const std = @import("std");
const assert = std.debug.assert;

const Row = @import("row.zig").Row;

pub const Page = struct {
    size: u16,
    header_offset: u16,
    content_offset: u16,
    data: []const u8,
    content: PageContent,

    pub fn init(
        size: u16,
        header_offset: u16,
        content_offset: u16,
        cell_offsets: []u16,
        data: []const u8,
        allocator: std.mem.Allocator,
    ) !Page {
        assert(data.len == size);

        const page = Page{
            .size = size,
            .header_offset = header_offset,
            .content_offset = content_offset,
            .data = data,
            .content = try PageContent.init(data, cell_offsets, allocator),
        };

        return page;
    }

    pub fn deinit(self: Page, allocator: std.mem.Allocator) !void {
        _ = allocator.free(self.content.rows);
    }
};

const PageContent = struct {
    rows: []Row,

    pub fn init(data: []const u8, cell_offsets: []u16, allocator: std.mem.Allocator) !PageContent {
        const rows_buffer = try allocator.alloc(Row, cell_offsets.len);

        const rows: []Row = try extract_rows(rows_buffer, data, cell_offsets);
        return PageContent{ .rows = rows };
    }

    fn extract_rows(rows_buffer: []Row, data: []const u8, cell_offsets: []u16) ![]Row {
        var i: u16 = 0;
        for (cell_offsets) |cell_offset| {
            const row_size = data[cell_offset];
            const row: Row = try Row.init(data[cell_offset .. cell_offset + row_size]);
            rows_buffer[i] = row;
            i += 1;
        }

        return rows_buffer;
    }
};
