const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Utils = @import("utils.zig");
pub const SerializeOptionsMaskFlags = @import("flags.zig").SerializeOptionsMaskFlags;

pub const serializeRecursiveBinary = @import("serializers/serialize_binary.zig").serializeRecursiveBinary;
pub const serializeJson = @import("serializers/serialize_json.zig").serializeJson;

/// Serializes the given `value: T` into the `stream`.
/// - `stream` is a instance of `std.io.Writer`
/// - `T` is the type to serialize
/// - `value` is the instance to serialize.
pub fn serialize(stream: anytype, comptime T: type, value: T, comptime options: SerializeOptionsMaskFlags) @TypeOf(stream).Error!void {
    comptime Utils.validateTopLevelType(T);
    const type_hash = comptime Utils.computeTypeHash(T, options);

    if (options.binary) {
        try stream.writeAll(type_hash[0..]);
        try serializeRecursiveBinary(stream, T, value, options);
    }

    if (options.json) {
        try serializeJson(stream, T, value);
    }
}

fn testSerialize(comptime T: type, value: T, comptime options: SerializeOptionsMaskFlags) !void {
    var data = std.ArrayList(u8).init(std.testing.allocator);
    defer data.deinit();

    try serialize(data.writer(), T, value, options);
}

test "serialize binary" {
    const options = SerializeOptionsMaskFlags{
        .binary = true,
        .little_endian = true,
    };

    try testSerialize(f16, std.math.pi, options);
    try testSerialize(f32, std.math.pi, options);
    try testSerialize(f64, std.math.pi, options);
    try testSerialize(f80, std.math.pi, options);
    try testSerialize(f128, std.math.pi, options);
}

test "serialize json" {
    const options = SerializeOptionsMaskFlags{
        .json = true,
        .little_endian = true,
    };

    try testSerialize(f16, std.math.pi, options);
    try testSerialize(f32, std.math.pi, options);
    try testSerialize(f64, std.math.pi, options);
    try testSerialize(f80, std.math.pi, options);
    try testSerialize(f128, std.math.pi, options);
}

test "basic serialize json" {
    const options = SerializeOptionsMaskFlags{
        .json = true,
        .little_endian = true,
    };

    var data = std.ArrayList(u8).init(std.testing.allocator);
    defer data.deinit();

    const T = struct { a: i32, b: []const u8 };
    try serialize(data.writer(), T, T{ .a = 123, .b = "xy" }, options);
    try testing.expectEqualSlices(u8, "{\"a\":123,\"b\":\"xy\"}", data.items);
}

// pub const binary = @intFromEnum(flags.options.binary);
// pub const text = @intFromEnum(flags.options.text);
// pub const json = @intFromEnum(flags.options.json);
// pub const mem = @intFromEnum(flags.options.mem);

// const ArgSetType = u32;
// const max_format_args = @typeInfo(ArgSetType).Int.bits;

// pub fn Buffer(comptime T: type) type {
//     return struct {
//         data: []T,
//         allocator: Allocator,

//         pub fn init(allocator: Allocator) !@This() {
//             return .{
//                 .data = try allocator.alloc(T, 0),
//                 .allocator = allocator,
//             };
//         }

//         pub fn deinit(self: *@This()) void {
//             self.allocator.free(self.data);
//         }

//         pub fn append(self: *@This(), value: T) !void {
//             const new_data = try self.allocator.realloc(self.data, self.data.len + 1);
//             new_data[new_data.len - 1] = value;
//             self.data = new_data;
//         }

//         pub fn appendSlice(self: *@This(), slice: []const T) !void {
//             const new_len = self.data.len + slice.len;
//             const new_data = try self.allocator.realloc(self.data, new_len);
//             @memcpy(new_data[self.data.len..], slice);
//             self.data = new_data;
//         }
//     };
// }

// pub fn save(allocator: Allocator, comptime input_flags: usize, yas_object: anytype) !Buffer(u8) {
//     var buffer = try Buffer(u8).init(allocator);
//     errdefer buffer.deinit();

//     if (flags.isJsonArchive(input_flags)) {
//         try buffer.append('{');
//         inline for (std.meta.fields(@TypeOf(yas_object.given_args)), 0..) |field, i| {
//             if (i > 0) try buffer.append(',');

//             // std.debug.print("name: {s}, type: {s}\n", .{field.name, @typeName(field.type)});

//             const nested_value = @field(yas_object.given_args, field.name);
//             inline for (std.meta.fields(@TypeOf(nested_value)), 0..) |inner_field, j| {
//                 if (j > 0) try buffer.append(',');
//                 //std.debug.print("\tname: {s}, type: {s}\n", .{inner_field.name, @typeName(inner_field.type)});
//                 try buffer.append('"');
//                 try buffer.appendSlice(inner_field.name);
//                 try buffer.append('"');
//                 try buffer.append(':');

//                 const value = @field(nested_value, inner_field.name);
//                 switch (@TypeOf(value)) {
//                     comptime_int, i32, i64, u16, u32, u64 => {
//                         const str = try std.fmt.allocPrint(allocator, "{d}", .{value});
//                         defer allocator.free(str);
//                         try buffer.appendSlice(str);
//                     },
//                     f32, f64 => {
//                         const str = try std.fmt.allocPrint(allocator, "{d}", .{value});
//                         defer allocator.free(str);
//                         try buffer.appendSlice(str);
//                     },
//                     else => @compileError("Unsupported type: " ++ @typeName(@TypeOf(value))),
//                 }
//             }
//         }
//         try buffer.append('}');
//     } else if (flags.isBinaryArchive(input_flags)) {
//         @panic("Binary serialization not implemented yet");
//     } else {
//         @panic("Unsupported serialization format");
//     }

//     return buffer;
// }

// pub fn load(allocator: Allocator, buf: []const u8, comptime input_flags: usize, yas_object_nvp: anytype) !void {
//     if (flags.isJsonArchive(input_flags)) {
//         var parsed = try std.json.parseFromSlice(std.json.Value, allocator, buf, .{});
//         defer parsed.deinit();

//         if (parsed.value != .object) return error.InvalidJson;

//         inline for (std.meta.fields(@TypeOf(yas_object_nvp.given_args))) |field| {
//             const nested_value = @field(yas_object_nvp.given_args, field.name);
//             inline for (std.meta.fields(@TypeOf(nested_value))) |inner_field| {
//                 const name = inner_field.name;
//                 const ptr = @field(nested_value, name);
//                 const value = parsed.value.object.get(name) orelse return error.MissingField;

//                 switch (value) {
//                     .integer => |i| {
//                         if (@TypeOf(ptr.*) == @TypeOf(i)) {
//                             // ptr.* = @as(@TypeOf(i), @intCast(i));
//                             @field(nested_value, name) = @as(@TypeOf(i), @intCast(i));
//                         }
//                     },
//                     .float => |f| {
//                         if (@TypeOf(ptr.*) == @TypeOf(f)) {
//                             // ptr.* = @as(@TypeOf(f), @floatCast(f));
//                             @field(nested_value, name) = @as(@TypeOf(f), @floatCast(f));
//                         }
//                     },
//                     else => {},
//                 }
//             }
//         }
//     } else if (input_flags & binary != 0) {
//         @panic("Binary deserialization not implemented yet");
//     } else {
//         @panic("Unsupported deserialization format");
//     }
// }

// pub fn YasObject(object_name: []const u8, args: anytype) YasObjectAux(@TypeOf(args)) {
//     return .{ .object_name = object_name, .given_args = args };
// }

// fn YasObjectAux(comptime args: type) type {
//     const args_type_info = @typeInfo(args);
//     if (args_type_info != .Struct) {
//         @compileError("expected tuple or struct argument, found " ++ @typeName(args));
//     }

//     const fields_info = args_type_info.Struct.fields;
//     if (fields_info.len > max_format_args) {
//         @compileError("32 arguments max are supported per format call");
//     }

//     return struct {
//         object_name: []const u8,
//         given_args: args,
//     };
// }

// pub fn YasObjectNVP(object_name: []const u8, args: anytype) YasObjectNVPAux(@TypeOf(args)) {
//     return .{
//         .object_name = object_name,
//         .given_args = args,
//     };
// }

// fn YasObjectNVPAux(comptime Args: type) type {
//     return struct {
//         object_name: []const u8,
//         given_args: Args,
//     };
// }

// test "mem json serialize test" {
//     const test_allocator = std.testing.allocator;

//     const a: u32 = 3;
//     var aa: u32 = undefined;
//     const b: u16 = 4;
//     var bb: u16 = undefined;
//     const c: f32 = 3.14;
//     var cc: f32 = undefined;

//     const input_flags: usize = mem | json;

//     const yas_obj = YasObject("myobject", .{ .{ .a = a }, .{ .b = b }, .{ .c = c } });
//     var buf = try save(test_allocator, input_flags, yas_obj);
//     defer buf.deinit();

//     try testing.expectEqualStrings("{\"a\":3,\"b\":4,\"c\":3.14}", buf.data);

//     // std.debug.print("Serialized: {s}\n", .{buf.data});

//     // std.debug.print("Before Deserialized: a = {}, b = {}, c = {d}\n", .{ aa, bb, cc });
//     const yas_obj_nvp = YasObjectNVP("myobject", .{ .{ .a = &aa }, .{ .b = &bb }, .{ .c = &cc } });

//     try load(test_allocator, buf.data, input_flags, yas_obj_nvp);

//     // std.debug.print("Deserialized: a = {}, b = {}, c = {d}\n", .{ aa, bb, cc });
//     // try testing.expectEqual(a, aa);
//     // try testing.expectEqual(b, bb);
//     // try testing.expectEqual(c, cc);
// }
