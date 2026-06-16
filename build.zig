const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const enable = b.option(bool, "tracy", "Link the Tracy client and enable profiling") orelse false;

    const opts = b.addOptions();
    opts.addOption(bool, "enable", enable);

    const mod = b.addModule("ztracy", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.addOptions("ztracy_options", opts);

    if (enable) {
        const tracy = b.dependency("tracy", .{});
        mod.addIncludePath(tracy.path("public"));
        mod.addCSourceFile(.{
            .file = tracy.path("public/TracyClient.cpp"),
            .flags = &.{"-DTRACY_ENABLE"},
        });
        mod.link_libcpp = true;

        // Tracy's client opens a socket and reads symbols; pull in the
        // platform libs it needs.
        if (target.result.os.tag == .windows) {
            mod.linkSystemLibrary("ws2_32", .{});
            mod.linkSystemLibrary("dbghelp", .{});
        }
    }

    const mod_tests = b.addTest(.{ .root_module = mod });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
