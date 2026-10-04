
const std = @import("std");
const StructField = std.builtin.Type.StructField;

const util = @import("util.zig");

const Mutability = util.Mutability;

pub inline fn unimplemented(comptime message: ?[]const u8) noreturn {
    const msg = blk: {
        if (message) |m| {
            break :blk "Not implemented: " ++ m;
        } else {
            break :blk "Not implemented.";
        }
    };
    if (@inComptime()) {
        @compileError(msg);
    } else {
        @panic(msg);
    }
}

inline fn strEql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub fn interfaceFnPtrType(comptime T: type) !type { comptime {
    const inf = @typeInfo(T);
    switch (inf) {
        .optional => |o| {
            const oinf = @typeInfo(o.child);
            if (oinf != .pointer) {
                return error{};
            }
            const chinf = @typeInfo(oinf.pointer.child);
            if (chinf != .@"fn") {
                return error{};
            }
            return oinf.pointer.child;
        },
        .@"fn" => {
            return T;
        },
        .pointer => |p| {
            const chinf = @typeInfo(p.child);
            if (chinf != .@"fn") {
                return error{};
            }
            return p.child;
        },
        else => return error{},
    }
}}

pub const VTFieldInfo = struct {
    const Self = @This();
    outer: type,
    field: StructField,

    pub fn FnType(comptime self: Self) type { comptime {
        return interfaceFnPtrType(self.field.type).?;
    }}

    pub fn ParentFallback(comptime self: Self) ?type { comptime {
        if (@hasDecl(self.outer, "FALLBACK")) {
            return @field(self.outer, "FALLBACK");
        }
        return null;
    }}

    pub fn fallback(comptime self: Self) ?*const self.FnType() { comptime {
        if (self.ParentFallback()) |fb| {
            if (@hasDecl(fb, self.field.name))
                return &@field(fb, self.field.name);
        }
        return null;
    }}

    pub inline fn hasDefault(comptime self: Self) bool { comptime {
        return self.field.default_value_ptr != null;
    }}

    pub fn isRequired(self: *Self) bool { comptime {
        if (self.hasDefault()) {
            return false;
        }
        if (self.fallback()) {
            return false;
        }
        return true;
    }}

    pub fn loadDefault(comptime self: Self) *const self.FnType() { comptime {
        if (self.field.defaultValue()) |default| {
            return default;
        } else {
            @compileError("No default value.");
        }
    }}
};

pub fn vtFieldInfo(comptime Interface: type, comptime fn_name: []const u8) ?VTFieldInfo { comptime {
    if (!@hasField(Interface, fn_name)) {
        return null;
    }
    const field_index = std.meta.fieldIndex(Interface, fn_name).?;
    const field_info = std.meta.fields(Interface)[field_index];
    return VTFieldInfo {
        .outer = Interface,
        .field = field_info,
    };
}}

pub fn hasInterface(comptime T: type, comptime Interface: type) bool { comptime {
    for (std.meta.fields(Interface)) |field| {
        if (!vtFieldInfo(Interface, field.name)) {
            // TODO: vtable_constants, vtable_globals
            return false;
        }
        if (@hasDecl(T, field.name)) {
            return false;
        }
    }
    return true;
}}

pub fn expectInterface(comptime T: type, comptime Interface: type) void { comptime {
    for (std.meta.fields(Interface)) |field| {
        if (vtFieldInfo(Interface, field.name)) |_| {} else {
            // TODO: vtable_constants, vtable_globals
            @compileError(
                @typeName(Interface)
                ++ "."
                ++ field.name
                ++ " is not a VTPtr field: ");
        }
        if (!@hasDecl(T, field.name)) {
            @compileError("Missing decl in \"" ++ @typeName(T) ++ "\": \"" ++ field.name ++ "\".");
        }
    }
}}

pub fn vtable(comptime Interface: type, comptime Impl: type) *const Interface {
    const POPULATED = struct {
        pub const VTABLE: Interface = blk: {
            var vt: Interface = undefined;
            for (std.meta.fields(Interface)) |field| {
                if (!@hasDecl(Impl, field.name)) @compileError("Missing decl: \"" ++ field.name ++ "\" from pointer type \"" ++ @typeName(Impl) ++ "\".");
                @field(vt, field.name) = @ptrCast(&@field(Impl, field.name));
            }
            break :blk vt;
        };
    };
    return &POPULATED.VTABLE;
}

pub inline fn createClosure(comptime ClosureType: type, comptime Interface: type, ptr: anytype) ClosureType {
    comptime expectInterface(ClosureType, Interface);
    return .{
        .ptr = @ptrCast(ptr),
        .vtable = vtable(Interface, @typeInfo(@TypeOf(ptr)).pointer.child),
    };
}

pub fn isVTableFnPtr(comptime ClosureType: type, comptime Impl: ?type, comptime T: type)
    enum { is, not_pointer, not_const, no_self }
{ comptime {
    const inf = @typeInfo(T);
    if (inf != .pointer) {
        return .not_pointer;
    }
    if (!inf.pointer.is_const) {
        return .not_const;
    }
    const ptrch = inf.pointer.child;
    const ptrinf = @typeInfo(ptrch);
    const first_param = ptrinf.@"fn".params[0].type;
    if (first_param == ClosureType) {
        return .is;
    }
    const sinf = @typeInfo(first_param);

    switch (sinf) {
        .pointer => |p| {
            if (p.child == ClosureType) {
                return .is;
            }
            if (p.child == anyopaque) {
                return .is;
            }
            if (Impl) |i| {
                if (p.child == i) {
                    return .is;
                }
            }
            return .no_self;
        },
        else => return .no_self,
    }
    return .is;
}}

pub fn isVTablePtr(comptime ClosureType: type, comptime T: type)
    enum { is, not_pointer, not_const, invalid_interface }
{ comptime {
    const inf = @typeInfo(T);
    if (inf != .pointer) {
        return .not_pointer;
    }
    if (!inf.pointer.is_const) {
        return .not_const;
    }
    const InterfaceType = inf.pointer.child;
    const fields = std.meta.fields(InterfaceType);
    for (fields) |field| {
        if (strEql(field.name, "vtable_constants"))
            unimplemented("vtable_constants field.");
        if (strEql(field.name, "vtable_globals"))
            unimplemented("vtable_globals field.");
        switch (isVTableFnPtr(ClosureType, null, @FieldType(InterfaceType, field.name))) {
            .is => continue,
            else => return .invalid_interface,
        }
    }
    return .is;
}}

pub const InvalidClosureError = error {
    NotAStruct,
    NotExtern,
    MissingPtrField,
    MissingVTableField,
    MissingCtxField,
    FieldMismatch,
    FieldCountMismatch,
    PtrFieldNotAnyOpaquePtr,
    VTableFieldNotAVTable,
};

pub fn checkClosureType(comptime T: type) InvalidClosureError!void { comptime {
    const inf = @typeInfo(T);
    if (inf != .@"struct") {
        return InvalidClosureError.NotAStruct;
    }
    const struc = inf.@"struct";
    if (struc.layout != .@"extern") {
        return InvalidClosureError.NotExtern;
    }
    if (!@hasField(T, "ptr"))
        return false;
    const ptr_type = @FieldType(T, "ptr");
    const ptr_inf = @typeInfo(ptr_type);
    if (ptr_inf != .pointer or ptr_inf.pointer.child != anyopaque) {
        return InvalidClosureError.PtrFieldNotAnyOpaquePtr;
    }
    if (!@hasField(T, "vtable"))
        return InvalidClosureError.MissingVTableField;
    switch (isVTablePtr(T, @FieldType(T, "vtable"))) {
        .is => {},
        else => return InvalidClosureError.VTableFieldNotAVTable,
    }
    switch (struc.fields.len) {
        2 => {}, // extern struct { ptr: Ptr, vtable: VTPtr }
        3 => { // extern struct { ptr: Ptr, vtable: VTPtr, ctx: CtxPtr }
            if (!@hasField(T, "ctx")) {
                return InvalidClosureError.MissingCtxField;
            }
        },
        else => return InvalidClosureError.FieldCountMismatch,
    }
}}

pub fn functions(comptime ClosureType: type) type { comptime {
    if (checkClosureType(ClosureType)) {} else |_| {
        @compileError("Not a closure type.");
    }
    const vtable_ty = @FieldType(ClosureType, "vtable");
    const vtinf = @typeInfo(vtable_ty);
    if (vtinf != .pointer) {
        @compileError("vtable field must be pointer type.");
    }
    if (!vtinf.pointer.is_const) {
        @compileError("vtable field must be const pointer.");
    }
    const InterfaceType = vtinf.pointer.child;
    expectInterface(ClosureType, InterfaceType);
    return struct {
        // pub fn initFor()
        //     fn(ptr: anytype) callconv(.@"inline") ClosureType
        // { comptime {
        //     if (!@hasField(ClosureType, "vtable")) {
        //         @compileError("Expected vtable field.");
        //     }
        //     const vtable_ty = @FieldType(ClosureType, "vtable");
        //     const vtinf = @typeInfo(vtable_ty);
        //     if (vtinf != .pointer) {
        //         @compileError("vtable field must be pointer type.");
        //     }
        //     if (!vtinf.pointer.is_const) {
        //         @compileError("vtable field must be const pointer.");
        //     }
        //     const Interface = vtinf.pointer.child;
        //     expectInterface(ClosureType, Interface);
    
        //     return struct {
        //         pub inline fn function(ptr: anytype) ClosureType {
        //             return createClosure(ClosureType, Interface, ptr);
        //         }
        //     }.function;
        // }}
        
        pub const init = struct {
            pub inline fn init(ptr: anytype) ClosureType {
                return createClosure(ClosureType, InterfaceType, ptr);
            }
        }.init;

        pub const as = struct {
            pub inline fn as(self: ClosureType, comptime T: type)
                Mutability.of(@FieldType(ClosureType, "ptr")).Ptr(T)
            {
                return @ptrCast(@alignCast(self.ptr));
            }
        }.as;

        pub const fas = struct {
            pub inline fn fas(self: ClosureType, comptime T: type)
                Mutability.of(@FieldType(ClosureType, "ptr")).Ptr(T)
            {
                @setRuntimeSafety(false);
                return @ptrCast(@alignCast(self.ptr));
            }
        }.fas;
    };
}}
