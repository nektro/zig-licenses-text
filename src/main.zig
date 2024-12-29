const std = @import("std");
const licenses = @import("./lib.zig");

pub fn main() !void {
    for (licenses.spdx) |item| {
        std.log.info("{s}", .{item[0]});
    }

    std.debug.print("\n{?s}\n", .{licenses.find("MIT")});
}
