const std = @import("std");
const c = @import("../lib.zig");
const config = @import("../config.zig");
const UUID = @import("uuid").UUID;
const tmos = @import("tmos.zig");
const debug = @import("../debug.zig");

const systick = @import("../hal/systick.zig");
const rtc = @import("../hal/rtc.zig");
const pmu = @import("../hal/pmu.zig");
const interrupts = @import("../hal/interrupts.zig");
const eeprom = @import("../hal/eeprom.zig");

const n = @import("assigned_numbers.zig");

var memBuf align(4) = std.mem.zeroes([config.ble.mem_heap_size]u8);

var ble_config: c.bleConfig_t = blk: {
    var cfg = std.mem.zeroes(c.bleConfig_t);

    cfg.MEMLen = config.ble.mem_heap_size;
    cfg.BufMaxLen = config.ble.buf_max_len;
    cfg.BufNumber = config.ble.buf_number;
    cfg.TxNumEvent = config.ble.tx_num_event;
    cfg.TxPower = @intFromEnum(config.ble.tx_power);

    cfg.SNVAddr = 0x8000 - 512; // Last 512 bytes of EEPROM
    cfg.readFlashCB = libReadFlash;
    cfg.writeFlashCB = libWriteFlash;

    cfg.SelRTCClock = 1; // 32KHz LSI

    cfg.ConnectNumber =
        (config.ble.peripheral_max_connections & 3) | (config.ble.central_max_connections << 2);

    cfg.srandCB = getSysTickCount;
    cfg.rcCB = c.Lib_Calibration_LSI;
    cfg.MacAddr = config.ble.mac_addr;

    cfg.idleCB = enterSleep;

    break :blk cfg;
};

const WAKE_UP_RTC_MAX_TIME = 16; // 0.5ms in 32KHz RTC cycles

// Are these sleep min, max values just by choice or is it the chip's limitations?
const SLEEP_RTC_MIN_TIME = 8; // 0.25ms
const SLEEP_RTC_MAX_TIME = 2715440914; // RTC max 32K cycle (idk how long this is yet) minus 1hr

pub const TxPower = enum(u8) {

    dbm_n20 = c.LL_TX_POWEER_MINUS_20_DBM, // Negative
    dbm_n15 = c.LL_TX_POWEER_MINUS_15_DBM,
    dbm_n10 = c.LL_TX_POWEER_MINUS_10_DBM,
    dbm_n8 = c.LL_TX_POWEER_MINUS_8_DBM,
    dbm_n5 = c.LL_TX_POWEER_MINUS_5_DBM,
    dbm_n3 = c.LL_TX_POWEER_MINUS_3_DBM,
    dbm_n1 = c.LL_TX_POWEER_MINUS_1_DBM,
    dbm_0 = c.LL_TX_POWEER_0_DBM, // Zero
    dbm_1 = c.LL_TX_POWEER_1_DBM, // Positive
    dbm_2 = c.LL_TX_POWEER_2_DBM,
    dbm_3 = c.LL_TX_POWEER_3_DBM,
    dbm_4 = c.LL_TX_POWEER_4_DBM,

    pub fn value(comptime self: @This()) i8 {
        return switch (self) {
            .dbm_n20 => -20,
            .dbm_n15 => -15,
            .dbm_n10 => -10,
            .dbm_n8 => -8,
            .dbm_n5 => -5,
            .dbm_n3 => -3,
            .dbm_n1 => -1,
            .dbm_0 => 0,
            .dbm_1 => 1,
            .dbm_2 => 2,
            .dbm_3 => 3,
            .dbm_4 => 4,
        };
    }
};

pub fn init() !void {
    try initBleModule();
    rtc.init();
    try tmos.init();

    pmu.setWakeUpEvent(.rtc, true);
    rtc.setTriggerMode(true);
    interrupts.set(.rtc, true);
}

pub fn process() void {
    c.TMOS_SystemProcess();
}

fn initBleModule() !void {
    ble_config.MEMAddr = @intFromPtr(&memBuf);

    const result = c.BLE_LibInit(&ble_config);

    return switch (result) {
        c.SUCCESS => {},
        c.ERR_LLE_IRQ_HANDLE => error.LleIrqHandle,
        c.ERR_MEM_ALLOCATE_SIZE => error.MemAllocateSize,
        c.ERR_SET_MAC_ADDR => error.SetMacAddr,
        c.ERR_GAP_ROLE_CONFIG => error.GapRoleConfig,
        c.ERR_CONNECT_NUMBER_CONFIG => error.ConnectNumberConfig,
        c.ERR_SNV_ADDR_CONFIG => error.SnvAddrConfig,
        c.ERR_CLOCK_SELECT_CONFIG => error.ClockSelectConfig,
        else => unreachable,
    };
}

fn libReadFlash(addr: u32, num: u32, pBuf: [*c]u32) callconv(.C) u32 {
    var buf: [*c]u8 = @ptrCast(pBuf);
    eeprom.read(@intCast(addr), buf[0 .. num * 4]) catch return 1;
    return 0;
}

fn libWriteFlash(addr: u32, num: u32, pBuf: [*c]u32) callconv(.C) u32 {
    const buf: [*c]u8 = @ptrCast(pBuf);
    eeprom.write(@intCast(addr), buf[0 .. num * 4]) catch return 1;
    return 0;
}

fn getSysTickCount() callconv(.C) u32 {
    return @truncate(systick.count());
}

fn enterSleep(time: u32) callconv(.C) u32 {
    {
        interrupts.globalSet(false);
        defer interrupts.globalSet(true);

        const time_curr = rtc.getTime();
        const sleep_dur = if (time < time_curr)
            time + (rtc.MAX_CYCLE_32K - time_curr)
        else
            time - time_curr;

        if (sleep_dur < SLEEP_RTC_MIN_TIME or sleep_dur > SLEEP_RTC_MAX_TIME) {
            return 2; // No documentation on what 2 means.
        }

        rtc.setTriggerTime(time);
    }

    // There's a possibility that, right here, RTC interrupt may have just been triggered.
    // In that case, there's no more need to sleep. We return early to prevent sleeping.
    if (rtc.isTriggerTimeActivated()) {
        return 3; // No documentation on what 3 means.
    }

    pmu.sleepDeep(.{
        .ram_2k = true,
        .ram_30k = true,
        .extend = true,
    });

    if (rtc.isTriggerTimeActivated()) {
        // We're woken up by the RTC trigger - it's time to prepare for the connection interval.
        // When coming from deep sleep, HSE has just powered on and needs 0.5ms (typ) to stabilize.
        // We need HSE to stabilize since BLE transmission is time-critical.
        // Fortunately, we configured the BLE stack to give us that much time to get ready.
        // So here, we sleep light (HSE awake) for 0.5ms, so when we wake up, it's show time!
        rtc.setTriggerTime(time +% WAKE_UP_RTC_MAX_TIME);
        pmu.sleepIdle();
    }

    // TODO: Something about HSE current for stability? Not sure.
    // HSECFG_Current(HSE_RCur_100);

    config.sys.led_1.toggle();
    return 0;
}

pub fn initPeripheralRole() !void {
    const err = c.GAPRole_PeripheralInit();
    if (err != c.SUCCESS) {
        return error.Failure;
    }
}

pub const GattUuid = extern struct {
    len: u8,
    uuid: [*]const u8,

    const Self = @This();

    pub fn init(comptime uuid: anytype) Self {
        return switch (@TypeOf(uuid)) {
            u16 => .{
                .len = @sizeOf(u16),
                .uuid = &std.mem.toBytes(uuid),
            },
            else => switch (uuid.len) {
                4 => .{
                    .len = @sizeOf(u16),
                    .uuid = &std.mem.toBytes(std.fmt.parseUnsigned(u16, uuid, 16) catch unreachable),
                },
                else => .{
                    .len = @sizeOf(u128),
                    .uuid = &(UUID.parse(uuid) catch unreachable).bytes,
                },
            },
        };
    }
};

pub const GattPermissions = packed struct(u8) {
    read: bool = false,
    write: bool = false,
    authenticated_read: bool = false,
    authenticated_write: bool = false,
    authorized_read: bool = false,
    authorized_write: bool = false,
    encrypted_read: bool = false,
    encrypted_write: bool = false,

    const Self = @This();

    pub fn isReadonly(comptime self: Self) bool {
        return !self.write and !self.authenticated_write and !self.authorized_write and !self.encrypted_write;
    }
};

pub const GattProperties = packed struct(u8) {
    broadcast: bool = false,
    read: bool = false,
    write_no_rsp: bool = false,
    write: bool = false,
    notify: bool = false,
    indicate: bool = false,
    authenticate: bool = false,
    extended: bool = false,
};

pub const GattAttribute = extern struct {
    type: GattUuid,
    permissions: GattPermissions,
    handle: u16 = 0,
    value: *anyopaque,

    const Self = @This();
};

pub fn gattAttrPrimaryService(comptime service_uuid: GattUuid) GattAttribute {
    return GattAttribute{
        .type = GattUuid.init(n.DECL_PRIMARY_SERVICE),
        .permissions = .{ .read = true },
        .value = @constCast(@ptrCast(&service_uuid)),
    };
}

pub fn gattAttrCharacteristicDecl(comptime properties: GattProperties) GattAttribute {
    return GattAttribute{
        .type = GattUuid.init(n.DECL_CHARACTERISTIC),
        .permissions = .{ .read = true },
        .value = @constCast(&@as(u8, @bitCast(properties))),
    };
}

pub fn gattAttrClientCharCfg(comptime ccc: *ClientCharCfg, comptime permissions: GattPermissions) GattAttribute {
    return GattAttribute{
        .type = GattUuid.init(n.DESC_CLIENT_CHAR_CONFIG),
        .permissions = permissions,
        .value = ccc,
    };
}

pub fn gattAttrReportRef(comptime ref: *const HidReportReference, comptime permissions: GattPermissions) GattAttribute {
    return GattAttribute{
        .type = GattUuid.init(n.DESC_REPORT_REF),
        .permissions = permissions,
        .value = @constCast(ref),
    };
}

pub const HidReportReference = packed struct {
    report_id: u8,
    report_type: enum(u8) {
        input = 1,
        output = 2,
        feature = 3,
    },
};

pub const ClientCharCfg = struct {
    ccc: [config.ble.total_max_connections]c.gattCharCfg_t = undefined,

    pub const uuid = GattUuid.init(n.DESC_CLIENT_CHAR_CONFIG);

    const Self = @This();

    pub fn register(self: *Self, conn_handle: ?u16) void {
        c.GATTServApp_InitCharCfg(conn_handle orelse c.INVALID_CONNHANDLE, @ptrCast(&self.ccc));
    }

    pub fn write(conn_handle: u16, p_attr: [*c]c.gattAttribute_t, p_value: [*c]u8, len: u16, offset: u16) void {
        _ = c.GATTServApp_ProcessCCCWriteReq(conn_handle, p_attr, p_value, len, offset, c.GATT_CLIENT_CFG_NOTIFY);
    }

    pub fn notify(self: *Self, comptime T: type, conn_handle: u16, handle: u16, value: *T) !void {
        const char_cfg = c.GATTServApp_ReadCharCfg(conn_handle, @ptrCast(&self.ccc));
        const null_ptr = @as(*allowzero u16, @ptrFromInt(0));

        if ((char_cfg & c.GATT_CLIENT_CFG_NOTIFY) == 0)
            return;

        var noti: c.attHandleValueNoti_t = undefined;
        noti.pValue = @ptrCast(c.GATT_bm_alloc(conn_handle, c.ATT_HANDLE_VALUE_NOTI, @sizeOf(T), null_ptr, 0));

        if (@intFromPtr(noti.pValue) == 0)
            return;

        noti.handle = handle;
        noti.len = @sizeOf(T);
        c.tmos_memcpy(noti.pValue, value, noti.len);

        const result = c.GATT_Notification(conn_handle, &noti, 0);

        if (result != c.SUCCESS) {
            c.GATT_bm_free(@ptrCast(&noti), c.ATT_HANDLE_VALUE_NOTI);
        }

        return switch (result) {
            c.SUCCESS => {},
            c.INVALIDPARAMETER => error.InvalidParameter,
            c.MSG_BUFFER_NOT_AVAIL => error.MsgBufferNotAvail,
            c.bleNotConnected => error.BleNotConnected,
            c.bleMemAllocError => error.BleMemAllocError,
            c.bleTimeout => error.BleTimeout,
            else => unreachable,
        };
    }
};
