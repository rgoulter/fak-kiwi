const std = @import("std");
const kirei = @import("kirei");
const common = @import("common");

const microzig = @import("microzig");
const rp2040 = microzig.hal;
const time = rp2040.time;

const usb = @import("usb.zig");
const scheduler = @import("scheduler.zig");
const Gpio = @import("gpio.zig").Gpio;

const UmmAllocator = @import("umm").UmmAllocator(.{});

var engine: kirei.Engine = undefined;

var umm: UmmAllocator = undefined;
var umm_heap = std.mem.zeroes([16 * 1024]u8);

var drivers = [_]common.Driver(Gpio){
    .{ .matrix = .{
        .config = &.{
            // PyKey40 Lite
            .cols = &.{ Gpio.pin(.P0), Gpio.pin(.P1), Gpio.pin(.P2), Gpio.pin(.P3), Gpio.pin(.P4), Gpio.pin(.P5), Gpio.pin(.P6), Gpio.pin(.P7), Gpio.pin(.P8), Gpio.pin(.P9), Gpio.pin(.P10), Gpio.pin(.P11) },
            .rows = &.{ Gpio.pin(.P14), Gpio.pin(.P15), Gpio.pin(.P16), Gpio.pin(.P17) },
        },
    } },
};

var kscan = common.Kscan(Gpio){
    .drivers = &drivers,
    .engine = &engine,
};

pub fn init() void {
    umm = UmmAllocator.init(&umm_heap) catch {
        std.log.err("umm alloc init failed", .{});
        return;
    };

    kscan.setup();

    engine = kirei.Engine.init(
        .{
            .allocator = umm.allocator(),
            .onReportPush = onReportPush,
            .getTimeMillis = getKireiTimeMillis,
            .scheduleCall = scheduler.enqueue,
            .cancelCall = scheduler.cancel,
        },
        {},
    ) catch |e| {
        std.log.err("engine init failed: {any}", .{e});
        return;
    };
}

pub fn scan() void {
    kscan.process();
}

pub fn process() void {
    scheduler.process();
    engine.process();
}

fn onReportPush(report: *const [8]u8) bool {
    usb.sendReport(report) catch return false;
    return true;
}

pub fn callScheduled(token: kirei.ScheduleToken) void {
    engine.callScheduled(token);
}

fn getKireiTimeMillis() kirei.TimeMillis {
    const time_ms = time.get_time_since_boot().to_us() / 1000;
    return @intCast(time_ms % (std.math.maxInt(kirei.TimeMillis) + 1));
}
