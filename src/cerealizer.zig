const std = @import("std");
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

// Runs tests found in these imports
comptime {
    _ = @import("yas/yas.zig");
    _ = @import("yas/flags.zig");
}
