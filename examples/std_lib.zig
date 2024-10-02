const std = @import("std");
const Allocator = std.mem.Allocator;
const cerealizer = @import("cerealizer");
const log = std.log.scoped(.std_lib_example);

const debug = std.debug;
const io = std.io;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var nums_1 = std.ArrayList(u32).init(allocator);
    defer nums_1.deinit();

    try nums_1.append(2);

    // const serialized = cerealizer.Serialize(nums_1);
    // const json_string = try serialized.toOwnedString(allocator);
    // defer allocator.free(json_string);

    // std.debug.print("Serialized: {s}\n", .{json_string});

    debug.print("Print from std-lib.zig example\n", .{});
}
