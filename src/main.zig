const std = @import("std");
const net = std.net;
const posix = std.posix;

pub fn main() !void {
    const address = try net.Address.parseIp("192.168.10.221", 8080);

    const tpe: u32 = posix.SOCK.STREAM;
    const protocol = posix.IPPROTO.TCP;
    const listener = try posix.socket(address.any.family, tpe, protocol);
    defer posix.close(listener);

    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(listener, &address.any, address.getOsSockLen());
    try posix.listen(listener, 128);

    //var read_buf: [256]u8 = undefined;
    while (true) {
        var client_address: net.Address = undefined;
        var client_address_len: posix.socklen_t = @sizeOf(net.Address);

        const socket = posix.accept(listener, &client_address.any, &client_address_len, 0) catch |err| {
            std.debug.print("error accept: {}\n", .{err});
            continue;
        };
        defer posix.close(socket);

        std.debug.print("{} connected\n", .{client_address});

        const stream = std.net.Stream{.handle = socket};

        while (true) {
            _ = try stream.write("Hello world\r\n");

            std.time.sleep(2 * std.time.ns_per_s);

            //const read = try stream.read(&read_buf);
            //if (read == 0) {
            //    continue;
            //}

            //std.debug.print("Received: {s}\n", .{read_buf[0..read]});
        }
    }
}

