const std = @import("std");

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

const DBInfo = struct {
    page_size: u16,
    table_count: u16,

    fn read(file: std.fs.File) !DBInfo {
        var buf: [2]u8 = undefined;
        _ = try file.seekTo(16);
        _ = try file.read(&buf);
        const page_size = std.mem.readInt(u16, &buf, .big);
        // header of b tree
        _ = try file.seekTo(100);

        // count of cell = tables
        _ = try file.seekBy(3);

        var table_count_buf: [2]u8 = undefined;
        _ = try file.read(&table_count_buf);
        const table_count = std.mem.readInt(u16, &table_count_buf, .big);

        return DBInfo{ .page_size = page_size, .table_count = table_count };
    }
};

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

    if (std.mem.eql(u8, command, ".dbinfo")) {
        var file = try std.fs.cwd().openFile(database_file_path, .{});
        defer file.close();

        const info = try DBInfo.read(file);
        try stdout.print("database page size: {}\n", .{info.page_size});
        try stdout.print("number of tables: {}\n", .{info.table_count});
        // Uncomment this block to pass the first stage
    }
}
