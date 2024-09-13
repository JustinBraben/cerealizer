const std = @import("std");
const testing = std.testing;

pub const options = enum(usize) {
    binary = 1 << 0,
    text = 1 << 1,
    json = 1 << 2,
    no_header = 1 << 3,
    elittle = 1 << 4,
    ebig = 1 << 5,
    ehost = 1 << 6,
    compacted = 1 << 7,
    mem = 1 << 8,
    file = 1 << 9,
};

pub fn isBinaryArchive(comptime input: usize) bool {
    return input & @intFromEnum(options.binary) == @intFromEnum(options.binary);
}

pub fn isTextArchive(comptime input: usize) bool {
    return input & @intFromEnum(options.text) == @intFromEnum(options.text);
}

pub fn isJsonArchive(comptime input: usize) bool {
    return input & @intFromEnum(options.json) == @intFromEnum(options.json);
}

pub fn isMemArchive(comptime input: usize) bool {
    return input & @intFromEnum(options.mem) == @intFromEnum(options.mem);
}

pub fn isFileArchive(comptime input: usize) bool {
    return input & @intFromEnum(options.file) == @intFromEnum(options.file);
}

pub fn isEnum(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .Enum => true,
        else => false,
    };
}

test "mem archive test" {
    const mem_text = @intFromEnum(options.mem) | @intFromEnum(options.text);
    const mem_binary = @intFromEnum(options.mem) | @intFromEnum(options.binary);
    const mem_json = @intFromEnum(options.mem) | @intFromEnum(options.json);

    try testing.expectEqual(false, isBinaryArchive(mem_text));
    try testing.expectEqual(true, isTextArchive(mem_text));
    try testing.expectEqual(false, isJsonArchive(mem_text));
    try testing.expectEqual(true, isMemArchive(mem_text));
    try testing.expectEqual(false, isFileArchive(mem_json));

    try testing.expectEqual(true, isBinaryArchive(mem_binary));
    try testing.expectEqual(false, isTextArchive(mem_binary));
    try testing.expectEqual(false, isJsonArchive(mem_binary));
    try testing.expectEqual(true, isMemArchive(mem_binary));
    try testing.expectEqual(false, isFileArchive(mem_json));

    try testing.expectEqual(false, isBinaryArchive(mem_json));
    try testing.expectEqual(false, isTextArchive(mem_json));
    try testing.expectEqual(true, isJsonArchive(mem_json));
    try testing.expectEqual(true, isMemArchive(mem_json));
    try testing.expectEqual(false, isFileArchive(mem_json));
}

test "file archive test" {
    const file_text = @intFromEnum(options.file) | @intFromEnum(options.text);
    const file_binary = @intFromEnum(options.file) | @intFromEnum(options.binary);
    const file_json = @intFromEnum(options.file) | @intFromEnum(options.json);

    try testing.expectEqual(false, isBinaryArchive(file_text));
    try testing.expectEqual(true, isTextArchive(file_text));
    try testing.expectEqual(false, isJsonArchive(file_text));
    try testing.expectEqual(false, isMemArchive(file_text));
    try testing.expectEqual(true, isFileArchive(file_text));

    try testing.expectEqual(true, isBinaryArchive(file_binary));
    try testing.expectEqual(false, isTextArchive(file_binary));
    try testing.expectEqual(false, isJsonArchive(file_binary));
    try testing.expectEqual(false, isMemArchive(file_text));
    try testing.expectEqual(true, isFileArchive(file_binary));

    try testing.expectEqual(false, isBinaryArchive(file_json));
    try testing.expectEqual(false, isTextArchive(file_json));
    try testing.expectEqual(true, isJsonArchive(file_json));
    try testing.expectEqual(false, isMemArchive(file_text));
    try testing.expectEqual(true, isFileArchive(file_json));
}

test "isEnum test" {
    const BloodType = enum { A, B, AB, O };

    try testing.expectEqual(true, isEnum(BloodType));
}
