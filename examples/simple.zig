const std = @import("std");
const Allocator = std.mem.Allocator;
const cerealizer = @import("cerealizer");
const log = std.log.scoped(.simple_example);

const debug = std.debug;
const io = std.io;

pub const Server = struct {
    address: []const u8,    // no default value
    port: u16,              // default value
};

pub const ServerList = struct {
    allocator: Allocator,
    servers: std.ArrayList(Server),
};

const Person = struct {
    name: []const u8,
    age: u32,
    hobbies: []const []const u8,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const person = Person{
        .name = "Alice",
        .age = 30,
        .hobbies = &[_][]const u8{ "reading", "cycling" },
    };
    
    var serialized = cerealizer.Serialize(person);
    const json_string = try serialized.toOwnedString(allocator);
    defer allocator.free(json_string);

    log.info("Serialized: {s}\n", .{json_string});

    // var stream = std.io.fixedBufferStream(json_string);
    // var reader = stream.reader();
    // const deserializer = cerealizer.Deserialize(Person);
    // const deserialized_object = try deserializer.toObject(allocator, reader);
    // defer allocator.free(deserialized_object.name);
    // defer allocator.free(deserialized_object.hobbies);
    // for (deserialized_object.hobbies) |hobby| {
    //     allocator.free(hobby);
    // }

    // std.debug.print("Name: {s}, Age: {d}\n", .{deserialized_object.name, deserialized_object.age});
    // for (deserialized_object.hobbies) |hobby| {
    //     std.debug.print("Hobby: {s}\n", .{hobby});
    // }

    // _ = &reader;

    debug.print("Print from simple.zig example\n", .{});
}