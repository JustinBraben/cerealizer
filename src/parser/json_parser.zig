const std = @import("std");
const JsonTokenizer = @import("../tokenizer/json_tokenizer.zig").JsonTokenizer;
const JsonToken = @import("../tokenizer/json_tokenizer.zig").JsonToken;

const JsonParseError = error{
    UnexpectedToken,
    UnexpectedComma,
    UnexpectedColon,
    UnexpectedString,
    UnexpectedNumber,
    UnexpectedFalse,
    UnexpectedTrue,
    UnexpectedNull,
    UnexpectedEof,
    MissingComma,
    MissingColon,
    InvalidObjectKey,
    InvalidValue,
    InvalidCharacter,
    OutOfMemory,
};

// pub fn printCurrentToken(self: *JsonParser, token: JsonToken) void {
//     std.debug.print("Token: {s}, Content: {s}\n", .{@tagName(token.tag), self.tokenizer.buffer[token.loc.start..token.loc.end]});
// }

pub const JsonValue = union(enum) {
    Object: std.StringArrayHashMap(JsonValue),
    Array: std.ArrayList(JsonValue),
    String: []const u8,
    Number: f64,
    Bool: bool,
    Null: void,

    pub fn deinit(self: *JsonValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .Object => |*map| {
                var it = map.iterator();
                while (it.next()) |entry| {
                    entry.value_ptr.deinit(allocator);
                }
                map.deinit();
            },
            .Array => |*list| {
                for (list.items) |*item| {
                    item.deinit(allocator);
                }
                list.deinit();
            },
            .String => |str| allocator.free(str),
            else => {},
        }
    }
};

pub const JsonParser = struct {
    allocator: std.mem.Allocator,
    tokenizer: JsonTokenizer,
    root: JsonValue,

    pub fn init(source: [:0]const u8, gpa: std.mem.Allocator) JsonParser {
        return .{
            .allocator = gpa,
            .tokenizer = JsonTokenizer.init(source),
            .root = undefined,
        };
    }

    pub fn deinit(self: *JsonParser) void {
        self.root.deinit(self.allocator);
    }

    pub fn parse(self: *JsonParser) JsonParseError!void {
        while (true) {
            const cur_token = self.tokenizer.next();

            switch (cur_token.tag) {
                .l_brace => {
                    // // Old
                    // try self.parseObject();
                    // New
                    self.root = try self.parseObject();
                },
                .eof => {
                    break;
                },
                else => {
                    return JsonParseError.UnexpectedToken;
                },
            }
        }
    }

    pub fn parseObject(self: *JsonParser) JsonParseError!JsonValue {
        var hash_map = std.StringArrayHashMap(JsonValue).init(self.allocator);
        errdefer {
            for (hash_map.keys()) |key| {
                self.allocator.free(key);
            }
            hash_map.deinit();
        }

        var first_parse = true;
        var value_allowed = false;
        var colon_allowed = false;
        var comma_allowed = false;
        var comma_expected = false;

        while (true) {
            const cur_token = self.tokenizer.next();
            switch (cur_token.tag) {
                .l_bracket => {
                    // // Old
                    // try self.parseArray();
                    // comma_allowed = true;
                    // // New
                    const nested_array = try self.parseArray();
                    try hash_map.put("Array", nested_array);
                    comma_allowed = true;
                },
                .l_brace => {
                    // // Old
                    // try self.parseObject();
                    // // New
                    const nested_object = try self.parseObject();
                    try hash_map.put("Object", nested_object);
                },
                .r_brace => {
                    break;
                },
                .whitespace => {
                    continue;
                },
                .comma => {
                    if (!comma_allowed) return JsonParseError.UnexpectedComma;

                    value_allowed = false;
                    comma_expected = false;
                },
                .colon => {
                    if (!colon_allowed) return JsonParseError.UnexpectedColon;
                    value_allowed = true;
                },
                .string => {
                    first_parse = false;

                    if (comma_expected) return JsonParseError.MissingComma;

                    if (!value_allowed) {
                        colon_allowed = true;
                        comma_allowed = false;
                        comma_expected = false;
                    } else {
                        colon_allowed = false;
                        comma_allowed = true;
                        comma_expected = true;
                    }
                },
                .number => {
                    if (!value_allowed) return JsonParseError.UnexpectedNumber;

                    comma_allowed = true;
                    colon_allowed = false;
                    value_allowed = false;
                },
                .keyword_false => {
                    if (!value_allowed) return JsonParseError.UnexpectedFalse;

                    comma_allowed = true;
                    colon_allowed = false;
                    value_allowed = false;
                },
                .keyword_true => {
                    if (!value_allowed) return JsonParseError.UnexpectedTrue;

                    comma_allowed = true;
                    colon_allowed = false;
                    value_allowed = false;
                },
                .keyword_null => {
                    if (!value_allowed) return JsonParseError.UnexpectedNull;

                    comma_allowed = true;
                    colon_allowed = false;
                    value_allowed = false;
                },
                .eof => return JsonParseError.UnexpectedEof,
                else => return JsonParseError.UnexpectedToken,
            }
        }

        return JsonValue{ .Object = hash_map };
    }

    pub fn parseArray(self: *JsonParser) JsonParseError!JsonValue {
        var array = std.ArrayList(JsonValue).init(self.allocator);
        errdefer {
            for (array.items) |*item| {
                item.deinit(self.allocator);
            }
            array.deinit();
        }

        var value_allowed = true;
        var comma_allowed = false;

        while (true) {
            const cur_token = self.tokenizer.next();
            switch (cur_token.tag) {
                .r_bracket => {
                    break;
                },
                .whitespace => continue,
                .l_brace => {
                    return try self.parseObject();
                },
                .comma => {
                    if (!comma_allowed) return JsonParseError.UnexpectedComma;
                    value_allowed = true;
                    comma_allowed = false;
                },
                .string => {
                    if (!value_allowed) return JsonParseError.UnexpectedString;
                    const string_value = try self.allocator.dupe(u8, self.tokenizer.buffer[cur_token.loc.start..cur_token.loc.end]);
                    errdefer self.allocator.free(string_value);
                    try array.append(JsonValue{ .String = string_value });
                    value_allowed = false;
                    comma_allowed = true;
                },
                .number => {
                    if (!value_allowed) return JsonParseError.UnexpectedNumber;
                    const number_value = try std.fmt.parseFloat(f64, self.tokenizer.buffer[cur_token.loc.start..cur_token.loc.end]);
                    try array.append(JsonValue{ .Number = number_value });
                    value_allowed = false;
                    comma_allowed = true;
                },
                .keyword_false => {
                    if (!value_allowed) return JsonParseError.UnexpectedFalse;
                    try array.append(JsonValue{ .Bool = false });
                    value_allowed = false;
                    comma_allowed = true;
                },
                .keyword_true => {
                    if (!value_allowed) return JsonParseError.UnexpectedTrue;
                    try array.append(JsonValue{ .Bool = true });
                    value_allowed = false;
                    comma_allowed = true;
                },
                .keyword_null => {
                    if (!value_allowed) return JsonParseError.UnexpectedNull;
                    try array.append(JsonValue{ .Null = {} });
                    value_allowed = false;
                    comma_allowed = true;
                },
                .eof => {
                    return JsonParseError.UnexpectedEof;
                },
                else => {
                    // Unhandled
                },
            }
        }

        return JsonValue{ .Array = array };
    }
};

test "valid simple json" {
    const test_allocator = std.testing.allocator;
    const valid_simple_json =
        \\{ 
        \\  "name": "John Doe",
        \\  "age": 20 
        \\}
    ;
    var parser = JsonParser.init(valid_simple_json, test_allocator);
    defer parser.deinit();
    const res = parser.parse() catch |err| return err;
    try std.testing.expect(@TypeOf(res) == void);
}

test "valid multiline simple json" {
    const test_allocator = std.testing.allocator;
    const valid_simple_json =
        \\{
        \\    "name": "John Doe",
        \\    "age": 20,
        \\    "hobbies": ["reading","swimming",23]
        \\}
    ;
    var parser = JsonParser.init(valid_simple_json, test_allocator);
    defer parser.deinit();
    const res = parser.parse() catch |err| return err;
    try std.testing.expect(@TypeOf(res) == void);
}

test "valid json" {
    const test_allocator = std.testing.allocator;
    const valid_json =
        \\{
        \\  "name": "John Doe",
        \\  "age": 30,
        \\  "is_active": true,
        \\  "hobbies": ["reading", "swimming"],
        \\  "address": {
        \\    "street": "123 Main St",
        \\    "city": "Anytown"
        \\  }
        \\}
    ;
    var parser = JsonParser.init(valid_json, test_allocator);
    const res = parser.parse() catch |err| return err;
    try std.testing.expect(@TypeOf(res) == void);
    parser.deinit();

    // const valid_json_2 =
    // \\{
    // \\  "obj": {
    // \\      "name": "Bob"
    // \\  }
    // \\}
    // ;
    // parser = JsonParser.init(valid_json_2, test_allocator);
    // defer parser.deinit();
    // res = parser.parse() catch |err| return err;
    // try std.testing.expect(@TypeOf(res) == void);
}

// test "invalid json" {
//     const test_allocator = std.testing.allocator;
//     const invalid_json =
//         \\{
//         \\  "name": "John Doe"
//         \\  "age": 30,
//         \\  "is_active": true,
//         \\  "hobbies": ["reading", "swimming"],
//         \\  "address": {
//         \\    "street": "123 Main St",
//         \\    "city": "Anytown",
//         \\  }
//         \\}
//     ;
//     var parser = JsonParser.init(invalid_json, test_allocator);
//     defer parser.deinit();
//     try std.testing.expectError(JsonParseError.MissingComma, parser.parse());
// }
