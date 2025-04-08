const std = @import("std");
const Pager = @import("page.zig").Pager;
const Page = @import("page.zig").Page;
const SqliteSchemaRow = @import("sqlite-schema-row.zig").SqliteSchemaRow;
const TableOperation = @import("sql/parser.zig").TableOperation;
const Lexer = @import("sql/lexer.zig").Lexer;
const Parser = @import("sql/parser.zig").Parser;

const assert = std.debug.assert;

pub const Database = struct {
    allocator: std.mem.Allocator,
    pager: Pager,
    pageZero: Page,
    systemTable: SystemTable,

    pub fn init(allocator: std.mem.Allocator, file: std.fs.File) !Database {
        const pager = try Pager.init(file, allocator);
        const pageZero = try pager.get_page(0);

        return Database{
            .allocator = allocator,
            .pageZero = pageZero,
            .pager = pager,
            .systemTable = SystemTable.init(allocator, pager, pageZero),
        };
    }

    pub fn deinit(self: *Database) void {
        self.pageZero.deinit();
    }

    pub fn getTableByName(self: *Database, tableName: []const u8) !Page {
        const pageIndex = try self.systemTable.getTablePageIndex(tableName);
        const page = try self.pager.get_page(@intCast(pageIndex));
        return page;
    }

    pub fn getQueryInfo(self: *Database, query: TableOperation) !std.AutoHashMap(usize, []const u8) {
        return try self.systemTable.getQueryInfo(query);
    }
    pub fn nameToIndex(self: *Database, query: TableOperation) !std.StringHashMap(usize) {
        return try self.systemTable.nameToIndex(query);
    }
};

pub const SystemTable = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    pager: Pager,
    pageZero: Page,
    queryResult: std.AutoHashMap(usize, []const u8),

    pub fn init(allocator: std.mem.Allocator, pager: Pager, pageZero: Page) Self {
        return Self{
            .allocator = allocator,
            .pager = pager,
            .pageZero = pageZero,
            .queryResult = std.AutoHashMap(usize, []const u8).init(allocator),
        };
    }

    pub fn getQueryInfo(self: *Self, query: TableOperation) !std.AutoHashMap(usize, []const u8) {
        assert(query == TableOperation.Select);
        const querySelect = query.Select;

        const pageZero = self.pageZero;
        const allocator = self.allocator;

        var result = std.AutoHashMap(usize, []const u8).init(allocator);
        defer result.deinit();

        for (pageZero.cells) |cell| {
            const sqlite_row = try SqliteSchemaRow.init(cell.content);
            if (std.mem.eql(u8, sqlite_row.body.table_name, querySelect.tableName)) {
                var lexerSql = Lexer.init(sqlite_row.body.sql, allocator);
                defer lexerSql.deinit();

                const tokensSql = try lexerSql.tokenize();

                var parserSql = try Parser.init(tokensSql, allocator);
                defer parserSql.deinit();

                const resultSql = try parserSql.parseQuery();
                defer self.allocator.free(resultSql.CreateTable.fields);
                for (resultSql.CreateTable.fields, 0..) |field, column_index| {
                    try result.put(column_index, field.name);
                }
            }
        }

        return try result.clone();
    }

    pub fn nameToIndex(self: *Self, query: TableOperation) !std.StringHashMap(usize) {
        assert(query == TableOperation.Select);
        const querySelect = query.Select;

        const pageZero = self.pageZero;
        const allocator = self.allocator;

        var result = std.StringHashMap(usize).init(allocator);
        defer result.deinit();

        for (pageZero.cells) |cell| {
            const sqlite_row = try SqliteSchemaRow.init(cell.content);
            if (std.mem.eql(u8, sqlite_row.body.table_name, querySelect.tableName)) {
                var lexerSql = Lexer.init(sqlite_row.body.sql, allocator);
                defer lexerSql.deinit();

                const tokensSql = try lexerSql.tokenize();

                var parserSql = try Parser.init(tokensSql, allocator);
                defer parserSql.deinit();

                const resultSql = try parserSql.parseQuery();
                defer self.allocator.free(resultSql.CreateTable.fields);
                for (resultSql.CreateTable.fields, 0..) |field, column_index| {
                    try result.put(field.name, column_index);
                }
            }
        }

        return try result.clone();
    }

    fn getTablePageIndex(self: Self, tableName: []const u8) !usize {
        const pageZero = self.pageZero;

        for (pageZero.cells) |cell| {
            const sqlite_row = try SqliteSchemaRow.init(cell.content);
            if (std.mem.eql(u8, sqlite_row.body.table_name, tableName)) {
                return sqlite_row.body.root_page[0] - 1;
            }
        }

        return error.TableNotFound;
    }
};
