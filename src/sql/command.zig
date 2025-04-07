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
                    const rows = try self.exectuteSelectQuery(tableName, columnNames);
                    for (rows.items) |row| {
                        for (row.columns.items, 0..) |col, idx| {
                            if (idx > 0) {
                                std.debug.print("|", .{});
                            }
                            std.debug.print("{s}", .{col});
                        }
                        std.debug.print("\n", .{});
                    }

                    defer for (rows.items) |row| {
                        row.columns.deinit();
                    };
                    defer rows.deinit();
                },
                // .is_function => |function| {
                //     const function_name = function.functionName;
                //     const table_name = function.tableName;
                //     const fields = function.fields;
                // },
                else => unreachable,
            }
        }

        pub fn exectuteSelectQuery(self: Self, tableName: []const u8, columnNames: ?std.ArrayList([]const u8)) !std.ArrayList(Row) {
            var db = try Database.init(self.allocator, self.file);
            // defer db.deinit();
            const queryInfo = try db.getQueryInfo(TableOperation{ .Select = .{
                .tableName = tableName,
                .columnNames = columnNames.?,
                .functionName = null,
            } });

            var nameSet = std.StringHashMap(u8).init(self.allocator);
            defer nameSet.deinit();

            for (columnNames.?.items) |colName| {
                const a: u8 = 1;
                try nameSet.put(colName, a);
            }

            const currentTable = try db.getTableByName(tableName);
            // defer currentTable.deinit();

            var rows = std.ArrayList(Row).init(self.allocator);

            var cellIterator = currentTable.getIterator();
            while (cellIterator.next()) |rowIter| {
                var rowMutable = rowIter;

                const columns = std.ArrayList([]const u8).init(self.allocator);
                var row = Row{ .columns = columns };

                var index: usize = 0;
                while (rowMutable.next()) |column_data| {
                    const columnName = queryInfo.get(index);
                    const has = nameSet.get(columnName.?);

                    if (has == 1) {
                        try row.columns.append(column_data);
                    }

                    index += 1;
                }
                try rows.append(row);
            }

            return rows;
        }
    };
}

const Row = struct {
    columns: std.ArrayList([]const u8),
};

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
