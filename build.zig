const std = @import("std");
const deps = @import("./deps.zig");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});

    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("zig-licenses", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    //

    const exe2 = b.addExecutable("generate", "generate.zig");
    exe2.setTarget(target);
    exe2.setBuildMode(mode);
    deps.addAllTo(exe2);
    exe2.install();

    const run_cmd2 = exe2.run();
    run_cmd2.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd2.addArgs(args);
    }

    const run_step2 = b.step("gen", "generate the list");
    run_step2.dependOn(&run_cmd2.step);
}
