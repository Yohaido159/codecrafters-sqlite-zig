const std = @import("std");

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

const assert = std.debug.assert;

const DBHeader = @import("db-info.zig").DBHeader;
const Pager = @import("page.zig").Pager;
const fieldIterator = @import("page.zig").fieldIterator;
const FieldIterator = @import("page.zig").FieldIterator;
const SqliteSchemaRow = @import("sqlite-schema-row.zig").SqliteSchemaRow;
const Lexer = @import("sql/lexer.zig").Lexer;
const Parser = @import("sql/parser.zig").Parser;
const Command = @import("sql/command.zig").Command;

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
    const page_zero = try pager.get_page(0);
    defer page_zero.deinit();

    if (std.mem.eql(u8, command, ".dbinfo")) {
        try stdout.print("database page size: {any}\n", .{db_header.page_size});
        try stdout.print("number of tables: {any}\n", .{page_zero.meta.cell_amount});
    }

    if (std.mem.eql(u8, command, ".tables")) {
        for (page_zero.cells) |cell| {
            const sqlite_row = try SqliteSchemaRow.init(cell.content);
            if (std.mem.eql(u8, sqlite_row.body.table_name, "sqlite_sequence")) {
                continue;
            }

            try stdout.print("{s} ", .{sqlite_row.body.table_name});
        }
    } else {
        var commandInstance = try Command().init(allocator, file);
        try commandInstance.parseCommand(command);
        defer commandInstance.deinit();
        // var lexer = Lexer.init(command, allocator);
        // defer lexer.deinit();
        //
        // const tokens = try lexer.tokenize();
        // var parser = try Parser.init(tokens, allocator);
        // defer parser.deinit();
        //
        // const result = try parser.parseQuery();
        // const table_name = result.Select.tableName;
        // const function_name = result.Select.functionName;
        // // const columns = result.Select.fieldNames;
        // // const column = columns.items[0];
        //
        // for (page_zero.cells) |cell| {
        //     const sqlite_row = try SqliteSchemaRow.init(cell.content);
        //     if (std.mem.eql(u8, sqlite_row.body.table_name, table_name)) {
        //         const selected_table = try pager.get_page(sqlite_row.body.root_page[0] - 1);
        //         defer selected_table.deinit();
        //
        //         var lexerSql = Lexer.init(sqlite_row.body.sql, allocator);
        //         defer lexerSql.deinit();
        //
        //         const tokensSql = try lexerSql.tokenize();
        //
        //         var parserSql = try Parser.init(tokensSql, allocator);
        //         defer parserSql.deinit();
        //
        //         const resultSql = try parserSql.parseQuery();
        //
        //         if (function_name) |functionname| {
        //             if (std.mem.eql(u8, functionname, "count")) {
        //                 try stdout.print("{any}\n", .{selected_table.meta.cell_amount});
        //                 return;
        //             }
        //         }
        //
        //         const columns = result.Select.columnNames.?;
        //
        //         for (selected_table.cells) |selected_table_cell| {
        //             var iter_cells = fieldIterator(selected_table_cell);
        //             var field_values = std.ArrayList([]const u8).init(allocator);
        //             defer field_values.deinit();
        //
        //             // Collect all field values from this row
        //             while (iter_cells.next()) |field_data| {
        //                 try field_values.append(field_data);
        //             }
        //
        //             // Print only the requested columns with proper separators
        //             var first_column = true;
        //             for (columns.items) |column| {
        //                 var match_index: ?usize = null;
        //
        //                 // Find the index of this column in the table schema
        //                 for (resultSql.CreateTable.fields.items, 0..) |field, i| {
        //                     if (std.mem.eql(u8, field.name, column)) {
        //                         match_index = i;
        //                         break;
        //                     }
        //                 }
        //
        //                 // Print the value if we found the column
        //                 if (match_index) |idx| {
        //                     if (!first_column) {
        //                         try stdout.print("|", .{});
        //                     }
        //                     if (idx < field_values.items.len) {
        //                         try stdout.print("{s}", .{field_values.items[idx]});
        //                     }
        //                     first_column = false;
        //                 }
        //             }
        //             try stdout.print("\n", .{});
        //         }
        //
        //         // const columns = result.Select.fieldNames.?;
        //         //
        //         // for (columns.items) |column| {
        //         //     var match_index: u8 = 0;
        //         //     for (resultSql.CreateTable.fields.items) |field| {
        //         //         if (std.mem.eql(u8, field.name, column)) {
        //         //             break;
        //         //         }
        //         //         //
        //         //         match_index += 1;
        //         //         for (selected_table.cells) |selected_table_cell| {
        //         //             var iter_cells = fieldIterator(selected_table_cell);
        //         //             var match_index_cell: u8 = 0;
        //         //             while (iter_cells.next()) |field_data| {
        //         //                 if (match_index_cell == match_index) {
        //         //                     try stdout.print("{s}", .{field_data});
        //         //                 }
        //         //
        //         //                 match_index_cell += 1;
        //         //             }
        //         //             try stdout.print("\n", .{});
        //         //         }
        //         //     }
        //         //
        //         // }
        //     }
    }
    // }
}
