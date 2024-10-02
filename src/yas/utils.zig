const std = @import("std");
const SerializeOptionsMaskFlags = @import("flags.zig").SerializeOptionsMaskFlags;
const TypeHashFn = std.hash.Fnv1a_64;

fn intToLittleEndianBytes(val: anytype) [@sizeOf(@TypeOf(val))]u8 {
    const T = @TypeOf(val);
    var res: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(AlignedInt(T), &res, val, .little);
    return res;
}

fn intToBigEndianBytes(val: anytype) [@sizeOf(@TypeOf(val))]u8 {
    const T = @TypeOf(val);
    var res: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(AlignedInt(T), &res, val, .big);
    return res;
}

pub fn validateTopLevelType(comptime T: type) void {
    switch (@typeInfo(T)) {
        // Unsupported top level types:
        .ErrorSet,
        .ErrorUnion,
        => @compileError("Unsupported top level type " ++ @typeName(T) ++ ". Wrap into struct to serialize these."),

        else => {},
    }
}

pub fn computeTypeHash(comptime T: type, options: SerializeOptionsMaskFlags) [8]u8 {
    var hasher = TypeHashFn.init();

    computeTypeHashInternal(&hasher, T);

    if (options.little_endian) {
        return intToLittleEndianBytes(hasher.final());
    }

    if (options.big_endian) {
        return intToBigEndianBytes(hasher.final());
    }

    return intToLittleEndianBytes(hasher.final());
}

fn computeTypeHashInternal(hasher: *TypeHashFn, comptime T: type) void {
    @setEvalBranchQuota(10_000);
    switch (@typeInfo(T)) {
        // Primitive types:
        .Void,
        .Bool,
        .Float,
        => hasher.update(@typeName(T)),

        .Int => {
            if (T == usize) {
                // special case: usize can differ between platforms, this
                // format uses u64 internally.
                hasher.update(@typeName(u64));
            } else {
                hasher.update(@typeName(T));
            }
        },
        .Pointer => |ptr| {
            if (ptr.is_volatile) @compileError("Serializing volatile pointers is most likely a mistake.");
            if (ptr.sentinel != null) @compileError("Sentinels are not supported yet!");
            switch (ptr.size) {
                .One => {
                    hasher.update("pointer");
                    computeTypeHashInternal(hasher, ptr.child);
                },
                .Slice => {
                    hasher.update("slice");
                    computeTypeHashInternal(hasher, ptr.child);
                },
                .C => @compileError("C-pointers are not supported"),
                .Many => @compileError("Many-pointers are not supported"),
            }
        },
        .Array => |arr| {
            if (arr.sentinel != null) @compileError("Sentinels are not supported yet!");
            hasher.update(&intToLittleEndianBytes(@as(u64, arr.len)));
            computeTypeHashInternal(hasher, arr.child);
        },
        .Struct => |str| {
            // we can safely ignore the struct layout here as we will serialize the data by field order,
            // instead of memory representation

            // add some generic marker to the hash so emtpy structs get
            // added as information
            hasher.update("struct");

            for (str.fields) |fld| {
                if (fld.is_comptime) @compileError("comptime fields are not supported.");
                computeTypeHashInternal(hasher, fld.type);
            }
        },
        .Optional => |opt| {
            hasher.update("optional");
            computeTypeHashInternal(hasher, opt.child);
        },
        .ErrorUnion => |eu| {
            hasher.update("error union");
            computeTypeHashInternal(hasher, eu.error_set);
            computeTypeHashInternal(hasher, eu.payload);
        },
        .ErrorSet => {
            // Error unions are serialized by "index of sorted name", so we
            // hash all names in the right order

            hasher.update("error set");
            const names = comptime getSortedErrorNames(T);
            for (names) |name| {
                hasher.update(name);
            }
        },
        .Enum => |list| {
            const Tag = if (list.tag_type == usize)
                u64
            else if (list.tag_type == isize)
                i64
            else
                list.tag_type;
            if (list.is_exhaustive) {
                // Exhaustive enums only allow certain values, so we
                // tag them via the value type
                hasher.update("enum.exhaustive");
                computeTypeHashInternal(hasher, Tag);
                const names = getSortedEnumNames(T);
                inline for (names) |name| {
                    hasher.update(name);
                    hasher.update(&intToLittleEndianBytes(@as(Tag, @intFromEnum(@field(T, name)))));
                }
            } else {
                // Non-exhaustive enums are basically integers. Treat them as such.
                hasher.update("enum.non-exhaustive");
                computeTypeHashInternal(hasher, Tag);
            }
        },
        .Union => |un| {
            const tag = un.tag_type orelse @compileError("Untagged unions are not supported!");
            hasher.update("union");
            computeTypeHashInternal(hasher, tag);
            for (un.fields) |fld| {
                computeTypeHashInternal(hasher, fld.type);
            }
        },
        .Vector => |vec| {
            hasher.update("vector");
            hasher.update(&intToLittleEndianBytes(@as(u64, vec.len)));
            computeTypeHashInternal(hasher, vec.child);
        },

        // Unsupported types:
        .NoReturn,
        .Type,
        .ComptimeFloat,
        .ComptimeInt,
        .Undefined,
        .Null,
        .Fn,
        .Opaque,
        .Frame,
        .AnyFrame,
        .EnumLiteral,
        => @compileError("Unsupported type " ++ @typeName(T)),
    }
}

pub fn AlignedInt(comptime T: type) type {
    return std.math.ByteAlignedInt(T);
}

fn getSortedEnumNames(comptime T: type) []const []const u8 {
    comptime {
        const type_info = @typeInfo(T).@"enum";

        var sorted_names: [type_info.fields.len][]const u8 = undefined;
        for (type_info.fields, 0..) |err, i| {
            sorted_names[i] = err.name;
        }

        std.mem.sortUnstable([]const u8, &sorted_names, {}, struct {
            fn order(ctx: void, lhs: []const u8, rhs: []const u8) bool {
                _ = ctx;
                return (std.mem.order(u8, lhs, rhs) == .lt);
            }
        }.order);
        return &sorted_names;
    }
}

fn getSortedErrorNames(comptime T: type) []const []const u8 {
    comptime {
        const error_set = @typeInfo(T).error_set orelse @compileError("Cannot serialize anyerror");

        var sorted_names: [error_set.len][]const u8 = undefined;
        for (error_set, 0..) |err, i| {
            sorted_names[i] = err.name;
        }

        std.mem.sortUnstable([]const u8, &sorted_names, {}, struct {
            fn order(ctx: void, lhs: []const u8, rhs: []const u8) bool {
                _ = ctx;
                return (std.mem.order(u8, lhs, rhs) == .lt);
            }
        }.order);
        return &sorted_names;
    }
}
