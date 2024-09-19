const std = @import("std");
const Allocator = std.mem.Allocator;
const cerealizer = @import("cerealizer");
const serialize = cerealizer.yas.serialize;
const SerializeOptionsMaskFlags = cerealizer.yas.SerializeOptionsMaskFlags;
// const Cerializer = cerealizer.Cerializer;
// const Decerealizer = cerealizer.Decerealizer;
// const yas = cerealizer.yas;
// const log = std.log.scoped(.std_lib_example);

// const debug = std.debug;
// const io = std.io;

const Place = struct { lat: f32, long: f32 };

pub fn main() !void {
   const ally = std.heap.page_allocator;
    var data = std.ArrayList(u8).init(ally);
    defer data.deinit();

    const place_1 = Place{
        .lat = 51.997664,
        .long = -0.740687,
    };
    const options = SerializeOptionsMaskFlags{
        .mem = true,
        .binary = true,
        .little_endian = true,
    };

    try serialize(data.writer(), Place, place_1, options);
    std.debug.print("serialized: {s}\n", .{data.items});
}