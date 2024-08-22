const std = @import("std");
const Allocator = std.mem.Allocator;
const cerealizer = @import("cerealizer");

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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var original: ServerList = .{
        .allocator = allocator,
        .servers = std.ArrayList(Server).init(allocator),
    };
    defer original.servers.deinit();
    _ = &original;

    debug.print("Print from simple.zig example\n", .{});
}