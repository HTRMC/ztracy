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

        // One shared Tracy client so multiple linking artifacts (e.g. an exe
        // plus a hot-reload dll) share a single profiling instance. Baking
        // TracyClient.cpp into the module gives each artifact its own client
        // and only one binds the listen socket.
        const client = b.addLibrary(.{
            .name = "tracy",
            .linkage = .dynamic,
            .root_module = b.createModule(.{ .target = target, .optimize = optimize }),
        });
        client.root_module.addIncludePath(tracy.path("public"));
        client.root_module.addCSourceFile(.{
            .file = tracy.path("public/TracyClient.cpp"),
            // -fno-sanitize=undefined: don't UBSan vendored Tracy. Its bundled
            // libbacktrace casts a ULEB128 straight into `enum dwarf_tag`
            // (dwarf.cpp), which traps under Zig's default UBSan when parsing
            // DWARF 5 emitted by Zig 0.16. Bounds-checked reads make it benign;
            // the trap is the only failure. Upstream ships it un-sanitized.
            .flags = &.{ "-DTRACY_ENABLE", "-DTRACY_EXPORTS", "-fno-sanitize=undefined" },
        });
        client.root_module.link_libcpp = true;

        switch (target.result.os.tag) {
            .windows => {
                client.root_module.linkSystemLibrary("ws2_32", .{});
                client.root_module.linkSystemLibrary("dbghelp", .{});
            },
            // dl covers dladdr; pthread/libc come in via libc++.
            // Add libunwind here only if you turn on TRACY_CALLSTACK.
            .linux => client.root_module.linkSystemLibrary("dl", .{}),
            else => {},
        }
        b.installArtifact(client);

        mod.addIncludePath(tracy.path("public"));
        mod.linkLibrary(client);
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
