const std = @import("std");

pub const Buffers = @import("buffers.zig");
pub const ResizableOutputBuffer = Buffers.ResizableOutputBuffer;

// pub const JsonSerializer = Serializer(.json);
pub const JsonParser = @import("parser/json_parser.zig").JsonParser;

pub const SerialType = enum { Json, Xml };

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
                    // Initialize the struct
                    var value: ValueType = undefined;

                    // Read fields until we hit the closing '}'
                    var read_something = false;

                    while (true) {
                        // Try to read the next character, handling EOF
                        const next_char = reader.readByte() catch |err| switch (err) {
                            error.EndOfStream => if (read_something) return value else return err,
                            else => return err,
                        };

                        // Skip opening '{'
                        if (next_char == '{') {
                            if (!read_something) continue;
                        }

                        // Check if we've reached the end of the object
                        if (next_char == '}') {
                            if (read_something) return value;
                            return error.UnexpectedCharacter;
                        }

                        // Handle comma between fields
                        if (read_something) {
                            // if (next_char != ',') return error.ExpectedComma;
                            if (next_char == ',') continue;
                            // Skip whitespace after comma
                            // only skip whitespace next_car is whitespace
                            // try skipWhitespace(reader);
                        } else if (isWhitespace(next_char)) {
                            // Skip leading whitespace
                            try skipWhitespace(reader);
                        }

                        if (next_char != '"') return error.ExpectedString;
                        const field_name = try readString(allocator, reader);
                        defer allocator.free(field_name);

                        // Expect and skip colon
                        const colon = try reader.readByte();
                        if (colon != ':') return error.ExpectedColon;

                        // Skip whitespace after colon
                        //try skipWhitespace(reader);

                        // Find and parse field
                        inline for (std.meta.fields(ValueType)) |field| {
                            if (std.mem.eql(u8, field.name, field_name)) {
                                @field(value, field.name) = try deserializeValue(field.type, allocator, reader);
                                read_something = true;
                                break;
                            }
                        } else {
                            // Skip unknown field
                            try skipValue(reader);
                        }

                        // Skip whitespace after value
                        // only skip whitespace if it is
                        // try skipWhitespace(reader);
                    }
                },
                .Array => |info| {
                    std.debug.print(".Array info : {}\n", .{info});
                    switch (info.child) {
                        u8 => {
                            const quote = try reader.readByte();
                            if (quote != '"') return error.ExpectedString;
                            var value: ValueType = undefined;
                            _ = try reader.readUntilDelimiterOrEof(&value, '"') orelse return error.UnexpectedEndOfStream;
                            return value;
                        },
                        else => {
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
                        },
                    }
                },
                .Pointer => |info| {
                    std.debug.print(".Pointer info : {}\n", .{info});
                    switch (info.size) {
                        .Slice => {
                            if (info.child == u8) {
                                const quote = try reader.readByte();
                                std.debug.print("next_char : {}\n", .{quote});
                                if (quote != '"') return error.ExpectedString;
                                return try readString(allocator, reader);
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
                        },
                        else => {
                            @compileError("Unsupported pointer type");
                        },
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

        // Helper function to skip whitespace
        fn skipWhitespace(reader: anytype) !void {
            while (true) {
                const byte = reader.readByte() catch |err| switch (err) {
                    error.EndOfStream => return,
                    else => return err,
                };
                if (!isWhitespace(byte)) {
                    try reader.skipBytes(1, .{});
                    return;
                }
            }
        }

        // Helper function to check if a byte is whitespace
        fn isWhitespace(byte: u8) bool {
            return byte == ' ' or byte == '\t' or byte == '\n' or byte == '\r';
        }

        // Helper function to read a JSON string
        fn readString(allocator: std.mem.Allocator, reader: anytype) ![]const u8 {
            // const quote = try reader.readByte();
            // std.debug.print("quote : {}\n", .{quote});
            // if (quote != '"') return error.ExpectedString;
            return (try reader.readUntilDelimiterOrEofAlloc(allocator, '"', 1024)) orelse return error.UnexpectedEndOfStream;
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
                    '{', '[' => {
                        if (!in_string) nesting += 1;
                    },
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
    _ = @import("tokenizer/json_tokenizer.zig");
    _ = @import("parser/json_parser.zig");

    _ = @import("yas/yas.zig");
    _ = @import("yas/flags.zig");
}
