const std = @import("std");
const assert = std.debug.assert;

pub const DBHeader = struct {
    page_size: u16,
    table_count: u16,
    content_offset: u16,
    cell_offsets: []u16,

    pub fn init(file: std.fs.File) !DBHeader {
        const info = try DBInfo.init(file);
        return DBHeader{
            .page_size = try info.get_page_size(),
            .table_count = try info.get_cell_count(),
            .content_offset = try info.get_content_offset(),
            .cell_offsets = try info.get_cell_pointers(),
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

    pub fn get_cell_count(self: DBInfo) !u16 {
        const file = self.file;
        _ = try file.seekTo(100);
        _ = try file.seekBy(3);
        var buf: [2]u8 = undefined;
        _ = try file.read(&buf);
        return std.mem.readInt(u16, &buf, .big);
    }

    pub fn get_cell_pointers(self: DBInfo) ![]u16 {
        const table_count = try self.get_cell_count();
        const allocator = std.heap.page_allocator;

        var cell_pointers = try allocator.alloc(u16, table_count);
        // defer allocator.free(cell_pointers);

        const file = self.file;
        _ = try file.seekTo(100 + 8);
        for (0..table_count) |i| {
            var buf: [2]u8 = undefined;
            _ = try file.read(&buf);
            const cell_pointer = std.mem.readInt(u16, &buf, .big);
            cell_pointers[i] = cell_pointer;
        }

        return cell_pointers;
    }

    pub fn get_content_offset(self: DBInfo) !u16 {
        const file = self.file;
        _ = try file.seekTo(100 + 12);
        var buf: [2]u8 = undefined;
        _ = try file.read(&buf);
        return std.mem.readInt(u16, &buf, .big);
    }
};
