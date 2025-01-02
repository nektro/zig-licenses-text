const std = @import("std");
const licenses = @import("licenses-text");
const expect = @import("expect").expect;

test {
    try expect(licenses.spdx.len).toEqual(464);
    try expect(licenses.find("MIT")).not().toBeNull();
}
