const std = @import("std");
const JsonTokenizer = @import("../tokenizer/json_tokenizer.zig").JsonTokenizer;
const JsonToken = @import("../tokenizer/json_tokenizer.zig").JsonToken;

const JsonParseError = error{
    UnexpectedToken,
    UnexpectedComma,
    MissingComma,
    MissingColon,
    InvalidObjectKey,
    InvalidValue,
};

pub const JsonParser = struct {
    tokenizer: JsonTokenizer,

    pub fn init(source: [:0]const u8) JsonParser {
        return .{
            .tokenizer = JsonTokenizer.init(source),
        };
    }

    pub fn parse(self: *JsonParser) JsonParseError!void {
        try self.parseValue();
        const last_token = self.tokenizer.next();
        if (last_token.tag != .eof) {
            return JsonParseError.UnexpectedToken;
        }
    }

    fn parseValue(self: *JsonParser) JsonParseError!void {
        const token = self.tokenizer.next();
        switch (token.tag) {
            .l_brace => self.parseObject() catch |err| return err,
            .l_bracket => self.parseArray() catch |err| return err,
            .string => {},
            .number => {},
            .whitespace => {},
            .keyword_true, .keyword_false, .keyword_null => {},
            else => return JsonParseError.InvalidValue,
        }
    }

    fn parseObject(self: *JsonParser) JsonParseError!void {
        var first = true;
        while (true) {
            const token = self.tokenizer.next();
            switch (token.tag) {
                .r_brace => break,
                .comma => {
                    if (first) return JsonParseError.UnexpectedComma;
                },
                .string => {
                    if (!first) {
                        const prev_token = self.tokenizer.next();
                        if (prev_token.tag != .comma) return JsonParseError.MissingComma;
                    }
                    const colon_token = self.tokenizer.next();
                    if (colon_token.tag != .colon) return JsonParseError.MissingColon;
                    self.parseValue() catch |err| return err;
                },
                .whitespace => {
                    continue;
                },
                else => return JsonParseError.InvalidObjectKey,
            }

            first = false;
        }
    }

    fn parseArray(self: *JsonParser) JsonParseError!void {
        var first = true;
        while (true) {
            const token = self.tokenizer.next();
            switch (token.tag) {
                .r_bracket => break,
                .comma => {
                    if (first) return JsonParseError.UnexpectedComma;
                },
                else => {
                    if (!first) {
                        const prev_token = self.tokenizer.next();
                        if (prev_token.tag != .comma) return JsonParseError.MissingComma;
                    }
                    self.parseValue() catch |err| return err;
                },
            }
            first = false;
        }
    }

    pub fn printCurrentToken(self: *JsonParser, token: JsonToken) void {
        std.debug.print("Token: {s}, Content: {s}\n", .{@tagName(token.tag), self.tokenizer.buffer[token.loc.start..token.loc.end]});
    }

    pub fn isValid(source: [:0]const u8) bool {
        var parser = JsonParser.init(source);
        parser.parse() catch {
            return false;
        };
        return true;
    }
};

test "valid simple json" {
    const valid_simple_json = 
        \\{ "name":"John Doe" }
    ;
    var parser = JsonParser.init(valid_simple_json);
    parser.parse() catch |err| return err;
    try std.testing.expect(JsonParser.isValid(valid_simple_json));
}

// test "valid json" {
//     const valid_json = 
//         \\{
//         \\  "name": "John Doe",
//         \\  "age": 30,
//         \\  "is_active": true,
//         \\  "hobbies": ["reading", "swimming"],
//         \\  "address": {
//         \\    "street": "123 Main St",
//         \\    "city": "Anytown"
//         \\  }
//         \\}
//     ;
//     try std.testing.expect(JsonParser.isValid(valid_json));
// }

// test "invalid json" {
//     const invalid_json = 
//         \\{
//         \\  "name": "John Doe",
//         \\  "age": 30,
//         \\  "is_active": true,
//         \\  "hobbies": ["reading", "swimming"],
//         \\  "address": {
//         \\    "street": "123 Main St",
//         \\    "city": "Anytown",
//         \\  }
//         \\}
//     ;
//     try std.testing.expect(!JsonParser.isValid(invalid_json));
// }