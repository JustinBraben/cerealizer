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
    
    const serialized = cerealizer.Serialize(person);
    const json_string = try serialized.toOwnedString(allocator);
    defer allocator.free(json_string);

    log.info("Serialized: {s}\n", .{json_string});

    debug.print("Print from simple.zig example\n", .{});
}