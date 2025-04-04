const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;

pub fn Command() type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) !Self {
            return Self{
                .allocator = allocator,
            };
        }

        pub fn parseCommand(self: Self, input: []const u8) !void {
            const lexer = Lexer.init(input, self.allocator);
            defer lexer.deinit();
            const tokens = try lexer.tokenize();

            const parser = try Parser.init(tokens, self.allocator);
            defer parser.deinit();

            const result = parser.parseQuery();
            switch (result) {
                .is_select => |select| {
                    const tableName = select.tableName;
                    const columnNames = select.columnNames;
                    // const whereClause = select.whereClause;
                    // self.exectuteSelectQuery(tableName, whereClause, columnNames);
                    self.exectuteSelectQuery(tableName, columnNames);
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
        fn exectuteSelectQuery(tableName: []const u8, columnNames: [][]const u8) void {
            const systemTableName = "sqlite_sequence";
            const systemTable = Database.getTableByName(systemTableName);
            const queryInfo = Database.getQueryInfo(.{
                .tableName = tableName,
                .columnNames = columnNames,
            });
            // result is hashmap name => index of column

            const currentTable = Database.getTableByName(tableName);

            const iterator = currentTable.getIterator();
            for (iterator.next()) |row| {
                // if (!WhereClause.valid(row)) {
                //     continue;
                // }
                const rowId = row.rowId;
                const rowData = row.data;

                const rowIterator = row.getIterator();
                for (rowIterator.next(), 0..) |column, idx| {
                    const columnNameExist = queryInfo.get(idx);
                    if (!columnNameExist) {
                        continue;
                    }
                    const data = column.data;

                    if (idx > 0) {
                        std.debug.print("|", .{});
                    }
                    std.debug.print("{s}", .{column});
                }
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
