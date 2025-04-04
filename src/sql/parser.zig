const std = @import("std");
const assert = std.debug.assert;
const Token = @import("./lexer.zig").Token;
const Lexer = @import("./lexer.zig").Lexer;

pub const TableOperation = union(enum) {
    Select: struct {
        functionName: ?[]const u8,
        tableName: []const u8,
        columnNames: ?std.ArrayList([]const u8),
    },
    CreateTable: struct { tableName: []const u8, fields: std.ArrayList(Field) },
};

pub const Field = struct {
    name: []const u8,
    dataType: DataType,
};

pub const DataType = enum {
    integer,
    text,
};

pub const Parser = struct {
    tokens: []const Token,
    pos: usize,
    columnNames: std.ArrayList([]const u8),
    tableName: []const u8,

    pub fn init(tokens: []const Token, allocator: std.mem.Allocator) !Parser {
        _ = allocator;
        return Parser{
            .tokens = tokens,
            .pos = 0,
            .columnNames = std.ArrayList([]const u8).init(std.heap.page_allocator),
            .tableName = "",
        };
    }

    pub fn deinit(self: *Parser) void {
        self.columnNames.deinit();
    }

    const Result = struct {
        columnNames: std.ArrayList([]const u8),
        tableName: []const u8,
    };

    pub fn parseQuery(self: *Parser) !TableOperation {
        const token = self.getToken();
        return try switch (token) {
            .Keyword => |kw| {
                if (std.mem.eql(u8, kw.lexeme, "select")) {
                    return try self.parseSelectQuery();
                } else if (std.mem.eql(u8, kw.lexeme, "CREATE")) {
                    return try self.parseCreateTableQuery();
                }
                unreachable;
            },
            else => unreachable,
        };
    }

    fn parseSelectQuery(self: *Parser) !TableOperation {
        try self.expectKeywordToken(Token{ .Keyword = .{ .lexeme = "select" } });
        self.advance();
        if (self.checkIdentifierToken(self.getToken())) {
            try self.parseFieldNames();
            try self.expectKeywordToken(Token{ .Keyword = .{ .lexeme = "from" } });
            self.advance();
            try self.parseTableName();

            return TableOperation{ .Select = .{
                .columnNames = self.columnNames,
                .tableName = self.tableName,
                .functionName = null,
            } };
        } else if (self.checkKeywordToken(Token{ .Keyword = .{ .lexeme = "count" } })) {
            try self.expectKeywordToken(Token{ .Keyword = .{ .lexeme = "count" } });
            self.advance();
            try self.expectSymbolToken(Token{ .Symbol = .{ .lexeme = "(" } });
            self.advance();
            try self.expectSymbolToken(Token{ .Symbol = .{ .lexeme = "*" } });
            self.advance();
            try self.expectSymbolToken(Token{ .Symbol = .{ .lexeme = ")" } });
            self.advance();
            try self.expectKeywordToken(Token{ .Keyword = .{ .lexeme = "from" } });
            self.advance();
            try self.parseTableName();

            return TableOperation{ .Select = .{
                .columnNames = null,
                .functionName = "count",
                .tableName = self.tableName,
            } };
        } else {
            unreachable;
        }
    }

    fn parseFieldNames(self: *Parser) !void {
        while (self.pos < self.tokens.len) {
            const tokeninner = self.getToken();
            if (tokeninner == .Symbol) {
                self.advance();
                continue;
            }

            if (tokeninner == .Keyword) {
                break;
            }
            const token = self.getToken();
            try self.expectIdentifierToken(token);
            try self.columnNames.append(token.Identifier.lexeme);
            self.advance();
        }
    }

    fn parseTableName(self: *Parser) !void {
        const token = self.getToken();
        try self.expectIdentifierToken(token);
        self.tableName = token.Identifier.lexeme;
    }

    fn parseCreateTableQuery(self: *Parser) !TableOperation {
        try self.expectKeywordToken(Token{ .Keyword = .{ .lexeme = "CREATE" } });
        self.advance();
        try self.expectKeywordToken(Token{ .Keyword = .{ .lexeme = "TABLE" } });
        self.advance();
        try self.expectIdentifierToken(self.getToken());
        self.advance();
        try self.expectSymbolToken(Token{ .Symbol = .{ .lexeme = "(" } });
        self.advance();

        var fields = std.ArrayList(Field).init(self.columnNames.allocator);
        try self.parseFields(&fields);

        return TableOperation{ .CreateTable = .{
            .tableName = self.tableName,
            .fields = fields,
        } };
    }

    fn parseFields(self: *Parser, fields: *std.ArrayList(Field)) !void {
        // we should start consume token by token, the first token is the Identifier of the field name
        // the second token is the data type
        // we should skip the field that has 'primary key as it's the row_id and not store in the table

        while (self.pos < self.tokens.len) {
            const token = self.getToken();
            if (token == .Symbol and std.mem.eql(u8, token.Symbol.lexeme, ")")) {
                break;
            }

            try self.expectIdentifierToken(token);
            const fieldName = token.Identifier.lexeme;
            self.advance();

            const dataTypeToken = self.getToken();
            try self.expectIdentifierToken(dataTypeToken);

            var dataType: DataType = undefined;
            if (std.mem.eql(u8, dataTypeToken.Identifier.lexeme, "integer")) {
                dataType = DataType.integer;
                self.advance();
            } else if (std.mem.eql(u8, dataTypeToken.Identifier.lexeme, "text")) {
                dataType = DataType.text;
                self.advance();
            }
            {
                while (self.pos < self.tokens.len) {
                    const tokeninner = self.getToken();
                    if (tokeninner == .Symbol and std.mem.eql(u8, tokeninner.Symbol.lexeme, ",")) {
                        self.advance();
                        break;
                    }
                    self.advance();
                }
            }

            try fields.append(Field{ .name = fieldName, .dataType = dataType });
        }
    }

    fn getToken(self: *Parser) Token {
        return self.tokens[self.pos];
    }

    fn advance(self: *Parser) void {
        self.pos += 1;
    }

    fn expectKeywordToken(self: *Parser, token: Token) !void {
        const currentToken = self.getToken();
        assert(currentToken == .Keyword and std.mem.eql(u8, currentToken.Keyword.lexeme, token.Keyword.lexeme));
    }

    fn checkKeywordToken(self: *Parser, token: Token) bool {
        const currentToken = self.getToken();
        return currentToken == .Keyword and std.mem.eql(u8, currentToken.Keyword.lexeme, token.Keyword.lexeme);
    }

    fn expectSymbolToken(self: *Parser, token: Token) !void {
        const currentToken = self.getToken();
        assert(currentToken == .Symbol and std.mem.eql(u8, currentToken.Symbol.lexeme, token.Symbol.lexeme));
    }

    fn expectIdentifierToken(self: *Parser, token: Token) !void {
        const currentToken = self.getToken();
        assert(currentToken == .Identifier and std.mem.eql(u8, currentToken.Identifier.lexeme, token.Identifier.lexeme));
    }

    fn checkIdentifierToken(self: *Parser, token: Token) bool {
        const currentToken = self.getToken();
        return currentToken == .Identifier and std.mem.eql(u8, currentToken.Identifier.lexeme, token.Identifier.lexeme);
    }
};

const testing = std.testing;

test "Parser - parse simple query" {
    const input = "SELECT name FROM table";
    var lexer = Lexer.init(input, testing.allocator);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    try testing.expectEqual(@as(usize, 5), tokens.len); // 4 tokens + EOF

    var parser = try Parser.init(tokens, testing.allocator);
    defer parser.deinit();
    const result = try parser.parseQuery();
    try testing.expectEqualStrings("name", result.columnNames.items[0]);
    try testing.expectEqualStrings("table", result.tableName);
}
