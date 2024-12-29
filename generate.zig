//! Run this with `zig build gen`

const std = @import("std");
const json = @import("json");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const f = try std.fs.cwd().createFile("src/lib.zig", .{});
    const w = f.writer();

    std.log.info("spdx", .{});
    const doc = try simple_fetch(alloc, "https://raw.githubusercontent.com/spdx/license-list-data/master/json/licenses.json");
    defer doc.deinit(alloc);
    const val = doc.root.object();

    try w.writeAll("// SPDX License Text data generated from https://github.com/spdx/license-list-data\n");
    try w.writeAll("//\n");
    try w.print("// Last generated from version {s}\n", .{val.getS("licenseListVersion").?});
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

    const licenses = try mutdupe(alloc, json.ValueIndex, val.getA("licenses").?);
    defer alloc.free(licenses);
    std.mem.sort(json.ValueIndex, licenses, {}, spdxlicenseLessThan);

    try w.writeAll("\n");
    try w.writeAll("pub const spdx = [_][2][]const u8{\n");
    for (licenses) |lic| {
        std.debug.print("|", .{});
        const licID = lic.object().getS("licenseId").?;

        var arena = std.heap.ArenaAllocator.init(alloc);
        defer arena.deinit();
        const aalloc = arena.allocator();

        const innerurl = try std.fmt.allocPrint(aalloc, "https://spdx.org/licenses/{s}.json", .{licID});
        const innerdoc = try simple_fetch(aalloc, innerurl);
        defer innerdoc.deinit(aalloc);
        const innerval = innerdoc.root.object();
        var fulltext = innerval.getS("licenseText") orelse "";
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

pub fn simple_fetch(alloc: std.mem.Allocator, url: []const u8) !json.Document {
    var client = std.http.Client{ .allocator = alloc };
    defer client.deinit();

    var list = std.ArrayList(u8).init(alloc);
    defer list.deinit();

    const fetch = try client.fetch(.{
        .location = .{ .url = url },
        .response_storage = .{ .dynamic = &list },
    });
    const opts = json.Parser.Options{ .maximum_depth = 100, .support_trailing_commas = true };
    if (fetch.status != .ok) return try json.parseFromSlice(alloc, url, "{}", opts);
    return try json.parseFromSlice(alloc, url, list.items, opts);
}

fn spdxlicenseLessThan(context: void, lhs: json.ValueIndex, rhs: json.ValueIndex) bool {
    _ = context;
    const l = lhs.object().getS("licenseId").?;
    const r = rhs.object().getS("licenseId").?;
    return std.mem.lessThan(u8, l, r);
}

fn mutdupe(alloc: std.mem.Allocator, comptime T: type, original: anytype) ![]T {
    const slice = try alloc.alloc(T, original.len);
    for (original, 0..) |item, i| slice[i] = item;
    return slice;
}
