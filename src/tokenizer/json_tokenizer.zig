const std = @import("std");

pub const JsonToken = struct {
    tag: Tag,
    loc: Loc,

    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    pub const keywords = std.StaticStringMap(Tag).initComptime(.{
        .{ "true", .keyword_true },
        .{ "false", .keyword_false },
    });

    pub fn getKeyword(bytes: []const u8) ?Tag {
        return keywords.get(bytes);
    }

    pub const Tag = enum {
        invalid,
        identifier,
        l_bracket,
        r_bracket,
        l_brace,
        r_brace,
        colon,
        comma,
        string,
        number,
        period,
        keyword,
        whitespace,
        eof,
        keyword_true,
        keyword_false,
        keyword_null,

        pub fn lexeme(tag: Tag) ?[]const u8 {
            return switch (tag) {
                .invalid,
                .identifier,
                .string,
                .number,
                .keyword,
                .whitespace,
                .eof
                => null,

                .l_bracket => "[",
                .r_bracket => "]",
                .l_brace => "{",
                .r_brace => "}",
                .period => ".",
                .colon => ":",
                .comma => ",",
                .keyword_true => "true",
                .keyword_false => "false",
                .keyword_null => "null",
            };
        }

        pub fn symbol(tag: Tag) []const u8 {
            return tag.lexeme() orelse switch (tag) {
                .invalid => "invalid token",
                .identifier => "an identifier",
                .string => "a string",
                .number => "a number",
                .keyword => "a keyword",
                .whitespace => "a whitespace",
                else => unreachable,
            };
        }
    };
};

pub const JsonTokenizer = struct {
    buffer: [:0]const u8,
    index: usize,

    pub fn init(buffer: [:0]const u8) JsonTokenizer {
        // Skip the UTF-8 BOM if present.
        return .{
            .buffer = buffer,
            .index = if (std.mem.startsWith(u8, buffer, "\xEF\xBB\xBF")) 3 else 0,
        };
    }

    const State = enum {
        start,
        identifier,
        string,
        int,
        int_exponent,
        int_period,
        float,
        float_exponent,
        keyword,
        whitespace,
        invalid
    };

    pub fn next(self: *JsonTokenizer) JsonToken {
        var state: State = .start;
        var result: JsonToken = .{
            .tag = undefined,
            .loc = .{
                .start = self.index,
                .end = undefined,
            },
        };

        while (true) : (self.index += 1) {
            const c = self.buffer[self.index];

            switch (state) {
                .start => switch (c) {
                    0 => {
                        if (self.index == self.buffer.len) return .{
                            .tag = .eof,
                            .loc = .{
                                .start = self.index,
                                .end = self.index,
                            },
                        };
                        state = .invalid;
                    },
                    ' ', '\n', '\t', '\r' => {
                        result.tag = .whitespace;
                        self.index += 1;
                        break;
                    },
                    '"' => {
                        state = .string;
                        result.tag = .string;
                    },
                    'a'...'z', 'A'...'Z', '_' => {
                        state = .identifier;
                        result.tag = .identifier;
                    },
                    '{' => {
                        result.tag = .l_brace;
                        self.index += 1;
                        break;
                    },
                    '}' => {
                        result.tag = .r_brace;
                        self.index += 1;
                        break;
                    },
                    '[' => {
                        result.tag = .l_bracket;
                        self.index += 1;
                        break;
                    },
                    ']' => {
                        result.tag = .r_bracket;
                        self.index += 1;
                        break;
                    },
                    ',' => {
                        result.tag = .comma;
                        self.index += 1;
                        break;
                    },
                    ':' => {
                        result.tag = .colon;
                        self.index += 1;
                        break;
                    },
                    '.' => {
                        result.tag = .period;
                        self.index += 1;
                        break;
                    },
                    '0'...'9' => {
                        state = .int;
                        result.tag = .number;
                    },
                    else => {
                        state = .invalid;
                    }
                },

                .invalid => switch (c) {
                    0 => if (self.index == self.buffer.len) {
                        result.tag = .invalid;
                        break;
                    },
                    else => continue,
                },

                .identifier => switch (c) {
                    'a'...'z', 'A'...'Z', '_', '0'...'9' => continue,
                    else => {
                        if (JsonToken.getKeyword(self.buffer[result.loc.start..self.index])) |tag| {
                            result.tag = tag;
                        }
                        break;
                    },
                },

                .string => switch (c) {
                    0 => {
                        if (self.index != self.buffer.len) {
                            state = .invalid;
                            continue;
                        }
                        result.tag = .invalid;
                        break;
                    },
                    '\n' => {
                        result.tag = .invalid;
                        break;
                    },
                    '"' => {
                        self.index += 1;
                        break;
                    },
                    0x01...0x09, 0x0b...0x1f, 0x7f => {
                        state = .invalid;
                    },
                    else => continue,
                },

                .int => switch (c) {
                    '.' => state = .int_period,
                    '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => continue,
                    'e', 'E', 'p', 'P' => state = .int_exponent,
                    else => break,
                },
                .int_exponent => switch (c) {
                    '-', '+' => {
                        state = .float;
                    },
                    else => {
                        self.index -= 1;
                        state = .int;
                    },
                },
                .int_period => switch (c) {
                    '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => {
                        state = .float;
                    },
                    'e', 'E', 'p', 'P' => state = .float_exponent,
                    else => {
                        self.index -= 1;
                        break;
                    },
                },
                .float => switch (c) {
                    '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => continue,
                    'e', 'E', 'p', 'P' => state = .float_exponent,
                    else => break,
                },
                .float_exponent => switch (c) {
                    '-', '+' => state = .float,
                    else => {
                        self.index -= 1;
                        state = .float;
                    },
                },

                else => {

                }
            }
        }

        result.loc.end = self.index;
        return result;
    }
};

fn testTokenize(source: [:0]const u8, expected_token_tags: []const JsonToken.Tag) !void {
    var tokenizer = JsonTokenizer.init(source);
    for (expected_token_tags) |expected_token_tag| {
        const token = tokenizer.next();
        try std.testing.expectEqual(expected_token_tag, token.tag);
    }
    // Last token should always be eof, even when the last token was invalid,
    // in which case the tokenizer is in an invalid state, which can only be
    // recovered by opinionated means outside the scope of this implementation.
    const last_token = tokenizer.next();
    try std.testing.expectEqual(JsonToken.Tag.eof, last_token.tag);
    try std.testing.expectEqual(source.len, last_token.loc.start);
    try std.testing.expectEqual(source.len, last_token.loc.end);
}

test "simple json" {
    const json_string = "{\"name\":\"John\"}";
    try testTokenize(
        json_string, 
        &.{
            .l_brace,
            .string,
            .colon,
            .string,
            .r_brace
        });
}

test "whitespace json" {
    const json_string_whitespace = "{ \"name\": \"John\" }";
    try testTokenize(
        json_string_whitespace, 
        &.{
            .l_brace,
            .whitespace,
            .string,
            .colon,
            .whitespace,
            .string,
            .whitespace,
            .r_brace
        });

    const json_string_tab = "{\t\"name\":\t\"John\"\t}";
    try testTokenize(
        json_string_tab, 
        &.{
            .l_brace,
            .whitespace,
            .string,
            .colon,
            .whitespace,
            .string,
            .whitespace,
            .r_brace
        });

    const json_string_newline = "{\n\"name\":\n\"John\"\n}";
    try testTokenize(
        json_string_newline, 
        &.{
            .l_brace,
            .whitespace,
            .string,
            .colon,
            .whitespace,
            .string,
            .whitespace,
            .r_brace
        });
}

test "bool json" {
    const json_string_true = "{\"is_active\": true}";
    try testTokenize(
        json_string_true, 
        &.{
            .l_brace,
            .string,
            .colon,
            .whitespace,
            .keyword_true,
            .r_brace
        });

    const json_string_false = "{\"is_a_good_liar\": false}";
    try testTokenize(
        json_string_false, 
        &.{
            .l_brace,
            .string,
            .colon,
            .whitespace,
            .keyword_false,
            .r_brace
        });
}

test "int json" {
    const json_string_false = "{\"int_number\": 43}";
    try testTokenize(
        json_string_false, 
        &.{
            .l_brace,
            .string,
            .colon,
            .whitespace,
            .number,
            .r_brace
        });
}

test "float json" {
    const json_string_false = "{\"float_number\": 43.29}";
    try testTokenize(
        json_string_false, 
        &.{
            .l_brace,
            .string,
            .colon,
            .whitespace,
            .number,
            .r_brace
        });
}