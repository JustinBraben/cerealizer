const std = @import("std");

pub const JsonToken = struct {
    tag: Tag,
    loc: Loc,

    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    pub const Tag = enum {
        invalid,
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

        pub fn lexeme(tag: Tag) ?[]const u8 {
            return switch (tag) {
                .invalid,
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
            };
        }

        pub fn symbol(tag: Tag) []const u8 {
            return tag.lexeme() orelse switch (tag) {
                .invalid => "invalid token",
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