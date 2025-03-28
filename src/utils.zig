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
