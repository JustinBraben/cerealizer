const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const testing = std.testing;
const expect = testing.expect;

const Errors = @import("errors.zig");
const SerializeError = Errors.SerializeError;
const Utils = @import("details/utils.zig");

pub const FixedOutputBuffer = struct {
    const Self = @This();

    allocator: Allocator,
    data: []const u8,
    begin_index: usize,
    current: []u8,
    end_index: usize,

    pub fn init(allocator: Allocator, capacity: usize) !Self {
        const _data = try allocator.alloc(u8, capacity);
        return Self{
            .allocator = allocator,
            .data = _data,
            .begin_index = 0,
            .current = _data,
            .end_index = capacity,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.data);
    }

    pub fn put(self: *Self, value: anytype) SerializeError!void {
        const T = @TypeOf(value);
        switch (@typeInfo(T)) {
            .Bool => return self.putBool(value),
            else => @compileError("Unsupported type"),
        }
    }

    fn putBool(self: *Self, value: bool) SerializeError!void {
        return self.putPrimitive(if (value) @as(u8, 1) else @as(u8, 0));
    }

    fn putPrimitive(self: *Self, value: anytype) SerializeError!void {
        const bytes = std.mem.asBytes(&value);
        return self.putSlice(bytes);
    }

    fn putSlice(self: *Self, slice: []const u8) SerializeError!void {
        const len = if (std.mem.indexOfScalar(u8, slice, 0)) |null_pos| null_pos else slice.len;
        const ptr = self.getPtr(len) orelse return SerializeError.NotEnoughMemory;
        @memcpy(ptr, slice[0..len]);
    }

    fn getPtr(self: *Self, inputSize: usize) ?[]u8 {
        if (inputSize <= self.end_index) {
            const start = self.current;
            self.current += inputSize;
            self.available -= inputSize;
            return self.data[start..self.current];
        }

        return null;
    }

    pub fn getCapacity(self: *Self) usize {
        return self.end_index;
    }
};

test "OutputBuffer basic functionality" {
    const allocator = std.testing.allocator;
    var fixedBuffer = try FixedOutputBuffer.init(allocator, 1024);
    defer fixedBuffer.deinit();

    // const array = [*]u8{'H', 'e', 'l', 'l', 'o'};
    // var ptr: [*]const u8 = &array;

    // try expect(ptr[0] == 1);
    // ptr += 1;
    // try expect(ptr[0] == 2);

    // Test putting different types of data
    // try fixedBuffer.put(true);
    // try testing.expectEqual(@as(usize, 1), fixedBuffer.size());
}

pub const ResizableOutputBuffer = struct {
    const Self = @This();

    /// How many T values this list can hold without allocating
    /// additional memory.
    capacity: usize,
    allocator: Allocator,
    data: []u8,
    current: usize,
    available: usize,

    pub fn init(allocator: Allocator, initialSize: usize, maxSize: usize) !Self {
        assert(initialSize <= maxSize);
        const _data = try allocator.alloc(u8, initialSize);
        return Self{
            .capacity = maxSize,
            .allocator = allocator,
            .data = _data,
            .current = 0,
            .available = initialSize,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.data);
    }

    pub fn put(self: *Self, value: anytype) SerializeError!void {
        const T = @TypeOf(value);
        switch (@typeInfo(T)) {
            .Bool => return self.putBool(value),
            .Int, .Float => return self.putPrimitive(value),
            .Pointer => |ptr_info| switch (ptr_info.size) {
                .One => return self.putPrimitive(value.*),
                .Slice => return self.putSlice(std.mem.sliceAsBytes(value)),
                else => @compileError("Unsupported pointer type"),
            },
            else => @compileError("Unsupported type"),
        }
    }

    fn putBool(self: *Self, value: bool) SerializeError!void {
        return self.putPrimitive(if (value) @as(u8, 1) else @as(u8, 0));
    }

    fn putPrimitive(self: *Self, value: anytype) SerializeError!void {
        const bytes = std.mem.asBytes(&value);
        return self.putSlice(bytes);
    }

    fn putSlice(self: *Self, slice: []const u8) SerializeError!void {
        const len = if (std.mem.indexOfScalar(u8, slice, 0)) |null_pos| null_pos else slice.len;
        const ptr = self.getPtr(len) orelse return SerializeError.NotEnoughMemory;
        @memcpy(ptr, slice[0..len]);
    }

    pub fn data(self: Self) []const u8 {
        return self.data[0..self.current];
    }

    pub fn size(self: Self) usize {
        return self.current;
    }

    pub fn capacity(self: Self) usize {
        return self.data.len;
    }

    pub fn clear(self: *Self) void {
        self.current = 0;
        self.available = self.data.len;
    }

    fn getPtr(self: *Self, inputSize: usize) ?[]u8 {
        if (inputSize <= self.available) {
            const start = self.current;
            self.current += inputSize;
            self.available -= inputSize;
            return self.data[start..self.current];
        }

        const used = self.current;
        if (used + inputSize <= self.capacity) {
            const newSize = @min(self.capacity, (used + inputSize) * 2);
            self.data = self.allocator.realloc(self.data, newSize) catch return null;
            self.available = newSize - used - inputSize;
            const start = used;
            self.current = start + inputSize;
            return self.data[start..self.current];
        }

        return null;
    }
};

test "ResizableOutputBuffer basic functionality" {
    const allocator = std.testing.allocator;
    var buffer = try ResizableOutputBuffer.init(allocator, 16, 1024);
    defer buffer.deinit();

    // Test putting different types of data
    try buffer.put(true);
    try testing.expectEqual(@as(usize, 1), buffer.size());
    try buffer.put(@as(u8, 42));
    try testing.expectEqual(@as(usize, 2), buffer.size());
    try buffer.put(@as(u32, 0x12345678));
    try testing.expectEqual(@as(usize, 6), buffer.size());
    try buffer.put("Hello");
    try testing.expectEqual(@as(usize, 11), buffer.size());

    // Check the contents
    try testing.expectEqual(@as(u8, 1), buffer.data[0]);
    try testing.expectEqual(@as(u8, 42), buffer.data[1]);
    try testing.expectEqual(@as(u32, 0x12345678), @as(u32, @bitCast(buffer.data[2..6].*)));
    
    // Only compare the exact number of bytes written
    try testing.expectEqualSlices(u8, "Hello", buffer.data[6..11]);

    // Alternatively, you can use the size() method to get the exact slice:
    try testing.expectEqualSlices(u8, "Hello", buffer.data[6..buffer.size()]);

    // Test clear
    buffer.clear();
    try testing.expectEqual(@as(usize, 0), buffer.size());

    // Test putting data after clear
    try buffer.put(@as(u64, 0x1122334455667788));
    try testing.expectEqual(@as(usize, 8), buffer.size());
}

test "ResizableOutputBuffer resizing" {
    const allocator = std.testing.allocator;
    var buffer = try ResizableOutputBuffer.init(allocator, 4, 1024);
    defer buffer.deinit();

    // Fill the initial buffer
    try buffer.put(@as(u32, 0x12345678));
    try testing.expectEqual(@as(usize, 4), buffer.size());

    // This should trigger a resize
    try buffer.put(@as(u32, 0x87654321));
    try testing.expectEqual(@as(usize, 8), buffer.size());

    // Check the contents after resize
    try testing.expectEqual(@as(u32, 0x12345678), @as(u32, @bitCast(buffer.data[0..4].*)));
    try testing.expectEqual(@as(u32, 0x87654321), @as(u32, @bitCast(buffer.data[4..8].*)));
}