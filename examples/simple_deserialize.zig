const std = @import("std");
const Allocator = std.mem.Allocator;
const cerealizer = @import("cerealizer");
const log = std.log.scoped(.simple_deserialize_example);

const debug = std.debug;
const io = std.io;

const Person = struct {
    name: []const u8,
    age: u32,
    // hobbies: []const []const u8,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    //const json_string = "{\"name\":\"Alice\",\"age\":30,\"hobbies\":[\"reading\",\"cycling\"]}";
    const json_string = "{\"name\":\"Alice\",\"age\":30,}";
    log.info("json_string to deserialize: {s}\n", .{json_string});
    var stream = std.io.fixedBufferStream(json_string);
    var reader: @TypeOf(stream.reader()) = undefined;
    reader = stream.reader();

    const Deserializer = cerealizer.Deserialize(Person);
    const person = try Deserializer.toObject(allocator, reader);
    defer allocator.free(person.name);
    // defer allocator.free(person.hobbies);
    // for (person.hobbies) |hobby| {
    //     allocator.free(hobby);
    // }

    //std.debug.print("Name: {s}\n", .{person.name});
    std.debug.print("Name: {s}, Age: {d}\n", .{person.name, person.age});
    // for (person.hobbies) |hobby| {
    //     std.debug.print("Hobby: {s}\n", .{hobby});
    // }

    const valid_simple_json = 
        \\{ "name":"John Doe","age":20 }
    ;

    var parser = cerealizer.JsonParser.init(valid_simple_json);
    try parser.parse();
}