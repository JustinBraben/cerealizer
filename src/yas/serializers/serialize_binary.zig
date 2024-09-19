const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Utils = @import("../utils.zig");
const SerializeOptionsMaskFlags = @import("../flags.zig").SerializeOptionsMaskFlags;

pub fn serializeRecursiveBinary(stream: anytype, comptime T: type, value: T, options: SerializeOptionsMaskFlags) @TypeOf(stream).Error!void {
    const endian = if (options.big_endian) std.builtin.Endian.big else std.builtin.Endian.little;
    
    switch (@typeInfo(T)) {
        // Primitive types:
        .Void => {}, // no data
        .Bool => try stream.writeByte(@intFromBool(value)),
        .Float => switch (T) {
            f16 => try stream.writeInt(u16, @bitCast(value), endian),
            f32 => try stream.writeInt(u32, @bitCast(value), endian),
            f64 => try stream.writeInt(u64, @bitCast(value), endian),
            f80 => try stream.writeInt(u80, @bitCast(value), endian),
            f128 => try stream.writeInt(u128, @bitCast(value), endian),
            else => unreachable,
        },

        .Int => {
            if (T == usize) {
                try stream.writeInt(u64, value, endian);
            } else {
                try stream.writeInt(Utils.AlignedInt(T), value, endian);
            }
        },

        .Pointer => |ptr| {
            if (ptr.sentinel != null) @compileError("Sentinels are not supported yet!");
            switch (ptr.size) {
                .One => try serializeRecursiveBinary(stream, ptr.child, value.*, options),
                .Slice => {
                    try stream.writeInt(u64, value.len, endian);
                    if (ptr.child == u8) {
                        try stream.writeAll(value);
                    } else {
                        for (value) |item| {
                            try serializeRecursiveBinary(stream, ptr.child, item, options);
                        }
                    }
                },
                .C => unreachable,
                .Many => unreachable,
            }
        },
        .Array => |arr| {
            if (arr.child == u8) {
                try stream.writeAll(&value);
            } else {
                for (value) |item| {
                    try serializeRecursiveBinary(stream, arr.child, item, options);
                }
            }
            if (arr.sentinel != null) @compileError("Sentinels are not supported yet!");
        },
        .@"Struct" => |str| {
            // we can safely ignore the struct layout here as we will serialize the data by field order,
            // instead of memory representation

            inline for (str.fields) |fld| {
                try serializeRecursiveBinary(stream, fld.type, @field(value, fld.name), options);
            }
        },
        .Optional => |opt| {
            if (value) |item| {
                try stream.writeInt(u8, 1, endian);
                try serializeRecursiveBinary(stream, opt.child, item, options);
            } else {
                try stream.writeInt(u8, 0, .little);
            }
        },
        .ErrorUnion => |eu| {
            if (value) |item| {
                try stream.writeInt(u8, 1, .little);
                try serializeRecursiveBinary(stream, eu.payload, item, options);
            } else |item| {
                try stream.writeInt(u8, 0, .little);
                try serializeRecursiveBinary(stream, eu.error_set, item, options);
            }
        },
        .ErrorSet => {
            // Error unions are serialized by "index of sorted name", so we
            // hash all names in the right order
            const names = comptime Utils.getSortedErrorNames(T);

            const index = for (names, 0..) |name, i| {
                if (std.mem.eql(u8, name, @errorName(value)))
                    break @as(u16, @intCast(i));
            } else unreachable;

            try stream.writeInt(u16, index, endian);
        },
        .@"Enum" => |list| {
            const Tag = if (list.tag_type == usize) u64 else list.tag_type;
            try stream.writeInt(Utils.AlignedInt(Tag), @intFromEnum(value), endian);
        },
        .@"Union" => |un| {
            const Tag = un.tag_type orelse @compileError("Untagged unions are not supported!");

            const active_tag = std.meta.activeTag(value);

            try serializeRecursiveBinary(stream, Tag, active_tag, options);

            inline for (std.meta.fields(T)) |fld| {
                if (@field(Tag, fld.name) == active_tag) {
                    try serializeRecursiveBinary(stream, fld.type, @field(value, fld.name), options);
                }
            }
        },
        .Vector => |vec| {
            const array: [vec.len]vec.child = value;
            try serializeRecursiveBinary(stream, @TypeOf(array), array, options);
        },

        // Unsupported types:
        .NoReturn,
        .Type,
        .ComptimeFloat,
        .ComptimeInt,
        .Undefined,
        .Null,
        .@"Fn",
        .@"Opaque",
        .Frame,
        .@"AnyFrame",
        .EnumLiteral,
        => unreachable,
    }
}