
const std = @import("std");
const StructField = std.builtin.Type.StructField;

pub const interface = @import("interface.zig");

pub inline fn unimplemented() noreturn {
    if (@inComptime()) {
        @compileError("Not implemented.");
    } else {
        @panic("Not implemented.");
    }
}

pub const VTFieldInfo = struct {
    const Self = @This();
    outer: type,
    field: StructField,

    pub fn isRequired(self: *Self) bool { comptime {
        if (self.field.default_value_ptr) {
            return false;
        }
        if (self.Fallback()) |fb| {
            if (@hasDecl(fb, self.field.name))
                return false;
        }
        return true;
    }}

    pub fn Fallback(comptime self: Self) ?type { comptime {
        if (@hasDecl(self.outer, "FALLBACK")) {
            return @field(self.outer, "FALLBACK");
        }
        return null;
    }}

    pub fn fallback(comptime self: Self) ?*const self.FnType() { comptime {
        if (self.Fallback()) |fb| {
            if (@hasDecl(fb, self.field.name))
                return &@field(fb, self.field.name);
        }
        return null;
    }}

    pub fn hasDefault(comptime self: Self) bool { comptime {
        return self.field.default_value_ptr != null;
    }}

    pub fn loadDefault(comptime self: Self) *const self.FnType() { comptime {
        if (self.field.defaultValue()) |default| {
            return default;
        } else {
            @compileError("No default value.");
        }
    }}

    pub fn FnType(comptime self: Self) type { comptime {
        const inf = @typeInfo(self.field.type);
        switch (inf) {
            .optional => |o| {
                return o.child;
            },
            .@"fn" => {
                return self.field.type;
            },
            .pointer => |p| {
                return p.child;
            },
        }
    }}
};

pub fn vtFieldInfo(comptime T: type, comptime fn_name: []const u8) VTFieldInfo { comptime {
    return VTFieldInfo {
        .outer = T,
        .field = std.meta.fieldInfo(T, fn_name),
    };
}}

pub fn interfaceFnPtrType(comptime T: type) type { comptime {
    return @typeInfo(T).pointer.child;
}}

pub fn hasInterface(comptime T: type, comptime I: type) bool { comptime {
    for (std.meta.fields(I)) |field| {
        // const fntype = interfaceFnPtrType(T, field.name);
        if (!@hasDecl(T, field.name)) {
            return false;
        }
    }
    return true;
}}

pub fn expectInterface(comptime T: type, comptime I: type) void { comptime {
    for (std.meta.fields(I)) |field| {
        if (!@hasDecl(T, field.name))
            @compileError("Missing declaration: \"" ++ field.name ++ "\" was not found in given type \"" ++ @typeName(T) ++ "\".");
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

pub fn init(comptime ClosureType: type)
    fn(ptr: anytype) callconv(.@"inline") ClosureType
{ comptime {
    if (!@hasField(ClosureType, "vtable")) {
        @compileError("Expected vtable field.");
    }
    const vtable_ty = @FieldType(ClosureType, "vtable");
    const vtinf = @typeInfo(vtable_ty);
    if (vtinf != .pointer) {
        @compileError("vtable field must be pointer type.");
    }
    if (!vtinf.pointer.is_const) {
        @compileError("vtable field must be const pointer.");
    }
    const Interface = vtinf.pointer.child;
    expectInterface(ClosureType, Interface);
    
    return struct {
        pub inline fn function(ptr: anytype) ClosureType {
            return createClosure(ClosureType, Interface, ptr);
        }
    }.function;
}}
