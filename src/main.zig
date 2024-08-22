const std = @import("std");
const Allocator = std.mem.Allocator;
const cerealizer = @import("cerealizer");

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

    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    var original: ServerList = .{
        .allocator = allocator,
        .servers = std.ArrayList(Server).init(allocator),
    };
    defer original.servers.deinit();
    _ = &original;

    // var out: cerealizer.ResizableOutputBuffer = undefined;
    // var serializer = cerealizer.PrettyJsonSerializer(out);

    // serializer.save(original) catch |err| {
    //     std.debug.print("Serializer save error: ", .{err});
    //     return err;
    // };

    // var loaded: ServerList = undefined;
    // loaded.servers.clear();

    
    // pods::InputBuffer in(out.data(), out.size());
    // pods::JsonDeserializer<decltype(in)> deserializer(in);
    // if (deserializer.load(loaded) != pods::Error::NoError)
    // {
    //     std::cerr << "deserialization error\n";
    //     return EXIT_FAILURE;
    // }

    // const std::string json(out.data(), out.size());
    // std::cout << json << '\n';

    // return EXIT_SUCCESS;
}
