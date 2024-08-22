const std = @import("std");

pub const Buffers = @import("buffers.zig");
pub const ResizableOutputBuffer = Buffers.ResizableOutputBuffer;

comptime {
    _ = @import("buffers.zig");
}

pub fn Serialize(object: anytype) SerializeInterface(@TypeOf(object)) {
    return .{ .original_object = object };
}

fn SerializeInterface(comptime T: type) type {
    return struct {
        const Self = @This();
        original_object: T,

        pub fn serialize(self: Self, writer: anytype) !void {
            try serializeValue(self.original_object, writer);
        }

        fn serializeValue(value: anytype, writer: anytype) !void {
            const ValueType = @TypeOf(value);
            switch (@typeInfo(ValueType)) {
                .Struct => {
                    try writer.writeByte('{');
                    inline for (std.meta.fields(ValueType), 0..) |field, i| {
                        if (i > 0) try writer.writeByte(',');
                        try writer.writeAll(field.name);
                        try writer.writeByte(':');
                        try serializeValue(@field(value, field.name), writer);
                    }
                    try writer.writeByte('}');
                },
                .Array => |info| {
                    if (info.child != u8) {
                        try writer.writeByte('[');
                        const slice = &value;
                        for (slice, 0..) |item, i| {
                            if (i > 0) try writer.writeByte(',');
                            try serializeValue(item, writer);
                        }
                        try writer.writeByte(']');
                    } else {
                        // Treat as string
                        try std.fmt.format(writer, "\"{s}\"", .{value});
                    }
                },
                .Pointer => |info| {
                    if (info.child != u8) {
                        try writer.writeByte('[');
                        const slice = value;
                        for (slice, 0..) |item, i| {
                            if (i > 0) try writer.writeByte(',');
                            try serializeValue(item, writer);
                        }
                        try writer.writeByte(']');
                    } else {
                        // Treat as string
                        try std.fmt.format(writer, "\"{s}\"", .{value});
                    }
                },
                .Int, .Float => {
                    try std.fmt.format(writer, "{d}", .{value});
                },
                .Bool => {
                    try std.fmt.format(writer, "{}", .{value});
                },
                .Optional => {
                    if (value) |v| {
                        try serializeValue(v, writer);
                    } else {
                        try writer.writeAll("null");
                    }
                },
                else => @compileError("Unsupported type: " ++ @typeName(ValueType)),
            }
        }

        pub fn toOwnedString(self: Self, allocator: std.mem.Allocator) ![]u8 {
            var list = std.ArrayList(u8).init(allocator);
            defer list.deinit();
            try self.serialize(list.writer());
            return list.toOwnedSlice();
        }
    };
}
