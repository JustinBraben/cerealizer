const std = @import("std");
const Allocator = std.mem.Allocator;
const cerealizer = @import("cerealizer");
const Cerializer = cerealizer.Cerializer;
const Decerealizer = cerealizer.Decerealizer;
const yas = cerealizer.yas;
const log = std.log.scoped(.std_lib_example);

const debug = std.debug;
const io = std.io;

const Place = struct { lat: f32, long: f32 };

pub fn main() !void {
    const ally = std.heap.page_allocator;

    const x = Place{
        .lat = 51.997664,
        .long = -0.740687,
    };

    const input_flags = yas.mem | yas.json;

    var serializer = try Cerializer(input_flags).init(ally, x);
    defer serializer.deinit();

    std.debug.print("{s}\n", .{serializer.buf.items});

    const input_slice = 
        \\{ "lat": 40.684540, "long": -74.401422 }
    ;

    var deserializer = try cerealizer.Decerealizer(Place, input_flags).init(ally, input_slice);
    defer deserializer.deinit();
    const place = deserializer.parsed_output.value;

    std.debug.print("deserialized: {any}\n", .{place});
    
    std.debug.print("lat: {d}\n", .{place.lat});
    std.debug.print("long: {d}\n", .{place.long});

    // log.info("Serialized: {s}\n", .{json_string});
}