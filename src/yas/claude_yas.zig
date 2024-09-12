const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
pub const flags = @import("flags.zig");

pub const binary = @intFromEnum(flags.options.binary);
pub const text = @intFromEnum(flags.options.text);
pub const json = @intFromEnum(flags.options.json);
pub const mem = @intFromEnum(flags.options.mem);

const ArgSetType = u32;
const max_format_args = @typeInfo(ArgSetType).Int.bits;

pub fn Buffer(comptime T: type) type {
    return struct {
        data: []T,
        allocator: Allocator,

        pub fn init(allocator: Allocator) !@This() {
            return .{
                .data = try allocator.alloc(T, 0),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.allocator.free(self.data);
        }

        pub fn append(self: *@This(), value: T) !void {
            const new_data = try self.allocator.realloc(self.data, self.data.len + 1);
            new_data[new_data.len - 1] = value;
            self.data = new_data;
        }

        pub fn appendSlice(self: *@This(), slice: []const T) !void {
            const new_len = self.data.len + slice.len;
            const new_data = try self.allocator.realloc(self.data, new_len);
            @memcpy(new_data[self.data.len..], slice);
            self.data = new_data;
        }
    };
}

pub fn save(allocator: Allocator, comptime input_flags: usize, yas_object: anytype) !Buffer(u8) {
    var buffer = try Buffer(u8).init(allocator);
    errdefer buffer.deinit();

    if (flags.isJsonArchive(input_flags)) {
        try buffer.append('{');
        inline for (std.meta.fields(@TypeOf(yas_object.given_args)), 0..) |field, i| {
            if (i > 0) try buffer.append(',');

            // std.debug.print("name: {s}, type: {s}\n", .{field.name, @typeName(field.type)});

            const nested_value = @field(yas_object.given_args, field.name);
            inline for (std.meta.fields(@TypeOf(nested_value)), 0..) |inner_field, j| {
                if (j > 0) try buffer.append(',');
                //std.debug.print("\tname: {s}, type: {s}\n", .{inner_field.name, @typeName(inner_field.type)});
                try buffer.append('"');
                try buffer.appendSlice(inner_field.name);
                try buffer.append('"');
                try buffer.append(':');

                const value = @field(nested_value, inner_field.name);
                _ = value;

                // TODO: cast *const anyopaque to the type we want
                // std.debug.print("\tname: {s}, type: {s}, value: {any}\n", .{inner_field.name, @typeName(inner_field.type), inner_field.default_value});
            }
            // try std.json.stringify(@field(yas_object.given_args, field.name), .{}, buffer);
        }
        try buffer.append('}');
    }
    // } else if (input_flags & binary != 0) {
    //     @panic("Binary serialization not implemented yet");
    // } else {
    //     @panic("Unsupported serialization format");
    // }

    return buffer;
}

pub fn load(allocator: Allocator, buf: []const u8, input_flags: usize, yas_object_nvp: anytype) !void {
    if (input_flags & json != 0) {
        var stream = std.json.TokenStream.init(buf);
        const parsed = try std.json.parse(std.json.Value, &stream, .{.allocator = allocator});
        defer std.json.parseFree(std.json.Value, parsed, .{.allocator = allocator});

        if (parsed != .Object) return error.InvalidJson;

        inline for (std.meta.fields(@TypeOf(yas_object_nvp.given_args))) |field| {
            const name = field.name;
            const ptr = &@field(yas_object_nvp.given_args, name);
            const value = parsed.Object.get(name) orelse return error.MissingField;
            ptr.* = switch (@TypeOf(ptr.*)) {
                u32 => @intCast(value.Integer),
                u16 => @intCast(value.Integer),
                f32 => @floatCast(value.Float),
                else => @panic("Unsupported type"),
            };
        }
    } else if (input_flags & binary != 0) {
        @panic("Binary deserialization not implemented yet");
    } else {
        @panic("Unsupported deserialization format");
    }
}

pub fn YasObject(object_name: []const u8, args: anytype) YasObjectAux(@TypeOf(args)) {
    return .{
        .object_name = object_name,
        .given_args = args
    };
}

fn YasObjectAux(comptime args: type) type {
    const args_type_info = @typeInfo(args);
    if (args_type_info != .Struct) {
        @compileError("expected tuple or struct argument, found " ++ @typeName(args));
    }

    const fields_info = args_type_info.Struct.fields;
    if (fields_info.len > max_format_args) {
        @compileError("32 arguments max are supported per format call");
    }

    return struct {
        object_name: []const u8,
        given_args: args, 
    };
}

pub fn YasObjectNVP(object_name: []const u8, args: anytype) YasObjectNVPAux(@TypeOf(args)) {
    return .{
        .object_name = object_name,
        .given_args = args,
    };
}

fn YasObjectNVPAux(comptime Args: type) type {
    return struct {
        object_name: []const u8,
        given_args: Args,
    };
}

test "mem json serialize test" {
    const test_allocator = std.testing.allocator;

    const a: u32 = 3;
    var aa: u32 = undefined;
    const b: u16 = 4;
    var bb: u16 = undefined;
    const c: f32 = 3.14;
    var cc: f32 = undefined;

    _ = &aa;
    _ = &bb;
    _ = &cc;

    const input_flags: usize = mem | json;

    const yas_obj = YasObject("myobject", .{ .{.a = a}, .{.b = b}, .{.c = c} });
    var buf = try save(test_allocator, input_flags, yas_obj);
    defer buf.deinit();

    try testing.expectEqualSlices(u8, "{\"a\":,\"b\":,\"c\":}", buf.data);

    // std.debug.print("Serialized: {s}\n", .{buf.data});

    // const yas_obj_nvp = YasObjectNVP(
    //     "myobject",
    //     .{ a = &aa, b = &bb, c = &cc }
    // );

    // try yas.load(allocator, buf.data, flags, yas_obj_nvp);

    // std.debug.print("Deserialized: a = {}, b = {}, c = {d}\n", .{ aa, bb, cc });
    // std.debug.assert(a == aa and b == bb and @abs(c - cc) < 0.0001);
}