const std = @import("std");
const Io = std.Io;

const pg = @import("pg");
const interface = @import("interface.zig");

pub fn qprint(comptime s: []const u8) void {
    std.debug.print(s, .{});
}

pub fn qprintln(comptime s: []const u8) void {
    std.debug.print(s ++ "\n", .{});
}

const FooFn = extern struct {
    const Self = @This();
    const VSelf = @FieldType(Self, "ptr");

    // TODO: ptr is also allowed to be a concrete type, in
    // which case the pointers the closure is created from
    // must be for that concrete type.
    ptr: *anyopaque,
    vtable: *const struct {
        // vtable_constants: struct {
        //     // constants can be these types:
        //     //     *const anyopaque
        //     //     *const ConcreteType
        //     //     ?*const anyopaque
        //     //     ?*const ConcreteType
        //     //     // ConcreteType is allowed here since it is read-only.
        //     //     ConcreteType
        //     //     union(enum)
        //     //         Every variant must be one of the above types
        //     //         Optional `missing` variant allowed (must be first variant).
        //     foo_const: ?*const anyopaque = null,
        // },
        // vtable_globals: struct {
        //     // globals can be these types (Must be pointer types):
        //     //     *anyopaque
        //     //     *ConcreteType
        //     //     ?*anyopaque
        //     //     ?*ConcreteType
        //     //     union(enum)
        //     //         Every variant must be one of the above types
        //     //         Optional `missing` variant allowed (must be first variant).
        //     foo_global: ?*u32 = null,
        //     // if there is an `*anyopaque` field, it must be
        //     // the last field (fields are checked in order).
        //     bar_global: union(enum) {
        //         missing,
        //         u32_val: *u32,
        //         u64_val: *u64,
        //         u128_val: *u128,
        //         any: *anyopaque,
        //     },
        // },
        foo: *const fn(self: Self) void,
        bar: *const fn(self: Self) void,
        // with union(enum) vtable pointers, you can specify
        // one of any function signatures that must be matched.
        // The union can also have a `missing` variant to specify
        // that it is optional. The missing variant is expected to
        // be the first variant.
        exp: union(enum) {
            missing,
            takes_closure: *const fn(self: Self) void,
            takes_pointer: *const fn(self: VSelf) void,
        },
    },

    pub const init = interface.functions(Self).init;
    pub const as = interface.functions(Self).as;
    pub const fas = interface.functions(Self).fas;

    // pub inline fn as(self: Self, comptime T: type) *const T {
    //     return @ptrCast(@alignCast(self.ptr));
    // }

    // pub inline fn fas(self: Self, comptime T: type) *const T {
    //     @setRuntimeSafety(false);
    //     return self.as(T);
    // }

    pub inline fn foo(self: Self) void {
        self.vtable.foo(self);
    }

    pub inline fn bar(self: Self) void {
        self.vtable.bar(self);
    }

    pub fn foobar(self: Self) void {
        self.foo();
        self.bar();
    }
};

pub const Foo = struct {
    const Self = @This();
    
    text: []const u8,
    counter: usize = 0,

    pub fn foo(self: FooFn) void {
        const me = self.fas(Self);
        std.debug.print("foo() == \"{s}, count: {}\"\n", .{me.text, me.counter});
        me.counter += 1;
        // self.bar();
    }

    pub fn bar(_: FooFn) void {
        qprintln("Foo.bar()");
    }
};

pub const Bar = struct {
    const Self = @This();

    pub fn foo(_: FooFn) void {
        qprintln("Waow | Based based based based based");
    }

    pub fn bar(_: FooFn) void {
        qprintln("Bar.bar() | :)");
    }
};

pub fn main() !void {
    var foo: Foo = .{.text = "Hello, world!"};
    var bar: Bar = .{};
    const foo_any: FooFn = FooFn.init(&foo);
    const bar_any: FooFn = FooFn.init(&bar);
    foo_any.foo();
    foo_any.foo();
    bar_any.foobar();
    qprintln("Fin.");
}

test "quick tests" {
}
