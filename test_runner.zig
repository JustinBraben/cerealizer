const std = @import("std");
const builtin = @import("builtin");
const tty = std.io.tty;

// Ansi escape codes
const RED = "\x1b[31;1m";
const GREEN = "\x1b[32;1m";
const CYAN = "\x1b[36;1m";
const WHITE = "\x1b[37;1m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";
const RESET = "\x1b[0m";

pub fn main() !void {
    const stdout = std.io.getStdOut();
    const config = tty.detectConfig(stdout);
    const out = stdout.writer();

    for (builtin.test_functions) |t| {
        const start = std.time.milliTimestamp();
        std.testing.allocator_instance = .{};
        const result = t.func();
        const elapsed = std.time.milliTimestamp() - start;

        const name = extractName(t);
        if (std.testing.allocator_instance.deinit() == .leak) {
            try config.setColor(out, .red);
            try std.fmt.format(out, "{s} leaked memory\n", .{name});
        }

        if (result) |_| {
            try config.setColor(out, .green);
            try std.fmt.format(out, "{s} passed - ({d}ms)\n", .{name, elapsed});
        } else |err| {
            try config.setColor(out, .red);
            try std.fmt.format(out, "{s} failed - {}\n", .{name, err});
        }
    }
}

fn extractName(t: std.builtin.TestFn) []const u8 {
    const marker = std.mem.lastIndexOf(u8, t.name, ".test.") orelse return t.name;
    return t.name[marker+6..];
}