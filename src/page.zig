const std = @import("std");
const assert = std.debug.assert;

const Row = struct {
    content: []const u8,

    pub fn init(content: []const u8) Row {
        return Row{
            .content = content,
        };
    }
};

const DBHeader = @import("db-info.zig").DBHeader;

pub const Pager = struct {
    file: std.fs.File,
    page_size: u16,
    allocator: std.mem.Allocator,

    pub fn init(file: std.fs.File, allocator: std.mem.Allocator) !Pager {
        const header = try DBHeader.init(file);
        return Pager{
            .file = file,
            .page_size = header.page_size,
            .allocator = allocator,
        };
    }

    pub fn get_page(self: Pager, page_number: u16) !Page {
        return Page.read(self.allocator, self.file, self.page_size, page_number);
    }
};

pub const Page = struct {
    allocator: std.mem.Allocator,
    buffer: []u8,
    rows: []Row,
    header: Header,

    pub fn read(
        allocator: std.mem.Allocator,
        file: std.fs.File,
        page_size: u16,
        page_number: u16,
    ) !Page {
        var buffer = try allocator.alloc(u8, page_size);
        const page_offset = page_number * page_size;

        try file.seekTo(page_offset);
        _ = try file.read(buffer);

        const header_offset: u16 = if (page_number == 0) 100 else 0;
        const cell_count = std.mem.readInt(u16, buffer[header_offset + 3 .. header_offset + 5][0..2], .big);

        var cell_offsets = try allocator.alloc(u16, cell_count);
        for (0..cell_count) |i| {
            const start = header_offset + 8 + i * 2;
            const end = start + 2;
            const buf = buffer[start..end][0..2].*;
            const cell_pointer = std.mem.readInt(u16, &buf, .big);
            cell_offsets[i] = cell_pointer;
        }

        var rows = try allocator.alloc(Row, cell_count);

        for (0..cell_count) |i| {
            rows[i] = Row.init(buffer[cell_offsets[i]..]);
        }

        const header = Header{
            .cell_amount = cell_count,
            .cell_offsets = cell_offsets,
        };

        return Page{
            .allocator = allocator,
            .buffer = buffer,
            .rows = rows,
            .header = header,
        };
    }

    pub fn deinit(self: Page) void {
        self.allocator.free(self.header.cell_offsets);
        self.allocator.free(self.rows);
        self.allocator.free(self.buffer);
    }
};

const Header = struct {
    cell_amount: u16,
    cell_offsets: []u16,
};
