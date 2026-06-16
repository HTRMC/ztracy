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

        switch (target.result.os.tag) {
            .windows => {
                mod.linkSystemLibrary("ws2_32", .{});
                mod.linkSystemLibrary("dbghelp", .{});
            },
            // dl covers dladdr; pthread/libc come in via libc++.
            // Add libunwind here only if you turn on TRACY_CALLSTACK.
            .linux => mod.linkSystemLibrary("dl", .{}),
            else => {},
        }
    }

    const example = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("example/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "ztracy", .module = mod }},
        }),
    });
    const run_example = b.addRunArtifact(example);
    if (b.args) |args| run_example.addArgs(args);
    b.step("run-example", "Build and run the example").dependOn(&run_example.step);

    const mod_tests = b.addTest(.{ .root_module = mod });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
