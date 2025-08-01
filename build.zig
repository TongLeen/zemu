const std = @import("std");

pub fn build(b: *std.Build) void {
    buildExe(b);
    // test_mod_monitor(b);
}

fn buildExe(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_mod = b.addModule("core", .{
        .root_source_file = b.path("src/core/root.zig"),
    });
    const io_mod = b.addModule("io", .{
        .root_source_file = b.path("src/io/root.zig"),
    });
    const monitor_mod = b.addModule("monitor", .{
        .root_source_file = b.path("src/monitor/root.zig"),
    });
    const misc_mod = b.addModule("misc", .{
        .root_source_file = b.path("src/misc/root.zig"),
    });

    const exe_mod = b.addModule(
        "zemu",
        .{
            .root_source_file = b.path("src/init.zig"),
            .target = target,
            .optimize = optimize,
        },
    );
    io_mod.addImport("core", core_mod);
    monitor_mod.addImport("core", core_mod);
    monitor_mod.addImport("misc", misc_mod);
    core_mod.addImport("core", core_mod);
    core_mod.addImport("misc", misc_mod);

    exe_mod.addImport("io", io_mod);
    exe_mod.addImport("core", core_mod);
    exe_mod.addImport("monitor", monitor_mod);

    const exe = b.addExecutable(.{
        .name = "zemu",
        .root_module = exe_mod,
    });

    exe.linkLibC();
    exe.linkSystemLibrary("readline");

    b.installArtifact(exe);

    const cmd_run = b.addRunArtifact(exe);
    cmd_run.addArg("main.bin");
    cmd_run.step.dependOn(&exe.step);

    const step_run = b.step("run", "Run the execuatble.");
    step_run.dependOn(&cmd_run.step);
}

fn test_mod_monitor(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_mod = b.addModule("test_mod", .{
        .root_source_file = b.path("src/monitor/Monitor.zig"),
        .optimize = optimize,
        .target = target,
    });

    const core_mod = b.addModule("core", .{
        .root_source_file = b.path("src/core/root.zig"),
    });
    const io_mod = b.addModule("io", .{
        .root_source_file = b.path("src/io/root.zig"),
    });
    test_mod.addImport("core", core_mod);
    test_mod.addImport("io", io_mod);
    core_mod.addImport("io", io_mod);

    const tests = b.addTest(.{
        .root_module = test_mod,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run test units.");
    test_step.dependOn(&run_tests.step);
}

// fn testWatchPoint(b: *std.Build) void {
//     const target = b.standardTargetOptions(.{});
//     const optimize = b.standardOptimizeOption(.{});

//     const test_mod = b.addModule("test_mod", .{
//         .root_source_file = b.path("./src/monitor/WatchPoint.zig"),
//         .optimize = optimize,
//         .target = target,
//     });

//     const core_mod = b.addModule("core", .{
//         .root_source_file = b.path("src/core/core.zig"),
//     });
//     const io_mod = b.addModule("io", .{
//         .root_source_file = b.path("src/io/io.zig"),
//     });
//     test_mod.addImport("core", core_mod);
//     test_mod.addImport("io", io_mod);
//     core_mod.addImport("io", io_mod);

//     const tests = b.addTest(.{
//         .root_module = test_mod,
//     });

//     const run_tests = b.addRunArtifact(tests);
//     const test_step = b.step("test", "Run test units.");
//     test_step.dependOn(&run_tests.step);
// }
