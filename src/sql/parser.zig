const std = @import("std");
const assert = std.debug.assert;
const Token = @import("./lexer.zig").Token;
const Lexer = @import("./lexer.zig").Lexer;

pub const Parser = struct {
    tokens: []const Token,
    pos: usize,
    fieldNames: std.ArrayList([]const u8),
    tableName: []u8,

    pub fn init(tokens: []const Token, allocator: std.mem.Allocator) !Parser {
        return Parser{
            .tokens = tokens,
            .pos = 0,
            .fieldNames = std.ArrayList([]const u8).init(allocator),
            .tableName = "",
        };
    }

    pub fn deinit(self: *Parser) void {
        self.fieldNames.deinit();
    }

    const Result = struct {
        fieldNames: std.ArrayList([]const u8),
        tableName: []const u8,
    };

    fn parseQuery(self: *Parser) !Result {
        while (true) {
            if (self.isAtEnd()) {
                return .{
                    .fieldNames = self.fieldNames,
                    .tableName = self.tableName,
                };
            }

            const token = self.getToken();
            switch (token) {
                .Keyword => |kw| {
                    if (std.mem.eql(u8, kw.lexeme, "SELECT")) {
                        try self.parseSelectQuery();
                    }
                },
                else => error.InvalidToken,
            }
        }
    }

    fn parseSelectQuery(self: *Parser) !void {
        try self.expectToken(Token{ .Keyword = .{ .lexeme = "SELECT" } });
        try self.expectToken(.Identifier);
        try self.expectToken(.Keyword);
        try self.expectToken(.Identifier);
    }

    fn getToken(self: *Parser) Token {
        return self.tokens[self.pos];
    }

    fn advance(self: *Parser) void {
        self.pos += 1;
    }

    fn expectToken(self: *Parser, token: Token) !void {
        const current = self.getToken();
        switch (current) {
            .Keyword => |kw| {
                if (std.mem.eql(u8, kw.lexeme, token.Keyword.lexeme)) {
                    self.advance();
                } else {
                    return error.InvalidToken;
                }
            },
            .Identifier => |id| {
                if (std.mem.eql(u8, id.lexeme, token.Identifier.lexeme)) {
                    self.advance();
                } else {
                    return error.InvalidToken;
                }
            },
            else => return error.InvalidToken,
        }

        self.pos += 1;
    }

    fn isAtEnd(self: *Parser) bool {
        return self.pos >= self.tokens.len;
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
    const result = try parser.parseQuery();
    try testing.expectEqualStrings("name", result.fieldNames.items[0]);
    try testing.expectEqualStrings("table", result.tableName);
}
