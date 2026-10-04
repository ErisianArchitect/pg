const std = @import("std");
const Io = std.Io;

const pg = @import("pg");
const vtable = @import("vtable.zig");

pub fn qprint(comptime s: []const u8) void {
    std.debug.print(s, .{});
}

pub fn qprintln(comptime s: []const u8) void {
    std.debug.print(s ++ "\n", .{});
}

const FooFn = extern struct {
    const Self = @This();
    const VSelf = *const anyopaque;
    
    ptr: *const anyopaque,
    vtable: *const struct {
        foo: *const fn(self: Self) void,
        bar: *const fn(self: Self) void,
    },

    pub const init = vtable.init(Self);

    pub inline fn as(self: Self, comptime T: type) *const T {
        return @ptrCast(@alignCast(self.ptr));
    }

    pub inline fn fas(self: Self, comptime T: type) *const T {
        @setRuntimeSafety(false);
        return self.as(T);
    }

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

    pub fn foo(self: FooFn) void {
        const me = self.fas(Self);
        std.debug.print("foo() == \"{s}\"\n", .{me.text});
        self.bar();
    }

    pub fn bar(_: FooFn) void {
        qprintln("Foo.bar()");
    }
};

// pub const Bar = struct {
//     const Self = @This();

//     pub fn foo(_: *const Self) void {
//         qprintln("Waow | Based based based based based");
//     }

//     pub fn bar(_: *const Self) void {
//         qprintln("Bar.bar() | :)");
//     }
// };

pub fn main() !void {
    const foo: Foo = .{.text = "Hello, world!"};
    // const bar: Bar = .{};
    const foo_any: FooFn = FooFn.init(&foo);
    // const bar_any: FooFn = FooFn.init(&bar);
    foo_any.foobar();
    // bar_any.foobar();
    qprintln("Fin.");
}

test "quick tests" {
}
