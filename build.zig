const std = @import("std");
const deps = @import("./deps.zig");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.option(std.builtin.Mode, "mode", "") orelse .Debug;

    const exe = b.addExecutable(.{
        .name = "zig-licenses",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = mode,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("test", "Run the app");
    run_step.dependOn(&run_cmd.step);

    //

    const exe2 = b.addExecutable(.{
        .name = "generate",
        .root_source_file = .{ .path = "generate.zig" },
        .target = target,
        .optimize = mode,
    });
    deps.addAllTo(exe2);
    b.installArtifact(exe2);

    const run_cmd2 = b.addRunArtifact(exe2);
    run_cmd2.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd2.addArgs(args);
    }

    const run_step2 = b.step("gen", "generate the list");
    run_step2.dependOn(&run_cmd2.step);
}
