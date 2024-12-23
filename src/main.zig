const std = @import("std");
const net = std.net;
const posix = std.posix;
const rl = @import("raylib");

pub fn main() !void {
    const address = try net.Address.parseIp("0.0.0.0", 8080);

    const tpe: u32 = posix.SOCK.STREAM;
    const protocol = posix.IPPROTO.TCP;
    const listener = try posix.socket(address.any.family, tpe, protocol);
    defer posix.close(listener);

    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(listener, &address.any, address.getOsSockLen());
    try posix.listen(listener, 128);

    var connected_client: ?net.Address = null;
    var connecting: bool = false;
    var stream: std.net.Stream = undefined;
    const read_buf: [256]u8 = undefined;
    var socket: posix.socket_t = undefined;

    _ = read_buf;

    var client_address: net.Address = undefined;
    var client_address_len: posix.socklen_t = @sizeOf(net.Address);

    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "robot driver");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {

        rl.pollInputEvents();

        if (rl.isKeyReleased(rl.KeyboardKey.key_c)) {
            if (!connecting and connected_client == null) {
                connecting = true;

                socket = posix.accept(listener, &client_address.any, &client_address_len, 0) catch |err| {
                    std.debug.print("error accept: {}\n", .{err});
                    continue;
                };

                connected_client = client_address;

                std.debug.print("{} connected\n", .{client_address});
                stream = net.Stream{.handle = socket};
                connecting = false;
            }
        }

        if (rl.isKeyReleased(rl.KeyboardKey.key_s)) {
            if (!connecting and !(connected_client == null)) {
                connected_client = null;
                posix.close(socket);
            }
        }

        if (rl.isGamepadAvailable(0)) {
            if (rl.isGamepadButtonDown(0, rl.GamepadButton.gamepad_button_right_trigger_2)) {
                rl.drawRectangle(0, 0, 19, 26, rl.Color.red);
            }
        }


        // Update
        //----------------------------------------------------------------------------------
        // TODO: Update your variables here
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        rl.drawText("C - Start server", 10, 10, 20, rl.Color.dark_gray);
        rl.drawText("S - Stop server", 10, 30, 20, rl.Color.dark_gray);


        rl.drawText(rl.textFormat("Detected Button: {any}", .{@intFromEnum(rl.getGamepadButtonPressed())}), 40, 60, 20, rl.Color.black);

        rl.drawText("Status:", rl.getScreenWidth() - 225, 10, 20, rl.Color.black);
        if (connected_client == null) {
            rl.drawText("Disconnected", rl.getScreenWidth() - 145, 10, 20, rl.Color.red);
        } else {
            rl.drawText("Connected", rl.getScreenWidth() - 145, 10, 20, rl.Color.green);
            rl.drawText("Client:", rl.getScreenWidth() - 145, 30, 20, rl.Color.green);
            rl.drawText(rl.textFormat("{}", .{connected_client.?}), rl.getScreenWidth() - 225, 30, 20, rl.Color.green);
        }

    }

    if (connected_client != null) {
        posix.close(socket);
    }
}

