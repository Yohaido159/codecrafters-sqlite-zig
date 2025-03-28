pub fn readVarint(buffer: []const u8) struct { value: u64, bytes_read: usize } {
    var value: u64 = 0;
    var i: usize = 0;
    while (i < buffer.len) {
        const b = buffer[i];
        value = (value << 7) | @as(u64, b & 0x7F);
        i += 1;
        if ((b & 0x80) == 0) break;
    }
    return .{ .value = value, .bytes_read = i };
}

pub fn get_skip_size(serial_type: u64) usize {
    return switch (serial_type) {
        0 => 0, // NULL
        1 => 1, // 8-bit
        2 => 2, // 16-bit
        3 => 3, // 24-bit
        4 => 4, // 32-bit
        5 => 6, // 48-bit
        6, 7 => 8, // 64-bit int or float
        8, 9 => 0, // Constants 0 and 1
        10, 11 => unreachable, // Reserved for expansion
        else => if (serial_type > 13)
            (serial_type - 13) / 2
        else
            0,
    };
}
