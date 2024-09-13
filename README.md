# Cerealizer

Cerealizer is a serialization library for Zig, inspired by the YAS (Yet Another Serialization) library for C++. This project is a hobby endeavor aimed at learning Zig while creating a useful tool for the Zig community.

## Features

- Simple and intuitive API
- Support for basic Zig types
- Extensible for custom types
- Compact binary format

## Installation

To use Cerealizer in your Zig project, you can add it as a dependency in your `build.zig.zon` file:

```zig
.dependencies = .{
    .cerealizer = .{
        .url = "https://github.com/JustinBraben/cerealizer/archive/df20948eaa944f923e5f8652cd4620a1f9eced31.tar.gz",
        // Replace with the actual .hash, when building it will tell you what it expects
    },
},
```

Then, in your `build.zig`, add:

```zig
const cerealizer = b.dependency("cerealizer", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("cerealizer", cerealizer.module("cerealizer"));
```

## Usage

Here's a simple example of how to use Cerealizer:

```zig
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
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by the [YAS (Yet Another Serialization) library](https://github.com/niXman/yas) for C++
- Thanks to the Zig community for their support and resources

## TODO

- [ ] Implement support for more complex types
- [ ] Add benchmarking
- [ ] Improve documentation
- [ ] Add more examples

---

*Note: This project is a work in progress and is primarily for learning purposes. Use in production environments is not recommended at this stage.*
