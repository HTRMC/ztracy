//! ztracy - Zig bindings for the Tracy profiler C API.
//!
//! Everything compiles to a no-op unless the build is run with `-Dtracy`.
//! Source locations are stamped per call site via a comptime-instantiated
//! static, so the pointer Tracy stores outlives the zone (required by the API).
const std = @import("std");

/// True when the Tracy client is linked in (build run with `-Dtracy`).
pub const enabled = @import("ztracy_options").enable;

const c = if (enabled) @cImport({
    @cDefine("TRACY_ENABLE", "1");
    @cInclude("tracy/TracyC.h");
}) else struct {};

/// A running profiling zone. Call `end()` to close it (use `defer`).
pub const Zone = struct {
    ctx: Ctx,

    const Ctx = if (enabled) c.TracyCZoneCtx else void;

    pub inline fn end(self: Zone) void {
        if (enabled) c.___tracy_emit_zone_end(self.ctx);
    }

    /// Attach dynamic text to this zone instance.
    pub inline fn text(self: Zone, txt: []const u8) void {
        if (enabled) c.___tracy_emit_zone_text(self.ctx, txt.ptr, txt.len);
    }

    /// Override this zone's name at runtime.
    pub inline fn name(self: Zone, txt: []const u8) void {
        if (enabled) c.___tracy_emit_zone_name(self.ctx, txt.ptr, txt.len);
    }

    /// Set the zone color (0xRRGGBB).
    pub inline fn color(self: Zone, rgb: u32) void {
        if (enabled) c.___tracy_emit_zone_color(self.ctx, rgb);
    }

    /// Attach a numeric value to this zone.
    pub inline fn value(self: Zone, val: u64) void {
        if (enabled) c.___tracy_emit_zone_value(self.ctx, val);
    }
};

/// Begin a zone named after the enclosing function. Pass `@src()`.
pub inline fn zone(comptime src: std.builtin.SourceLocation) Zone {
    return zoneNamed(src, null);
}

/// Begin a zone with an explicit static name. Pass `@src()`.
pub inline fn zoneNamed(comptime src: std.builtin.SourceLocation, comptime opt_name: ?[:0]const u8) Zone {
    if (comptime enabled) {
        // One static srcloc per call site (src + opt_name are comptime).
        const Static = struct {
            var loc: c.___tracy_source_location_data = .{
                .name = if (opt_name) |n| n.ptr else null,
                .function = src.fn_name.ptr,
                .file = src.file.ptr,
                .line = src.line,
                .color = 0,
            };
        };
        return .{ .ctx = c.___tracy_emit_zone_begin(&Static.loc, 1) };
    } else {
        return .{ .ctx = {} };
    }
}

/// Mark the end of a frame on the default (unnamed) frame set.
pub inline fn frameMark() void {
    if (enabled) c.___tracy_emit_frame_mark(null);
}

/// Mark the end of a frame on a named frame set.
pub inline fn frameMarkNamed(comptime fname: [:0]const u8) void {
    if (enabled) c.___tracy_emit_frame_mark(fname.ptr);
}

/// Plot a value on a named graph.
pub inline fn plot(comptime pname: [:0]const u8, val: f64) void {
    if (enabled) c.___tracy_emit_plot(pname.ptr, val);
}

/// Emit a log message to the profiler.
pub inline fn message(txt: []const u8) void {
    if (enabled) c.___tracy_emit_message(txt.ptr, txt.len, 0);
}

/// Name the current thread in the profiler.
pub inline fn setThreadName(comptime tname: [:0]const u8) void {
    if (enabled) c.___tracy_set_thread_name(tname.ptr);
}

/// Record a memory allocation.
pub inline fn alloc(ptr: ?*const anyopaque, size: usize) void {
    if (enabled) c.___tracy_emit_memory_alloc(ptr, size, 0);
}

/// Record a memory free.
pub inline fn free(ptr: ?*const anyopaque) void {
    if (enabled) c.___tracy_emit_memory_free(ptr, 0);
}

test {
    std.testing.refAllDecls(@This());
}

test "no-op path is callable when disabled" {
    // With the default build (no -Dtracy) these are all no-ops but must compile.
    const z = zone(@src());
    z.text("hi");
    z.value(7);
    z.end();
    frameMark();
    plot("fps", 60.0);
    message("hello");
}
