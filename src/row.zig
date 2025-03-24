const std = @import("std");
const assert = std.debug.assert;

pub const Row = struct {
    size: u8,
    row_id: u8,
    header: RowHeader,
    body: RowBody,

    pub fn init(content: []const u8) !Row {
        const row_size = content[0];
        const row_id = content[1];
        const header = RowHeader{
            .header_size = content[2],
            .type_size = (content[3] - 13) / 2,
            .name_size = (content[4] - 13) / 2,
            .table_name_size = (content[5] - 13) / 2,
            .root_page_size = content[6],
            .sql_size = ((content[7] + content[8]) - 13) / 2,
        };

        const start_type = 2 + header.header_size;
        const end_type = start_type + header.type_size;

        const start_name = end_type;
        const end_name = start_name + header.name_size;

        const start_table_name = end_name;
        const end_table_name = start_table_name + header.table_name_size;

        const start_root_page = end_table_name;
        const end_root_page = start_root_page + header.root_page_size;

        // const start_sql = end_root_page;
        // const end_sql = start_sql + header.sql_size;

        const body = RowBody{
            .type = content[start_type..end_type],
            .name = content[start_name..end_name],
            .table_name = content[start_table_name..end_table_name],
            .root_page = content[start_root_page..end_root_page],
            // .sql = content[start_sql..end_sql],
        };

        return Row{
            .size = row_size,
            .row_id = row_id,
            .header = header,
            .body = body,
        };
    }
};

const RowHeader = struct {
    header_size: u8,
    type_size: u8,
    name_size: u8,
    table_name_size: u8,
    root_page_size: u8,
    sql_size: u16,
};

const RowBody = struct {
    type: []const u8,
    name: []const u8,
    table_name: []const u8,
    root_page: []const u8,
    // sql: []const u8,
};
