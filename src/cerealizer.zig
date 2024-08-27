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

// pub fn Deserialize(object: anytype) DeserializeInterface(@TypeOf(object)) {
//     return .{ .serialized_object = object };
// }

pub fn Deserialize(comptime T: type) type {
    return DeserializeInterface(T);
}

fn DeserializeInterface(comptime T: type) type {
    return struct {
        const Self = @This();
        serialized_object: T,

        pub fn deserialize(allocator: std.mem.Allocator, reader: anytype) !T {
            //_ = self; // self is unused in this implementation
            return try deserializeValue(T, allocator, reader);
        }

        fn deserializeValue(comptime ValueType: type, allocator: std.mem.Allocator, reader: anytype) !ValueType {
            switch (@typeInfo(ValueType)) {
                .Struct => {
                    var value: ValueType = undefined;
                    var valid_read = false;
                    const first_byte = try reader.readByte(); // Skip opening '{'
                    var most_recent_byte = first_byte;
                    valid_read = (most_recent_byte == '{');

                    // Keep reading so long as valid read
                    // with return from this function if it ends nicely on '}'
                    while (valid_read) {
                        const byte = reader.readByte() catch |err| {
                            return err;
                        };
                        var whitespace_read = false;
                        whitespace_read = (byte == ' ' or byte == '\t' or byte == '\n' or byte == '\r');

                        switch (byte) {
                            ' ', '\t', '\n', '\r' => { 
                                if (most_recent_byte == '{' or 
                                    most_recent_byte == ' ' or most_recent_byte == '\t' or most_recent_byte == '\n' or most_recent_byte == '\r') 
                                {
                                    most_recent_byte = byte;
                                    continue;
                                }
                                return error.Whitespace;
                            },
                            '"' => {
                                const field_name = (try reader.readUntilDelimiterOrEofAlloc(allocator, '"', 1024)) orelse return error.UnexpectedEndOfStream;
                                defer allocator.free(field_name);
                                const colon = try reader.readByte();
                                if (colon != ':') return error.ExpectedColon;
                                // Find and parse field
                                inline for (std.meta.fields(ValueType)) |field| {
                                    if (std.mem.eql(u8, field.name, field_name)) {
                                        @field(value, field.name) = try deserializeValue(field.type, allocator, reader);
                                        break;
                                    }
                                // inline for returned a null
                                } else {
                                    // Skip unknown field
                                    try skipValue(reader);
                                }
                            },
                            else => {
                                return error.UnexpectedByte;
                            }
                        }
                    }

                    return error.InvalidRead;
                },
                .Array => |info| {
                    if (info.child == u8) {
                        const quote = try reader.readByte();
                        if (quote != '"') return error.ExpectedString;
                        var value: ValueType = undefined;
                        _ = try reader.readUntilDelimiterOrEof(&value, '"') orelse return error.UnexpectedEndOfStream;
                        return value;
                    } else {
                        var value: ValueType = undefined;
                        _ = try reader.readByte(); // Skip opening '['
                        for (&value, 0..) |*item, i| {
                            if (i > 0) {
                                const comma = try reader.readByte();
                                if (comma != ',') return error.ExpectedComma;
                            }
                            item.* = try deserializeValue(info.child, allocator, reader);
                        }
                        const closing = try reader.readByte();
                        if (closing != ']') return error.ExpectedClosingBracket;
                        return value;
                    }
                },
                .Pointer => |info| {
                    if (info.size == .Slice) {
                        if (info.child == u8) {
                            const quote = try reader.readByte();
                            if (quote != '"') return error.ExpectedString;
                            return (try reader.readUntilDelimiterOrEofAlloc(allocator, '"', 1024)) orelse return error.UnexpectedEndOfStream;
                        } else {
                            var list = std.ArrayList(info.child).init(allocator);
                            errdefer list.deinit();
                            _ = try reader.readByte(); // Skip opening '['
                            var first = true;
                            while (true) {
                                const byte = reader.readByte() catch |err| switch (err) {
                                    error.EndOfStream => return error.UnexpectedEndOfStream,
                                    else => return err,
                                };
                                if (byte == ']') break;
                                if (!first) {
                                    if (byte != ',') return error.ExpectedComma;
                                }
                                if (first) {
                                    try reader.skipBytes(1, .{});
                                }
                                const item = try deserializeValue(info.child, allocator, reader);
                                try list.append(item);
                                first = false;
                            }
                            return list.toOwnedSlice();
                        }
                    } else {
                        @compileError("Unsupported pointer type");
                    }
                },
                .Int, .Float => {
                    var buffer: [128]u8 = undefined;
                    const num_str = try reader.readUntilDelimiterOrEof(&buffer, ',') orelse return error.UnexpectedEndOfStream;
                    return try std.fmt.parseInt(ValueType, std.mem.trim(u8, num_str, " \t\r\n"), 10);
                },
                .Bool => {
                    var buffer: [5]u8 = undefined;
                    const bool_str = try reader.readUntilDelimiter(&buffer, ',') orelse return error.UnexpectedEndOfStream;
                    if (std.mem.eql(u8, std.mem.trim(u8, bool_str, " \t\r\n"), "true")) return true;
                    if (std.mem.eql(u8, std.mem.trim(u8, bool_str, " \t\r\n"), "false")) return false;
                    return error.InvalidBoolean;
                },
                .Optional => |info| {
                    var buffer: [4]u8 = undefined;
                    const peek = try reader.readUntilDelimiter(&buffer, ',') orelse return error.UnexpectedEndOfStream;
                    if (std.mem.eql(u8, std.mem.trim(u8, peek, " \t\r\n"), "null")) {
                        return null;
                    } else {
                        return try deserializeValue(info.child, allocator, reader);
                    }
                },
                else => @compileError("Unsupported type: " ++ @typeName(ValueType)),
            }
        }

        fn skipValue(reader: anytype) !void {
            var nesting: usize = 0;
            var in_string = false;
            while (true) {
                const byte = reader.readByte() catch |err| switch (err) {
                    error.EndOfStream => return error.UnexpectedEndOfStream,
                    else => return err,
                };
                switch (byte) {
                    '"' => in_string = !in_string,
                    '{', '[' => { if (!in_string) nesting += 1; },
                    '}', ']' => if (!in_string) {
                        if (nesting == 0) return;
                        nesting -= 1;
                    },
                    ',' => if (nesting == 0 and !in_string) return,
                    else => {},
                }
            }
        }

        pub fn toObject(allocator: std.mem.Allocator, reader: anytype) !T {
            return try deserialize(allocator, reader);
        }
    };
}

// Runs tests found in these imports
comptime {
    _ = @import("buffers.zig");
}