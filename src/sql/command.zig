const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const Database = @import("../database.zig").Database;
const TableOperation = @import("parser.zig").TableOperation;

pub fn Command() type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        file: std.fs.File,

        pub fn init(allocator: std.mem.Allocator, file: std.fs.File) Self {
            return Self{
                .allocator = allocator,
                .file = file,
            };
        }

        pub fn parseCommand(self: Self, input: []const u8) !void {
            var lexer = Lexer.init(input, self.allocator);
            defer lexer.deinit();
            const tokens = try lexer.tokenize();

            var parser = try Parser.init(tokens, self.allocator);
            defer parser.deinit();

            const result = try parser.parseQuery();
            switch (result) {
                .Select => |select| {
                    const tableName = select.tableName;
                    const columnNames = select.columnNames;
                    // const whereClause = select.whereClause;
                    // self.exectuteSelectQuery(tableName, whereClause, columnNames);
                    try self.exectuteSelectQuery(tableName, columnNames);
                },
                // .is_function => |function| {
                //     const function_name = function.functionName;
                //     const table_name = function.tableName;
                //     const fields = function.fields;
                // },
                else => unreachable,
            }
        }

        // fn exectuteSelectQuery(tableName: []const u8, whereClause: WhereClause, columnNames: [][]const u8) void {
        pub fn exectuteSelectQuery(self: Self, tableName: []const u8, columnNames: ?std.ArrayList([]const u8)) !void {
            const db = try Database.init(self.allocator, self.file);
            const queryInfo = try db.getQueryInfo(TableOperation{ .Select = .{
                .tableName = tableName,
                .columnNames = columnNames.?,
                .functionName = null,
            } });
            _ = queryInfo; // autofix
            // result is hashmap name => index of column

            const currentTable = try db.getTableByName(tableName);

            const cellIterator = currentTable.getIterator();
            for (cellIterator.next()) |row| {
                _ = row; // autofix
                // if (!WhereClause.valid(row)) {
                //     continue;
                // }
                // const rowId = row.rowId;
                // const rowData = row.data;
                //
                // const rowIterator = row.getIterator();
                // for (rowIterator.next(), 0..) |column, idx| {
                //     const columnNameExist = queryInfo.get(idx);
                //     if (!columnNameExist) {
                //         continue;
                //     }
                //     const data = column.data;
                //
                //     if (idx > 0) {
                //         std.debug.print("|", .{});
                //     }
                //     std.debug.print("{s}", .{column});
                // }
            }
        }
    };
}

const WhereClause = struct {
    head: ?Node,

    pub fn init() WhereClause {
        return WhereClause{
            .head = null,
        };
    }
};

const Node = struct {
    columnName: []const u8,
    operator: OperatorType,
    value: []const u8,
};

const OperatorType = enum {
    Equal,
    And,
    Or,
};
