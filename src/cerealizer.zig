const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
pub const yas = @import("yas/yas.zig");

pub fn Cerializer(comptime input_flags: usize) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        buf: std.ArrayList(u8),

        pub fn init(allocator: Allocator, value: anytype) !Self {

            if (yas.flags.isJsonArchive(input_flags)) {
                var string = std.ArrayList(u8).init(allocator);
                errdefer string.deinit();
                try std.json.stringify(value, .{}, string.writer());

                return Self{
                    .allocator = allocator,
                    .buf = string,
                };
            }

            if (yas.flags.isBinaryArchive(input_flags)) {
                var binary = std.ArrayList(u8).init(allocator);
                errdefer binary.deinit();

                const ValueType = @TypeOf(value);

                switch (@typeInfo(ValueType)) {
                    .Struct => |captured_struct| {
                        switch (captured_struct.layout) {
                            .auto => {},
                            .@"extern" => {},
                            .@"packed" => {
                                // std.debug.print("captured_struct.layout: {}\n", .{captured_struct.layout});
                                // const val = ValueType{ .lat = 40.2, .long = -74.2 };
                                // const val_to_bits: ValueType = @bitCast(val);
                                // std.debug.print("val_to_bits: {}\n", .{val_to_bits});
                            },
                        }
                    },
                    else => std.debug.print("Unsupported Binary\n", .{}),
                }
            }

            return Self{
                .allocator = allocator,
                .buf = std.ArrayList(u8).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.buf.deinit();
        }
    };
}

pub fn Decerealizer(comptime T: type, comptime input_flags: usize) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        parsed_output: std.json.Parsed(T),

        pub fn init(allocator: Allocator, slice: []const u8) !Self {

            if (yas.flags.isJsonArchive(input_flags)) {
                const parsed = try std.json.parseFromSlice(
                    T,
                    allocator,
                    slice,
                    .{},
                );
                errdefer parsed.deinit();

                return Self{
                    .allocator = allocator,
                    .parsed_output = parsed,
                };
            }

            return Self{
                .allocator = allocator,
                .parsed_output = undefined,
            };
        }

        pub fn deinit(self: *Self) void {
            self.parsed_output.deinit();
        }
    };
}

// test "cerealizer test" {
//     const Place = struct { lat: f32, long: f32 };
//     const ally = std.heap.page_allocator;

//     const x = Place{
//         .lat = 51.997664,
//         .long = -0.740687,
//     };

//     const input_flags = yas.mem | yas.json;

//     var serializer = try Cerializer(input_flags).init(ally, x);
//     defer serializer.deinit();

//     try testing.expect(
//         std.mem.eql(
//             u8, 
//             serializer.buf.items, 
//             "{\"lat\":5.199766540527344e1,\"long\":-7.406870126724243e-1}"
//         )
//     );

//     const input_slice = 
//         \\{ "lat": 40.684540, "long": -74.401422 }
//     ;
//     const expected = Place{
//         .lat = 40.684540,
//         .long = -74.401422,
//     };

//     var deserializer = try Decerealizer(Place, input_flags).init(ally, input_slice);
//     defer deserializer.deinit();
//     const place = deserializer.parsed_output.value;

//     try testing.expectEqualDeep(expected, place);
// }

// test "cerealizer packed test" {
//     const Place = packed struct { lat: f32, long: f32 };
//     const ally = std.heap.page_allocator;

//     const x = Place{
//         .lat = 51.997664,
//         .long = -0.740687,
//     };

//     const input_flags = yas.mem | yas.binary;

//     var serializer = try Cerializer(input_flags).init(ally, x);
//     defer serializer.deinit();

//     // std.debug.print("{any}\n", .{serializer.buf.items});
// }

// Runs tests found in these imports
comptime {
    _ = @import("yas/yas.zig");
    _ = @import("yas/flags.zig");
}
