const std = @import("std");
const net = std.net;
const posix = std.posix;
const rl = @import("raylib");

pub fn mapRangeTrigger(x: f32) u8 {
    const scaled = (x + 1) / 2 * 255.0;

    return @intFromFloat(scaled);
}

const MotorsSpeeds = struct {
    left: u8,
    right: u8,
};

pub fn getMotorSpeed(trigger: f32, stick_x: f32) MotorsSpeeds {

    const forward = (trigger + 1.0) / 2.0;
    const turn = stick_x * forward;
    var left = forward + turn;
    var right = forward - turn;

    left  = std.math.clamp(left,  0.0, 1.0);
    right = std.math.clamp(right, 0.0, 1.0);

    const left_u8: u8  = @intFromFloat(left * 255.0);
    const right_u8: u8 = @intFromFloat(right * 255.0);

    return .{
        .left = left_u8,
        .right = right_u8,
    };
}

pub fn main() !void {
    const address = try net.Address.parseIp("192.168.10.221", 8080);

    const tpe: u32 = posix.SOCK.STREAM | posix.SOCK.NONBLOCK;
    const protocol = posix.IPPROTO.TCP;
    const listener = try posix.socket(address.any.family, tpe, protocol);
    defer posix.close(listener);

    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(listener, &address.any, address.getOsSockLen());
    try posix.listen(listener, 128);

    var connected_client: ?net.Address = null;
    var connecting: bool = false;
    var stream: std.net.Stream = undefined;
    _ = undefined;
    var socket: posix.socket_t = undefined;

    var client_address: net.Address = undefined;
    var client_address_len: posix.socklen_t = @sizeOf(net.Address);
    var ip_buf: [21]u8 = undefined;

    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "robot driver");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {

        if (rl.isKeyPressed(rl.KeyboardKey.key_c)) {
            if (!connecting and connected_client == null) {
                connecting = true;

                std.debug.print("Start accepting\n", .{});

                socket = posix.accept(listener, &client_address.any, &client_address_len, 0 | posix.SOCK.NONBLOCK) catch |err| {
                    std.debug.print("error accept: {}\n", .{err});
                    connecting = false;
                    continue;
                };

                connected_client = client_address;

                std.debug.print("{} connected\n", .{client_address});
                stream = net.Stream{.handle = socket};
                connecting = false;
            }
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_s)) {
            if (!connecting and !(connected_client == null)) {
                connected_client = null;
                posix.close(socket);
            }
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        if (rl.isGamepadAvailable(0)) {

            var left_stick_x = rl.getGamepadAxisMovement(0, @intFromEnum(rl.GamepadAxis.gamepad_axis_left_x));
            if (left_stick_x > -0.2 and left_stick_x < 0.2) left_stick_x = 0;

            const right_trigger = rl.getGamepadAxisMovement(0, @intFromEnum(rl.GamepadAxis.gamepad_axis_right_trigger));
            const left_trigger = rl.getGamepadAxisMovement(0, @intFromEnum(rl.GamepadAxis.gamepad_axis_left_trigger));


            const rt_value = mapRangeTrigger(right_trigger);
            const lt_value = mapRangeTrigger(left_trigger);

            rl.drawText("Axis Values:", 10, 60, 20, rl.Color.black);

            rl.drawText(rl.textFormat("LEFT STICK X: %.02f", .{ left_stick_x}), 10, 80, 20, rl.Color.black);
            rl.drawText(rl.textFormat("R TRIGGER: %.02f", .{ right_trigger}), 10, 100, 20, rl.Color.black);
            rl.drawText(rl.textFormat("L TRIGGER: %.02f", .{ left_trigger}), 10, 120, 20, rl.Color.black);


            if (rl.isGamepadButtonDown(0, rl.GamepadButton.gamepad_button_right_trigger_2)) {
                rl.drawRectangle(40, 40, 20, 30, rl.Color.red);
            }

            if (connected_client != null) {

                var r_buf: [64]u8 = undefined;
                _ = try stream.read(&r_buf);
                //if (stream.read(&r_buf)) |len| {
                //    std.debug.print("READING {}\n", .{len});
                //} else |err| switch (err) {
                //    error.WouldBlock => {
                //        std.debug.print("WOULD BLOCK\n", .{});
                //    },
                //    else => {
                //        std.debug.print("Error receiving: {}\n", .{err});
                //    },
                //}

                //const r = try reader.readUntilDelimiterOrEof(&read_buf, '\n');
                //std.debug.print("{x}\n", .{r.?});
                //const read_len = try stream.read(&read_buf);
                //if (read_len != 0) {
                //    var b = read_buf[0..read_len];
                //
                //    std.debug.print("READING \n", .{});
//
                //    while (b.len != 0) {
                //        const left = std.mem.readInt(i32, b[0..4], .little);
                //        b = b[4..];
                //        const right = std.mem.readInt(i32, b[0..4], .little);
                //        b = b[4..];
                //        if (b[0] != '\n') {
                //            break;
                //        }
//
                //        rl.drawText(rl.textFormat("LEFT: %i", .{ left }), 10, 200, 20, rl.Color.black);
                //        rl.drawText(rl.textFormat("RIGHT: %i", .{ right }), 10, 220, 20, rl.Color.black);
//
                //        b = b[1..];
                //    }
//
                //}

                var send_buf: [128]u8 = undefined;
                var send_stream = std.io.fixedBufferStream(&send_buf);
                var writer = send_stream.writer();

                if (lt_value != 0) {
                    const speeds = getMotorSpeed(left_trigger, left_stick_x);

                    try writer.writeInt(u8, speeds.left, .little);
                    try writer.writeByte(' ');
                    try writer.writeInt(u8, speeds.right, .little);
                    try writer.writeByte(' ');
                    try writer.writeByte(1);
                    try writer.writeByte('\n');
                } else if (rt_value != 0) {
                    const speeds = getMotorSpeed(right_trigger, left_stick_x);

                    try writer.writeInt(u8, speeds.left, .little);
                    try writer.writeByte(' ');
                    try writer.writeInt(u8, speeds.right, .little);
                    try writer.writeByte(' ');
                    try writer.writeByte(0);
                    try writer.writeByte('\n');
                } else {
                    try writer.writeInt(u8, 0, .little);
                    try writer.writeByte(' ');
                    try writer.writeInt(u8, 0, .little);
                    try writer.writeByte(' ');
                    try writer.writeByte(0);
                    try writer.writeByte('\n');
                }

                _ = try stream.write(send_buf[0..6]);
            }
        }

        rl.drawText("C - Start server", 10, 10, 20, rl.Color.dark_gray);
        rl.drawText("S - Stop server", 10, 30, 20, rl.Color.dark_gray);

        rl.drawText("Status:", rl.getScreenWidth() - 230, 10, 20, rl.Color.black);
        if (connected_client == null) {
            rl.drawText("Disconnected", rl.getScreenWidth() - 145, 10, 20, rl.Color.red);
        } else {
            rl.drawText("Connected", rl.getScreenWidth() - 155, 10, 20, rl.Color.green);
            rl.drawText("Client:", rl.getScreenWidth() - 260, 30, 20, rl.Color.black);
            const b = try std.fmt.bufPrint(&ip_buf, "{}", .{connected_client.?});
            ip_buf[b.len] = 0;
            rl.drawText(rl.textFormat("%s", .{&ip_buf}), rl.getScreenWidth() - 190, 30, 20, rl.Color.green);
        }

    }

    if (connected_client != null) {
        posix.close(socket);
    }
}

