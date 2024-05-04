//! Run this with `zig build gen`

const std = @import("std");
const zfetch = @import("zfetch");
const json = @import("json");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const f = try std.fs.cwd().createFile("src/lib.zig", .{});
    const w = f.writer();

    std.log.info("spdx", .{});
    const val = try simple_fetch(alloc, "https://raw.githubusercontent.com/spdx/license-list-data/master/json/licenses.json");

    try w.writeAll("// SPDX License Text data generated from https://github.com/spdx/license-list-data\n");
    try w.writeAll("//\n");
    try w.print("// Last generated from version {s}\n", .{val.get("licenseListVersion").?.String});
    try w.writeAll("//\n");

    try w.writeAll("\n");
    try w.writeAll(
        \\const std = @import("std");
        \\
        \\pub fn find(name: []const u8) ?[]const u8 {
        \\    for (spdx) |item| {
        \\        if (std.mem.eql(u8, item[0], name)) {
        \\            return item[1];
        \\        }
        \\    }
        \\    return null;
        \\}
        \\
    );

    var licenses = val.get("licenses").?.Array;
    std.sort.sort(json.Value, licenses, {}, spdxlicenseLessThan);

    try w.writeAll("\n");
    try w.writeAll("pub const spdx = [_][2][]const u8{\n");
    for (licenses) |lic| {
        std.debug.print("|", .{});
        const licID = lic.get("licenseId").?.String;

        var arena = std.heap.ArenaAllocator.init(alloc);
        defer arena.deinit();
        const aalloc = &arena.allocator;

        const innerurl = try std.fmt.allocPrint(aalloc, "https://spdx.org/licenses/{s}.json", .{licID});
        const innerval = try simple_fetch(aalloc, innerurl);
        var fulltext = (innerval.get("licenseText") orelse json.Value{ .String = "" }).String;
        fulltext = try std.mem.replaceOwned(u8, aalloc, fulltext, "\\u0026", "&");
        fulltext = try std.mem.replaceOwned(u8, aalloc, fulltext, "\\u0027", "'");
        fulltext = try std.mem.replaceOwned(u8, aalloc, fulltext, "\\u003c", "<");
        fulltext = try std.mem.replaceOwned(u8, aalloc, fulltext, "\\u003d", "=");
        fulltext = try std.mem.replaceOwned(u8, aalloc, fulltext, "\\u003e", ">");
        fulltext = try std.mem.replaceOwned(u8, aalloc, fulltext, "\\u2028", "\\n");

        try w.print("    .{{ \"{s}\", \"{s}\" }},\n", .{ licID, fulltext });
    }
    try w.writeAll("};\n");
    std.debug.print("\n", .{});
}

pub fn simple_fetch(alloc: std.mem.Allocator, url: []const u8) !json.Value {
    const req = try zfetch.Request.init(alloc, url, null);
    defer req.deinit();
    try req.do(.GET, null, null);
    if (req.status.code != 200) return json.Value{
        .Object = &.{},
    };
    const r = req.reader();
    const body_content = try r.readAllAlloc(alloc, std.math.maxInt(usize));
    const val = try json.parse(alloc, body_content);
    return val;
}

fn spdxlicenseLessThan(context: void, lhs: json.Value, rhs: json.Value) bool {
    _ = context;
    const l = lhs.get("licenseId").?.String;
    const r = rhs.get("licenseId").?.String;
    return std.mem.lessThan(u8, l, r);
}
