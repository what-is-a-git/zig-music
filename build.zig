const std = @import("std");

pub fn build(b: *std.Build) void {
    // Currently not specically configured
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main executable
    const exe = b.addExecutable(.{
        .name = "zig-music",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // static libraries
    const dr_libs = b.addStaticLibrary(.{ .name = "dr_libs", .target = target, .optimize = optimize });
    dr_libs.linkLibC();
    dr_libs.addIncludePath(b.path("vendor/include/dr_libs/"));
    dr_libs.addCSourceFiles(.{ .root = b.path("vendor/src/dr_libs/"), .files = &.{
        "dr_flac.c",
        "dr_mp3.c",
        "dr_wav.c",
    } });

    const stb = b.addStaticLibrary(.{ .name = "stb", .target = target, .optimize = optimize });
    stb.linkLibC();
    stb.addIncludePath(b.path("vendor/include/stb/"));
    stb.addCSourceFile(.{ .file = b.path("vendor/src/stb/stb_vorbis.c") });

    // linking
    exe.linkLibC();
    exe.linkLibrary(dr_libs);
    exe.linkLibrary(stb);

    // dlls n stuff
    exe.addLibraryPath(b.path("vendor/lib"));
    if (target.result.os.tag == .windows) {
        exe.linkSystemLibrary("al-soft/OpenAL32");
        b.installFile("vendor/lib/al-soft/OpenAL32.dll", "bin/OpenAL32.dll");
    } else {
        exe.linkSystemLibrary("openal");
    }

    // includes
    exe.addIncludePath(b.path("vendor/include"));

    // finalize
    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Unit testing, not currently in use.
    // const exe_unit_tests = b.addTest(.{
    //     .root_source_file = b.path("src/main.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_exe_unit_tests.step);
}
