const std = @import("std");
const assert = std.debug.assert;

pub const Lexer = struct {
    input: []const u8,
    pos: usize = 0,
    tokens: std.ArrayList(Token),

    pub fn init(input: []const u8, allocator: std.mem.Allocator) !Lexer {
        const tokens = std.ArrayList(Token).init(allocator);
        return Lexer{
            .input = input,
            .tokens = tokens,
        };
    }

    pub fn deinit(self: Lexer) void {
        self.tokens.deinit();
    }

    const symbol_set = std.StaticStringMap(u8).initComptime(.{
        .{ "(", 0 },
        .{ ")", 0 },
        .{ "*", 0 },
    });

    pub fn isSymbol(c: u8) bool {
        const symbol_str = [_]u8{c};
        return symbol_set.has(&symbol_str);
    }

    const keywords = std.StaticStringMap(u8).initComptime(.{
        .{ "SELECT", 0 },
        .{ "FROM", 0 },
        .{ "COUNT", 0 },
    });

    pub fn isKeyword(keyword: []const u8) bool {
        return keywords.has(keyword);
    }
    fn next_token(self: *Lexer) !Token {
        if (self.check_is_end()) {
            return Token{ .Eof = .{ .lexeme = "" } };
        }

        self.skip_whitespace();

        const start_pos = self.pos;
        while (!self.check_is_end() and !self.is_whitespace(self.input[self.pos])) {
            _ = self.next_char();
        }
        const end_pos = self.pos;

        const token = self.input[start_pos..end_pos];
        if (Lexer.isSymbol(token[0])) {
            return Token{ .Symbol = .{ .lexeme = token } };
        } else if (Lexer.isKeyword(token)) {
            return Token{ .Keyword = .{ .lexeme = token } };
        } else {
            return Token{ .Identifier = .{ .lexeme = token } };
        }
    }

    fn peek_token(self: *Lexer) !Token {
        const saved_pos = self.pos;
        const token = try self.next_token();
        self.pos = saved_pos;
        return token;
    }

    fn is_whitespace(self: *Lexer, c: u8) bool {
        _ = self; // autofix
        return c == ' ' or c == '\t' or c == '\n' or c == '\r';
    }

    fn check_is_end(self: *Lexer) bool {
        return self.pos >= self.input.len;
    }

    fn next_char(self: *Lexer) ?u8 {
        self.pos += 1;
        if (self.check_is_end()) {
            return null;
        }

        const c = self.input[self.pos];
        return c;
    }

    fn skip_whitespace(self: *Lexer) void {
        while (self.is_whitespace(self.input[self.pos])) {
            _ = self.next_char();
        }
    }

    pub fn parse_string_to_tokens(self: *Lexer) ![]Token {
        while (!self.check_is_end()) {
            const token = try self.next_token();
            try self.tokens.append(token);
        }

        return self.tokens.items;
    }
};

pub const Token = union(enum) {
    Symbol: struct { lexeme: []const u8 },
    Keyword: struct { lexeme: []const u8 },
    Identifier: struct { lexeme: []const u8 },
    Eof: struct { lexeme: []const u8 },
};

const testing = std.testing;

test "Lexer - initialization and deinitialization" {
    const input = "SELECT name FROM table";
    var lexer = try Lexer.init(input, testing.allocator);
    defer lexer.deinit();

    try testing.expectEqualStrings(input, lexer.input);
    try testing.expect(lexer.pos == 0);
}

test "Lexer - tokenize simple query" {
    const input = "SELECT name FROM table";
    var lexer = try Lexer.init(input, testing.allocator);
    defer lexer.deinit();

    const tokens = try lexer.parse_string_to_tokens();

    try testing.expect(tokens.len == 4);

    // Check first token is a keyword "SELECT"
    try testing.expect(tokens[0] == .Keyword);
    switch (tokens[0]) {
        .Keyword => |kw| try testing.expectEqualStrings("SELECT", kw.lexeme),
        else => return error.TestUnexpectedToken,
    }

    // Check second token is an identifier "name"
    try testing.expect(@as(std.meta.Tag(Token), tokens[1]) == .Identifier);
    switch (tokens[1]) {
        .Identifier => |id| try testing.expectEqualStrings("name", id.lexeme),
        else => return error.TestUnexpectedToken,
    }

    // Check third token is a keyword "FROM"
    try testing.expect(@as(std.meta.Tag(Token), tokens[2]) == .Keyword);
    switch (tokens[2]) {
        .Keyword => |kw| try testing.expectEqualStrings("FROM", kw.lexeme),
        else => return error.TestUnexpectedToken,
    }

    try testing.expect(@as(std.meta.Tag(Token), tokens[3]) == .Identifier);
    switch (tokens[3]) {
        .Identifier => |id| try testing.expectEqualStrings("table", id.lexeme),
        else => return error.TestUnexpectedToken,
    }
}

test "Lexer - whitespace handling" {
    const input = "SELECT\t*\nFROM\r\ntable";
    var lexer = try Lexer.init(input, testing.allocator);
    defer lexer.deinit();

    const tokens = try lexer.parse_string_to_tokens();

    try testing.expect(tokens.len == 4);

    try testing.expect(@as(std.meta.Tag(Token), tokens[0]) == .Keyword);
    switch (tokens[0]) {
        .Keyword => |kw| try testing.expectEqualStrings("SELECT", kw.lexeme),
        else => return error.TestUnexpectedToken,
    }
}

// test "Lexer - EOF handling" {
//     const input = ";";
//     var lexer = try Lexer.init(input, testing.allocator);
//     defer lexer.deinit();
//
//     const tokens = try lexer.parse_string_to_tokens();
//
//     try testing.expect(tokens.len == 1);
//     try testing.expect(tokens[0] == .Eof);
// }

test "Lexer - peek_token does not advance position" {
    const input = "SELECT name";
    var lexer = try Lexer.init(input, testing.allocator);
    defer lexer.deinit();

    const original_pos = lexer.pos;

    const peeked_token = try lexer.peek_token();
    try testing.expect(lexer.pos == original_pos);

    switch (peeked_token) {
        .Keyword => |kw| try testing.expectEqualStrings("SELECT", kw.lexeme),
        else => return error.TestUnexpectedToken,
    }

    const actual_token = try lexer.next_token();
    try testing.expect(lexer.pos > original_pos);

    switch (actual_token) {
        .Keyword => |kw| try testing.expectEqualStrings("SELECT", kw.lexeme),
        else => return error.TestUnexpectedToken,
    }
}
