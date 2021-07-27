const std = @import("std");
const licenses = @import("./lib.zig");

pub fn main() !void {
    inline for (std.meta.declarations(licenses.spdx)) |item| {
        std.log.info("{s}", .{item.name});
    }

    std.debug.print("\n{s}\n", .{licenses.spdx.@"MIT"});
}
