const std = @import("std");
const assert = std.debug.assert;

const utils = @import("utils.zig");

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

const BTreeLeafHeader = struct {
    size: u8,
    content: []const u8,
    pub fn init(content: []const u8) BTreeLeafHeader {
        const b_tree_byte = 0x0d;
        //make sure it's BTreeLeafHeader, the first byte should be 0x0D
        assert(content[0] == b_tree_byte);

        const size = 8;
        return BTreeLeafHeader{
            .size = size,
            .content = content[0..size],
        };
    }

    fn get_cell_amount(self: BTreeLeafHeader) u16 {
        const buf = self.content[3..5];
        const cell_count = std.mem.readInt(u16, buf, .big);
        return cell_count;
    }

    fn get_start_content_area(self: BTreeLeafHeader) u16 {
        const buf = self.content[5..7];
        const start_content_area = std.mem.readInt(u16, buf, .big);
        return start_content_area;
    }
};

const CellPointerArray = struct {
    cell_offsets: []u16,
    allocator: std.mem.Allocator,

    fn init(content: []const u8, cell_count: u16, allocator: std.mem.Allocator) !CellPointerArray {
        var cell_offsets = try allocator.alloc(u16, cell_count);

        for (0..cell_count) |i| {
            const start = i * 2;
            const end = start + 2;
            const buf = content[start..end][0..2];
            const cell_pointer = std.mem.readInt(u16, buf, .big);
            cell_offsets[i] = cell_pointer;
        }

        return CellPointerArray{
            .allocator = allocator,
            .cell_offsets = cell_offsets,
        };
    }

    pub fn deinit(self: CellPointerArray) void {
        self.allocator.free(self.cell_offsets);
    }
};

const BTreeLeafCell = struct {
    size: usize,
    row_id: u64,
    header_content: []const u8,
    data_content: []const u8,
    content: []const u8,

    pub fn init(content: []const u8) BTreeLeafCell {
        var pos: usize = 0;
        const size_varint = utils.readVarint(content[0..]);
        const size = size_varint.value;
        pos += size_varint.bytes_read;

        const row_id_varint = utils.readVarint(content[pos..]);
        const row_id = row_id_varint.value;
        pos += row_id_varint.bytes_read;

        const start_header_size_pos = pos;
        const header_size_varint = utils.readVarint(content[pos..]);
        const header_size = header_size_varint.value;
        pos += header_size_varint.bytes_read;

        const pos_content = start_header_size_pos + header_size;

        return BTreeLeafCell{
            .content = content,
            .size = size,
            .row_id = row_id,
            .header_content = content[start_header_size_pos..pos_content],
            .data_content = content[pos_content..],
        };
    }

    // pub fn parse_data(self: BTreeLeafCell)  {
    //     const header_content = self.header_content;
    //     const header_without_size = header_content[1..];
    //
    //     var header_index: usize = 0;
    //     var data_index: usize = 0;
    //     while (header_index < header_without_size.len) {
    //         const serial_type_varint = utils.readVarint(header_without_size[header_index..]);
    //         const serial_type = serial_type_varint.value;
    //         header_index += serial_type_varint.bytes_read;
    //
    //         const field_size = utils.get_skip_size(serial_type);
    //         const field_data = self.data_content[data_index .. data_index + field_size];
    //
    //         data_index += field_size;
    //     }
    // }
};

const FieldIterator = struct {
    columns_serial_type: []const u8, // header without the size byte
    data: []const u8,
    header_index: usize = 0,
    data_index: usize = 0,

    pub fn next(self: *FieldIterator) ?[]const u8 {
        if (self.header_index >= self.columns_serial_type.len) return null;

        const serial_type_varint = utils.readVarint(self.columns_serial_type[self.header_index..]);
        const serial_type = serial_type_varint.value;
        self.header_index += serial_type_varint.bytes_read;

        const field_size = utils.get_skip_size(serial_type);

        const field_data = self.data[self.data_index .. self.data_index + field_size];
        self.data_index += field_size;
        return field_data;
    }
};

pub fn fieldIterator(cell: BTreeLeafCell) FieldIterator {
    return FieldIterator{
        .columns_serial_type = cell.header_content[1..],
        .data = cell.data_content,
        .header_index = 0,
        .data_index = 0,
    };
}

const CellIterator = struct {
    page: *const Page,
    current_index: usize = 0,

    pub fn next(self: *CellIterator) ?FieldIterator {
        if (self.current_index >= self.page.meta.cell_amount) {
            return null;
        }

        const cell = self.page.cells[self.current_index];
        self.current_index += 1;

        return fieldIterator(cell);
    }
};

const Meta = struct {
    cell_amount: u16,
    cell_offsets: []u16,
};

pub const Page = struct {
    allocator: std.mem.Allocator,
    buffer: []u8,
    cells: []BTreeLeafCell,
    meta: Meta,

    pub fn getIterator(self: *const Page) CellIterator {
        return CellIterator{
            .page = self,
            .current_index = 0,
        };
    }
    pub fn read(
        allocator: std.mem.Allocator,
        file: std.fs.File,
        page_size: u16,
        page_number: u16,
    ) !Page {
        var page_buffer = try allocator.alloc(u8, page_size);
        const page_offset = page_number * page_size;

        try file.seekTo(page_offset);
        _ = try file.read(page_buffer);

        const db_header_offset_size: u16 = if (page_number == 0) 100 else 0;
        const b_tree_header = BTreeLeafHeader.init(page_buffer[db_header_offset_size..]);
        const cell_count = b_tree_header.get_cell_amount();

        const cell_pointer_array = try CellPointerArray.init(page_buffer[db_header_offset_size + b_tree_header.size ..], cell_count, allocator);
        const cell_offsets = cell_pointer_array.cell_offsets;

        var cells = try allocator.alloc(BTreeLeafCell, cell_count);

        for (0..cell_count) |i| {
            const cell_offset = cell_offsets[i];
            // const cell_size = page_buffer[cell_offset];
            // const skip_size_and_row_id = 2;

            const start_offset = cell_offset;
            // const end_offset = cell_offset + skip_size_and_row_id + cell_size;
            // const cell = BTreeLeafCell.init(page_buffer[start_offset..end_offset]);
            const cell = BTreeLeafCell.init(page_buffer[start_offset..]);
            cells[i] = cell;
        }

        const meta = Meta{
            .cell_amount = cell_count,
            .cell_offsets = cell_offsets,
        };

        return Page{
            .allocator = allocator,
            .buffer = page_buffer,
            .cells = cells,
            .meta = meta,
        };
    }

    pub fn deinit(self: Page) void {
        self.allocator.free(self.meta.cell_offsets);
        self.allocator.free(self.cells);
        self.allocator.free(self.buffer);
    }
};
