const std = @import("std");

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

const assert = std.debug.assert;

const DBHeader = @import("db-info.zig").DBHeader;
const Pager = @import("page.zig").Pager;
const SqliteSchemaRow = @import("sqlite-schema-row.zig").SqliteSchemaRow;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        try stderr.print("Usage: {s} <database_file_path> <command>\n", .{args[0]});
        return;
    }

    const database_file_path: []const u8 = args[1];
    const command: []const u8 = args[2];

    var file = try std.fs.cwd().openFile(database_file_path, .{});
    defer file.close();

    const db_header = try DBHeader.init(file);

    const pager = try Pager.init(file, allocator);

    if (std.mem.eql(u8, command, ".dbinfo")) {
        const page = try pager.get_page(0);
        defer page.deinit();

        try stdout.print("database page size: {any}\n", .{db_header.page_size});
        try stdout.print("number of tables: {any}\n", .{page.header.cell_amount});
    }

    if (std.mem.eql(u8, command, ".tables")) {
        const page = try pager.get_page(0);
        defer page.deinit();

        for (page.rows) |row| {
            const sqlite_row = try SqliteSchemaRow.init(row.content);
            if (std.mem.eql(u8, sqlite_row.body.table_name, "sqlite_sequence")) {
                continue;
            }

            try stdout.print("{s} ", .{sqlite_row.body.table_name});
        }
    } else {
        var iter = std.mem.splitBackwardsAny(u8, command, " ");
        const table_name = iter.first();
        const page = try pager.get_page(0);
        defer page.deinit();

        for (page.rows) |row| {
            const sqlite_row = try SqliteSchemaRow.init(row.content);
            if (std.mem.eql(u8, sqlite_row.body.table_name, table_name)) {
                const selected_table = try pager.get_page(sqlite_row.body.root_page[0] - 1);
                defer selected_table.deinit();

                try stdout.print("{}\n", .{selected_table.header.cell_amount});
            }
        }
    }
}
