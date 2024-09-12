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

pub fn save(comptime input_flags: usize, yas_object: anytype) ![]const u8 {
    const YasObjectType = @TypeOf(yas_object);
    const yas_object_type_info = @typeInfo(YasObjectType);
    if (yas_object_type_info != .Struct) {
        @compileError("expected tuple or struct argument, found " ++ @typeName(YasObjectType));
    }
    const fields_info = yas_object_type_info.Struct.fields;
    if (fields_info.len > max_format_args) {
        @compileError("32 arguments max are supported per format call");
    }

    if (flags.isJsonArchive(input_flags)){
        var buffer: [40]u8 = undefined;
        const buf = buffer[0..];

        var name_list = std.ArrayList([]const u8).init(std.heap.page_allocator);
        defer name_list.deinit();

        var val_list = std.ArrayList([]u8).init(std.heap.page_allocator);
        defer val_list.deinit();

        inline for (yas_object_type_info.Struct.fields) |field| {
            
            const inner = @typeInfo(field.type);

            switch (inner) {
                .Struct => |inner_struct| {
                    inline for (inner_struct.fields) |inner_field| {

                        const inner_inner = @typeInfo(inner_field.type);

                        switch (inner_inner) {
                            .Struct => |inner_inner_struct| {
                                inline for (inner_inner_struct.fields) |inner_inner_field| {
                                    try name_list.append(inner_inner_field.name);
                                }
                            },
                            else => {}
                        }
                    }
                },
                .Pointer => {},
                else => {},
            }
        }

        // const fmt: []const u8 = "{s} {s} {s}";
        for (name_list.items) |item| {
            std.debug.print("item: \"{s}\"\n", .{item});
            // var fmt_buffer: [20]u8 = undefined;
            // const fmt_buf = fmt_buffer[0..];
            // _ = try std.fmt.bufPrint(fmt_buf, "\"{s}\"", .{yas_object.object_name});
            // fmt = fmt ++ buf;
        }
        std.debug.print("fmt: \"{s}\" \"{s}\" \"{s}\"\n", .{name_list.items[0], name_list.items[1], name_list.items[2]});


        
        // std.debug.print("yas_object.object_name = {s} \n", .{yas_object.object_name});
        
        _ = try std.fmt.bufPrint(buf, "{{\"{s}\"}}", .{yas_object.object_name});
        return buf;
    }
    else {
        var buffer: [40]u8 = undefined;
        const buf = buffer[0..];
        _ = try std.fmt.bufPrint(buf, "{{ \"{s}\" }}\n", .{"Oops, no flags set!"});
        return buf;
    }
    
    // std.debug.print("yas_obj:\n\tobject_name: {s},\n\tgiven_args: {} \n", .{yas_object.object_name, yas_object.given_args});
    // std.debug.print("input_flags = {} \n", .{input_flags});
}

// pub fn saveNew(gpa: Allocator, input_flags: usize, yas_object: anytype)

pub fn debugYasObject(yas_object: anytype) void {
    const YasObjectType = @TypeOf(yas_object);
    const yas_object_type_info = @typeInfo(YasObjectType);
    if (yas_object_type_info != .Struct) {
        @compileError("expected tuple or struct argument, found " ++ @typeName(YasObjectType));
    }
    const fields_info = yas_object_type_info.Struct.fields;
    if (fields_info.len > max_format_args) {
        @compileError("32 arguments max are supported per format call");
    }

    std.debug.print("yas_object_type_info fields len: {}\n", .{yas_object_type_info.Struct.fields.len});

    inline for (yas_object_type_info.Struct.fields) |field| {
        const inner = @typeInfo(field.type);
        std.debug.print("\tname: {s}, type: {s}\n", .{field.name, @typeName(field.type)});
        switch (inner) {
            .Struct => |inner_struct| {
                inline for (inner_struct.fields) |inner_field| {
                    std.debug.print("\t\tname: {s}, type: {s}\n", .{inner_field.name, @typeName(inner_field.type)});

                    const inner_inner = @typeInfo(inner_field.type);

                    switch (inner_inner) {
                        .Struct => |inner_inner_struct| {
                            inline for (inner_inner_struct.fields) |inner_inner_field| {
                                std.debug.print("\t\t\tname: {s}, type: {s}\n", .{inner_inner_field.name, @typeName(inner_inner_field.type)});

                                // var anyopaque_ptr = inner_inner_field.default_value.?;
                                // const res_anyopaque = @constCast(anyopaque_ptr);
                                // const res = @as([*]u8, @ptrCast(res_anyopaque));
                                // std.debug.print("res: {any}\n", .{res[0..1]});
                                // _ = &anyopaque_ptr;
                            }
                        },
                        else => {}
                    }
                }
            },
            .Pointer => {},
            else => {},
        }
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

// test "yas save test" {
//     const a: u32 = 3;
//     const b: u16 = 4;
//     const c: f32 = 3.14;

//     const input_flags: usize = mem | json;

//     const yas_obj = YasObject("myobject", .{a, b, c});
//     var buf = try save(input_flags, yas_obj);
//     _ = &buf;

//     try testing.expectEqualStrings(
//         "yas.yas.YasObjectAux(struct{comptime u32 = 3, comptime u16 = 4, comptime f32 = 3.140000104904175})", 
//         @typeName(@TypeOf(yas_obj))
//     );
// }