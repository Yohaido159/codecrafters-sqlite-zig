const std = @import("std");
const assert = std.debug.assert;

pub const SqliteSchemaRow = struct {
    size: u64,
    row_id: u64,
    header: RowHeader,
    body: RowBody,

    fn readVarint(buffer: []const u8) struct { value: u64, bytes_read: usize } {
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

    fn applyCalculation(size: u64) u64 {
        return (size - 13) / 2;
    }

    fn get_skip_size(serial_type: u64) usize {
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

    pub fn init(content: []const u8) !SqliteSchemaRow {
        const cell_buf = content[0..];
        const row_size_varint = readVarint(cell_buf[0..]);
        var pos = row_size_varint.bytes_read;

        const rowid_varint = readVarint(cell_buf[pos..]);
        pos += rowid_varint.bytes_read;

        const header_len_varint = readVarint(cell_buf[pos..]);
        pos += header_len_varint.bytes_read;

        const type_size_varint = readVarint(cell_buf[pos..]);
        pos += type_size_varint.bytes_read;

        const name_varint = readVarint(cell_buf[pos..]);
        pos += name_varint.bytes_read;

        const table_name_varint = readVarint(cell_buf[pos..]);
        pos += table_name_varint.bytes_read;

        const root_page_varint = readVarint(cell_buf[pos..]);
        pos += root_page_varint.bytes_read;

        const sql_varint = readVarint(cell_buf[pos..]);
        pos += sql_varint.bytes_read;

        const header_len_skip = SqliteSchemaRow.get_skip_size(header_len_varint.value);
        const type_size_skip = SqliteSchemaRow.get_skip_size(type_size_varint.value);
        const name_size_skip = SqliteSchemaRow.get_skip_size(name_varint.value);
        const table_name_size_skip = SqliteSchemaRow.get_skip_size(table_name_varint.value);
        const root_page_size_skip = SqliteSchemaRow.get_skip_size(root_page_varint.value);
        const sql_size_skip = SqliteSchemaRow.get_skip_size(sql_varint.value);

        const row_size = row_size_varint.value;
        const row_id = rowid_varint.value;
        const header = RowHeader{
            .header_size = header_len_skip,
            .type_size = type_size_skip,
            .name_size = name_size_skip,
            .table_name_size = table_name_size_skip,
            .root_page_size = root_page_size_skip,
            .sql_size = sql_size_skip,
        };

        const body_type = content[pos .. pos + type_size_skip];
        pos += type_size_skip;

        const body_name = content[pos .. pos + name_size_skip];
        pos += name_size_skip;

        const body_table_name = content[pos .. pos + table_name_size_skip];
        pos += table_name_size_skip;

        const body_root_page = content[pos .. pos + root_page_size_skip];
        pos += root_page_size_skip;

        const body_sql = content[pos .. pos + sql_size_skip];
        pos += sql_size_skip;

        const body = RowBody{
            .type = body_type,
            .name = body_name,
            .table_name = body_table_name,
            .root_page = body_root_page,
            .sql = body_sql,
        };

        return SqliteSchemaRow{
            .size = row_size,
            .row_id = row_id,
            .header = header,
            .body = body,
        };
    }
};

const RowHeader = struct {
    header_size: u64,
    type_size: u64,
    name_size: u64,
    table_name_size: u64,
    root_page_size: u64,
    sql_size: u64,
};

const RowBody = struct {
    type: []const u8,
    name: []const u8,
    table_name: []const u8,
    root_page: []const u8,
    sql: []const u8,
};
