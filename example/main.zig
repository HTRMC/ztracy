const std = @import("std");
const tracy = @import("ztracy");

fn work(n: u64) u64 {
    const z = tracy.zoneNamed(@src(), "work");
    defer z.end();

    var sum: u64 = 0;
    var i: u64 = 0;
    while (i < n) : (i += 1) sum +%= i;
    z.value(sum);
    return sum;
}

pub fn main() void {
    tracy.setThreadName("main");
    std.debug.print("ztracy example (profiling {s})\n", .{if (tracy.enabled) "ON" else "OFF"});

    var frame: u64 = 0;
    while (frame < 100) : (frame += 1) {
        const z = tracy.zone(@src());
        defer z.end();

        _ = work(100_000);
        tracy.plot("frame", @floatFromInt(frame));
        tracy.frameMark();
    }
    tracy.message("done");
}
