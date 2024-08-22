const std = @import("std");

pub fn JsonOutput(comptime T: type) type {
    return struct {
        output_json_stream_wrapper: T,
    };
}
