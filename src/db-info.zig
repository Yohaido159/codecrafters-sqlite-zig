const std = @import("std");
const assert = std.debug.assert;

pub const DBHeader = struct {
    page_size: u16,

    pub fn init(file: std.fs.File) !DBHeader {
        const info = try DBInfo.init(file);
        return DBHeader{
            .page_size = try info.get_page_size(),
        };
    }
};

const DBInfo = struct {
    file: std.fs.File,

    fn init(file: std.fs.File) !DBInfo {
        return DBInfo{ .file = file };
    }

    pub fn get_page_size(self: DBInfo) !u16 {
        const file = self.file;
        var buf: [2]u8 = undefined;
        _ = try file.seekTo(16);
        _ = try file.read(&buf);
        return std.mem.readInt(u16, &buf, .big);
    }
};
