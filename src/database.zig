const std = @import("std");
const Pager = @import("page.zig").Pager;
const Page = @import("page.zig").Page;
const SqliteSchemaRow = @import("sqlite-schema-row.zig").SqliteSchemaRow;
const TableOperation = @import("sql/parser.zig").TableOperation;

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

    pub fn getTableByName(self: Database, tableName: []const u8) !Page {
        const pageIndex = try self.systemTable.getTablePageIndex(tableName);
        const page = try self.pager.get_page(@intCast(pageIndex));
        return page;
    }

    pub fn getQueryInfo(self: Database, query: TableOperation) !std.AutoHashMap([]const u8, usize) {
        return try self.systemTable.getQueryInfo(query);
    }
};

pub const SystemTable = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    pager: Pager,
    pageZero: Page,

    pub fn init(allocator: std.mem.Allocator, pager: Pager, pageZero: Page) Self {
        return Self{
            .allocator = allocator,
            .pager = pager,
            .pageZero = pageZero,
        };
    }

    pub fn getQueryInfo(self: Self, query: TableOperation) !std.AutoHashMap([]const u8, usize) {
        assert(query == TableOperation.Select);
        const querySelect = query.Select;

        const pageZero = self.pageZero;
        const allocator = self.allocator;

        var result = std.AutoHashMap([]const u8, usize).init(allocator);
        defer result.deinit();

        for (pageZero.cells, 0..) |cell, idx| {
            const sqlite_row = try SqliteSchemaRow.init(cell.content);
            if (std.mem.eql(u8, sqlite_row.body.table_name, querySelect.tableName)) {
                for (querySelect.columnNames.?.items) |columnName| {
                    try result.put(columnName, idx);
                }
            }
        }

        return result;
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
