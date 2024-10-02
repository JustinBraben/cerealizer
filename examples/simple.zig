const std = @import("std");
const Allocator = std.mem.Allocator;
const cerealizer = @import("cerealizer");
const log = std.log.scoped(.simple_example);

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
}
