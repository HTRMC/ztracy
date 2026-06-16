# ztracy

Zig bindings for the [Tracy](https://github.com/wolfpld/tracy) profiler C API.

- Pinned to Tracy **v0.13.1** (see `build.zig.zon`).
- Profiling is **off by default** — every call compiles to a no-op. Pass `-Dtracy`
  to link the Tracy client and emit data.
- No code generation: the bindings are `@cImport`ed straight from `tracy/TracyC.h`,
  so they track whatever Tracy version is vendored.

## Use as a dependency

```sh
zig fetch --save git+https://github.com/HTRMC/ztracy
```

```zig
// build.zig
const ztracy = b.dependency("ztracy", .{
    .target = target,
    .optimize = optimize,
    .tracy = true, // omit (or false) to compile profiling out
});
exe_mod.addImport("ztracy", ztracy.module("ztracy"));
```

```zig
const tracy = @import("ztracy");

pub fn frame() void {
    const z = tracy.zone(@src());
    defer z.end();

    tracy.frameMark();
}
```

## API

| Call | Purpose |
| --- | --- |
| `zone(@src())` / `zoneNamed(@src(), "name")` | open a scoped zone; `z.end()` to close |
| `z.text/name/color/value(...)` | annotate a zone instance |
| `frameMark()` / `frameMarkNamed("x")` | mark a frame boundary |
| `plot("graph", value)` | plot a value over time |
| `message("...")` | log a message |
| `setThreadName("...")` | name the current thread |
| `alloc(ptr, size)` / `free(ptr)` | track allocations |
| `enabled` | comptime bool, true when `-Dtracy` is set |

## Run the example

```sh
zig build run-example -Dtracy   # connect with the Tracy profiler GUI
zig build run-example           # no-op build, prints "profiling OFF"
```

## Updating Tracy

A GitHub Action checks for new Tracy releases weekly and opens a PR that bumps the
dependency once `zig build test` passes against it. See
`.github/workflows/tracy-update.yml`.
