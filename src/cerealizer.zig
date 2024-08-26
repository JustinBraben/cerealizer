const std = @import("std");

pub const Buffers = @import("buffers.zig");
pub const ResizableOutputBuffer = Buffers.ResizableOutputBuffer;

// pub const JsonSerializer = Serializer(.json);

pub const SerialType = enum {
    Json,
    Xml
};

pub fn Serialize(object: anytype) SerializeInterface(@TypeOf(object)) {
    return .{ .original_object = object };
}

fn SerializeInterface(comptime T: type) type {
    return struct {
        const Self = @This();
        original_object: T,

        pub fn serialize(self: *Self, writer: anytype) !void {
            try serializeValue(self.original_object, writer);
        }

        fn serializeValue(value: anytype, writer: anytype) !void {
            const ValueType = comptime @TypeOf(value);
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

        pub fn toOwnedString(self: *Self, allocator: std.mem.Allocator) ![]u8 {
            var list = std.ArrayList(u8).init(allocator);
            defer list.deinit();
            try self.serialize(list.writer());
            return list.toOwnedSlice();
        }
    };
}

pub fn Deserialize(object: anytype) DeserializeInterface(@TypeOf(object)) {
    return .{ .serialized_object = object };
}

fn DeserializeInterface(comptime T: type) T {
    return struct {
        const Self = @This();
        serialized_object: T,

        pub fn deserialize(self: Self, allocator: std.mem.Allocator, reader: anytype) !T {
            _ = self; // self is unused in this implementation
            return try deserializeValue(T, allocator, reader);
        }

        fn deserializeValue(value: anytype, allocator: std.mem.Allocator, reader: anytype) !@TypeOf(value) {
            const ValueType = comptime @TypeOf(value);
            switch (@typeInfo(ValueType)) {
                .Struct => {
                    var val: ValueType = undefined;
                    try reader.skipUntilDelimiterOrEof('{');
                    inline for (std.meta.fields(ValueType)) |field| {
                        try reader.skipUntilDelimiterOrEof('"');
                        const read_field_name = try reader.readUntilDelimiterAlloc(allocator, '"', 1024);
                        defer allocator.free(read_field_name);
                        if (!std.mem.eql(u8, field.name, read_field_name)) {
                            return error.FieldMismatch;
                        }
                        try reader.skipUntilDelimiterOrEof(':');
                        @field(val, field.name) = try deserializeValue(field.type, allocator, reader);
                        _ = try reader.readByte(); // Skip comma or closing brace
                    }
                    return val;
                },
                .Array => |info| {
                    if (info.child == u8) {
                        var val: ValueType = undefined;
                        try reader.skipUntilDelimiterOrEof('"');
                        _ = try reader.readUntilDelimiterOrEof(&val, '"');
                        return val;
                    } else {
                        var val: ValueType = undefined;
                        try reader.skipUntilDelimiterOrEof('[');
                        for (&val) |*item| {
                            item.* = try deserializeValue(info.child, allocator, reader);
                            _ = try reader.readByte(); // Skip comma or closing bracket
                        }
                        return val;
                    }
                },
                .Pointer => |info| {
                    if (info.size == .Slice) {
                        if (info.child == u8) {
                            try reader.skipUntilDelimiterOrEof('"');
                            return try reader.readUntilDelimiterAlloc(allocator, '"', 1024);
                        } else {
                            var list = std.ArrayList(info.child).init(allocator);
                            errdefer list.deinit();
                            try reader.skipUntilDelimiterOrEof('[');
                            while (true) {
                                const item = try deserializeValue(info.child, allocator, reader);
                                try list.append(item);
                                const next_char = try reader.readByte();
                                if (next_char == ']') break;
                                if (next_char != ',') return error.InvalidFormat;
                            }
                            return list.toOwnedSlice();
                        }
                    } else {
                        @compileError("Unsupported pointer type");
                    }
                },
                .Int, .Float => {
                    var buffer: [128]u8 = undefined;
                    const num_str = try reader.readUntilDelimiterOrEof(&buffer, ',');
                    return try std.fmt.parseInt(ValueType, num_str.?, 10);
                },
                .Bool => {
                    var buffer: [5]u8 = undefined;
                    const bool_str = try reader.readUntilDelimiterOrEof(&buffer, ',');
                    return std.mem.eql(u8, bool_str.?, "true");
                },
                .Optional => |info| {
                    var buffer: [4]u8 = undefined;
                    const peek = try reader.readUntilDelimiterOrEof(&buffer, ',');
                    if (std.mem.eql(u8, peek.?, "null")) {
                        return null;
                    } else {
                        return try deserializeValue(info.child, allocator, reader);
                    }
                },
                else => @compileError("Unsupported type: " ++ @typeName(ValueType)),
            }
        }

        pub fn toObject(self: Self, allocator: std.mem.Allocator, reader: anytype) !T {
            return try self.deserialize(allocator, reader);
        }
    };
}

// Runs tests found in these imports
comptime {
    _ = @import("buffers.zig");
}