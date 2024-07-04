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
            .cols = &.{ Gpio.pin(.P7), Gpio.pin(.P8), Gpio.pin(.P9), Gpio.pin(.P6), Gpio.pin(.P10), Gpio.pin(.P21), Gpio.pin(.P28), Gpio.pin(.P22), Gpio.pin(.P26), Gpio.pin(.P27) },
            .rows = &.{ Gpio.pin(.P11), Gpio.pin(.P12), Gpio.pin(.P13), Gpio.pin(.P5), Gpio.pin(.P20), Gpio.pin(.P19), Gpio.pin(.P18), Gpio.pin(.P29) },
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
