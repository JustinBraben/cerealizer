# Cerealizer

Cerealizer is a serialization library for Zig, inspired by the YAS (Yet Another Serialization) library for C++. This project is a hobby endeavor aimed at learning Zig while creating a useful tool for the Zig community.

## Features

- Simple and intuitive API
- Support for basic Zig types
- Extensible for custom types
- Compact binary format
- [Add more features as you implement them]

## Installation

To use Cerealizer in your Zig project, you can add it as a dependency in your `build.zig.zon` file:

```zig
.dependencies = .{
    .cerealizer = .{
        .url = "https://github.com/yourusername/cerealizer/archive/v0.1.0.tar.gz",
        .hash = "12345...", // Replace with the actual hash
    },
},
```

Then, in your `build.zig`, add:

```zig
const cerealizer = b.dependency("cerealizer", .{
    .target = target,
    .optimize = optimize,
});
exe.addModule("cerealizer", cerealizer.module("cerealizer"));
```

## Usage

Here's a simple example of how to use Cerealizer:

```zig
const std = @import("std");
const Cerealizer = @import("cerealizer").Cerealizer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a Cerealizer instance
    var cerealizer = try Cerealizer.init(allocator);
    defer cerealizer.deinit();

    // Serialize data
    const original = @as(i32, 42);
    try cerealizer.serialize(original);

    // Deserialize data
    const deserialized = try cerealizer.deserialize(i32);

    std.debug.print("Original: {}, Deserialized: {}\n", .{ original, deserialized });
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
- [ ] [Add more items as needed]

---

*Note: This project is a work in progress and is primarily for learning purposes. Use in production environments is not recommended at this stage.*
