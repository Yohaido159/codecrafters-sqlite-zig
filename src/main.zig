const std = @import("std");

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

const assert = std.debug.assert;

const DBHeader = @import("db-info.zig").DBHeader;
const Page = @import("page.zig").Page;

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
    const header_offset = 100;
    const content_offset = db_header.content_offset;
    const cell_offsets = db_header.cell_offsets;

    const buffer = try allocator.alloc(u8, db_header.page_size);
    defer allocator.free(buffer);
    _ = try file.preadAll(buffer, 0);
    const page = try Page.init(db_header.page_size, header_offset, content_offset, cell_offsets, buffer, allocator);
    defer {
        page.deinit(allocator) catch {
            unreachable;
        };
    }

    if (std.mem.eql(u8, command, ".dbinfo")) {
        try stdout.print("database page size: {any}\n", .{db_header.page_size});
        try stdout.print("number of tables: {any}\n", .{db_header.table_count});
    }

    if (std.mem.eql(u8, command, ".tables")) {
        for (page.content.rows) |row| {
            if (std.mem.eql(u8, row.body.name, "sqlite_sequences")) {
                continue;
            }

            try stdout.print("{s}\n", .{row.body.name});
        }
    }
}
