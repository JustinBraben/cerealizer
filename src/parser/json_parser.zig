const std = @import("std");
const JsonTokenizer = @import("../tokenizer/json_tokenizer.zig").JsonTokenizer;
const JsonToken = @import("../tokenizer/json_tokenizer.zig").JsonToken;

const JsonParseError = error{
    UnexpectedToken,
    UnexpectedComma,
    UnexpectedColon,
    UnexpectedNumber,
    UnexpectedFalse,
    UnexpectedTrue,
    UnexpectedNull,
    UnexpectedEof,
    MissingComma,
    MissingColon,
    InvalidObjectKey,
    InvalidValue,
};

// pub const JsonParser = struct {
//     tokenizer: JsonTokenizer,

//     pub fn init(source: [:0]const u8) JsonParser {
//         return .{
//             .tokenizer = JsonTokenizer.init(source),
//         };
//     }

//     pub fn parse(self: *JsonParser) JsonParseError!void {
//         try self.parseValue();
//         const last_token = self.nextNonWhitespace();
//         if (last_token.tag != .eof) {
//             return JsonParseError.UnexpectedToken;
//         }
//     }

//     fn parseValue(self: *JsonParser) JsonParseError!void {
//         const token = self.nextNonWhitespace();
//         switch (token.tag) {
//             .l_brace => self.parseObject() catch |err| return err,
//             .l_bracket => self.parseArray() catch |err| return err,
//             .string, .number, .whitespace, .keyword_true, .keyword_false, .keyword_null => {},
//             else => return JsonParseError.InvalidValue,
//         }
//     }

//     fn parseObject(self: *JsonParser) JsonParseError!void {
//         var first = true;
//         while (true) {
//             const token = self.nextNonWhitespace();
//             switch (token.tag) {
//                 .r_brace => {
//                     // If we encounter a closing brace, we're done parsing the object
//                     // It's valid to have an empty object, so we break regardless of 'first'
//                     break;
//                 },
//                 .comma => {
//                     // A comma is only valid if we've already parsed at least one key-value pair
//                     if (first) return JsonParseError.UnexpectedComma;
//                     // After a comma, we expect another key-value pair
//                     first = false;
//                 },
//                 .string => {
//                     // If it's not the first key-value pair, we should have seen a comma
//                     if (!first) return JsonParseError.MissingComma;

//                      // Parse the colon after the key
//                     const colon_token = self.tokenizer.next();
//                     if (colon_token.tag != .colon) return JsonParseError.MissingColon;

//                     // Parse the value
//                     try self.parseValue();

//                     // We've successfully parsed a key-value pair
//                     first = false;
//                 },
//                 else => return JsonParseError.InvalidObjectKey,
//             }
//             first = false;
//         }
//     }

//     fn parseArray(self: *JsonParser) JsonParseError!void {
//         var first = true;
//         while (true) {
//             const token = self.nextNonWhitespace();
//             switch (token.tag) {
//                 .r_bracket => {
//                     // If we encounter a closing bracket, we're done parsing the array
//                     // It's valid to have an empty array, so we break regardless of 'first'
//                     break;
//                 },
//                 .comma => {
//                     // A comma is only valid if we've already parsed at least one value
//                     if (first) return JsonParseError.UnexpectedComma;
//                     // After a comma, we expect another value
//                     first = false;
//                 },
//                 else => {
//                     // If it's not the first value, we should have seen a comma
//                     if (!first) return JsonParseError.MissingComma;
                    
//                     // "Un-consume" the token so parseValue can process it
//                     self.tokenizer.index = token.loc.start;
                    
//                     // Parse the value
//                     try self.parseValue();
                    
//                     // We've successfully parsed a value
//                     first = false;
//                 },
//             }
//         }
//     }

//     pub fn printCurrentToken(self: *JsonParser, token: JsonToken) void {
//         std.debug.print("Token: {s}, Content: {s}\n", .{@tagName(token.tag), self.tokenizer.buffer[token.loc.start..token.loc.end]});
//     }

//     fn nextNonWhitespace(self: *JsonParser) JsonToken {
//         while (true) {
//             const token = self.tokenizer.next();
//             if (token.tag != .whitespace) {
//                 return token;
//             }
//         }
//     }

//     pub fn isValid(source: [:0]const u8) bool {
//         var parser = JsonParser.init(source);
//         parser.parse() catch {
//             return false;
//         };
//         return true;
//     }
// };

pub const JsonParser = struct {
    tokenizer: JsonTokenizer,

    pub fn init(source: [:0]const u8) JsonParser {
        return .{
            .tokenizer = JsonTokenizer.init(source),
        };
    }

    pub fn parse(self: *JsonParser) JsonParseError!void {
        while (true) {
            const cur_token = self.tokenizer.next();

            switch (cur_token.tag) {
                .l_brace => {
                    // Parse a json object
                    try self.parseObject();
                },
                .invalid => {
                    return JsonParseError.UnexpectedToken;
                },
                .eof => {
                    break;
                },
                else => {
                    return JsonParseError.UnexpectedToken;
                }
            }
        }
    }

    pub fn parseObject(self: *JsonParser) JsonParseError!void {
        var first_parse = true;
        var value_allowed = false;
        var colon_allowed = false;
        var comma_allowed = false;
        var comma_expected = false;
        while (true) {
            const cur_token = self.tokenizer.next();
            switch (cur_token.tag) {
                .l_bracket => {
                    try self.parseArray();
                    comma_allowed = true;
                },
                .l_brace => {
                    try self.parseObject();
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
                    }
                    else {
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
                .eof => {
                    return JsonParseError.UnexpectedEof;
                },
                else => {
                    // Unhandled
                }
            }
        }
    }

    pub fn parseArray(self: *JsonParser) JsonParseError!void {
        var first_parse = true;
        var comma_allowed = false;
        while (true) {
            const cur_token = self.tokenizer.next();
            switch (cur_token.tag) {
                .r_bracket => {
                    break;
                },
                .whitespace => {
                    continue;
                },
                .l_brace => {
                    try self.parseObject();
                    comma_allowed = true;
                },
                .comma => {
                    if (!comma_allowed) return JsonParseError.UnexpectedComma;
                    comma_allowed = false;
                },
                .string => {
                    first_parse = false;
                    comma_allowed = true;
                },
                .number => {
                    first_parse = false;
                    comma_allowed = true;
                },
                .eof => {
                    return JsonParseError.UnexpectedEof;
                },
                else => {
                    // Unhandled
                }
            }
        }
    }
};

test "valid simple json" {
    const valid_simple_json = 
        \\{ 
        \\  "name": "John Doe",
        \\  "age": 20 
        \\}
    ;
    var parser = JsonParser.init(valid_simple_json);
    const res = parser.parse() catch |err| return err;
    try std.testing.expect(@TypeOf(res) == void);
}

test "valid multiline simple json" {
    const valid_simple_json = 
        \\{
        \\    "name": "John Doe",
        \\    "age": 20,
        \\    "hobbies": ["reading","swimming",{},23]
        \\}
    ;
    var parser = JsonParser.init(valid_simple_json);
    const res = parser.parse() catch |err| return err;
    try std.testing.expect(@TypeOf(res) == void);
}

test "valid json" {
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
    var parser = JsonParser.init(valid_json);
    var res = parser.parse() catch |err| return err;
    try std.testing.expect(@TypeOf(res) == void);

    const valid_json_2 = 
    \\{
    \\  "obj": {
    \\      "name": "Bob"
    \\  }
    \\}
    ;
    parser = JsonParser.init(valid_json_2);
    res = parser.parse() catch |err| return err;
    try std.testing.expect(@TypeOf(res) == void);
}

test "invalid json" {
    const invalid_json = 
        \\{
        \\  "name": "John Doe"
        \\  "age": 30,
        \\  "is_active": true,
        \\  "hobbies": ["reading", "swimming"],
        \\  "address": {
        \\    "street": "123 Main St",
        \\    "city": "Anytown",
        \\  }
        \\}
    ;
    var parser = JsonParser.init(invalid_json);
    try std.testing.expectError(JsonParseError.MissingComma, parser.parse());
}