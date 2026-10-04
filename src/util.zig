
pub const Mutability = enum(u8) {
    const Self = @This();

    immut = 0,
    mut = 1,

    pub fn of(comptime T: type) Self { comptime {
        const inf = @typeInfo(T);
        if (inf != .pointer) {
            @compileError("Not a pointer type.");
        }
        if (inf.pointer.is_const) {
            return .immut;
        }
        return .mut;
    }}

    pub fn Ptr(comptime self: Self, comptime T: type) type {
        return switch (self) {
            .immut => *const T,
            .mut => *T,
        };
    }
};
