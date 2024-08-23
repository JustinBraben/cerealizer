const std = @import("std");

pub const StartObjectTag = struct {};
pub const EndObjectTag = struct {};
pub const StartArrayTag = struct {};
pub const EndArrayTag = struct {};
pub const KeyTag = struct {};
pub const BoolTag = struct {};
pub const IntTag = struct {};
pub const FloatTag = struct {};
pub const StringTag = struct {};

pub const EmptyData = struct {
    pub const ResultT = void;
};

pub const IsEndOfArrayData = struct {
    pub const isEndOfArray_ = false;
};

pub const IsEndOfObjectData = struct {
    pub const isEndOfObject_ = false;
};

pub fn ValueData(comptime T: type) type {
    return struct {
        const ValueT = T;

        value_: T,
    };
}

pub fn ValueAndIsEndOfArrayData(comptime T: type) type {
    return struct {
        IsEndOfArrayData_: IsEndOfArrayData,
        ValueData_: ValueData(T),
    };
}