const std = @import("std");

/// Token represents the different types of tokens in our SQL-like language
pub const Token = union(enum) {
    Symbol: struct { lexeme: []const u8 },
    Keyword: struct { lexeme: []const u8 },
    Identifier: struct { lexeme: []const u8 },
    Eof: struct { lexeme: []const u8 },

    /// Creates a String representation of the token
    pub fn toString(self: Token, allocator: std.mem.Allocator) ![]u8 {
        return switch (self) {
            .Symbol => |s| try std.fmt.allocPrint(allocator, "Symbol({s})", .{s.lexeme}),
            .Keyword => |k| try std.fmt.allocPrint(allocator, "Keyword({s})", .{k.lexeme}),
            .Identifier => |i| try std.fmt.allocPrint(allocator, "Identifier({s})", .{i.lexeme}),
            .Eof => |_| try allocator.dupe(u8, "EOF"),
        };
    }
};

/// Lexer tokenizes input text into SQL-like tokens
pub const Lexer = struct {
    input: []const u8,
    pos: usize = 0,
    tokens: std.ArrayList(Token),
    allocator: std.mem.Allocator,

    /// Initialize a new Lexer with the given input
    pub fn init(input: []const u8, allocator: std.mem.Allocator) Lexer {
        return .{
            .input = input,
            .tokens = std.ArrayList(Token).init(allocator),
            .allocator = allocator,
        };
    }

    /// Free resources used by the Lexer
    pub fn deinit(self: *Lexer) void {
        self.tokens.deinit();
    }

    /// Static map of recognized symbols
    const symbol_set = std.StaticStringMap(u8).initComptime(.{
        .{ "(", 0 },
        .{ ")", 0 },
        .{ "*", 0 },
        .{ ",", 0 },
        .{ ";", 0 },
    });

    /// Check if a character is a recognized symbol
    pub fn isSymbol(c: u8) bool {
        const symbol_str = [_]u8{c};
        return symbol_set.has(&symbol_str);
    }

    /// Static map of recognized keywords (case-sensitive)
    const keywords = std.StaticStringMap(u8).initComptime(.{
        .{ "SELECT", 0 },
        .{ "select", 0 },
        .{ "FROM", 0 },
        .{ "from", 0 },
        .{ "COUNT", 0 },
        .{ "WHERE", 0 },
        .{ "GROUP", 0 },
        .{ "BY", 0 },
        .{ "ORDER", 0 },
        .{ "LIMIT", 0 },
        .{ "CREATE", 0 },
        .{ "TABLE", 0 },
    });

    /// Check if a string is a recognized keyword
    pub fn isKeyword(keyword: []const u8) bool {
        return keywords.has(keyword);
    }

    /// Get the next token from the input
    fn nextToken(self: *Lexer) !Token {
        // Check if we've reached the end of input
        if (self.isAtEnd()) {
            return Token{ .Eof = .{ .lexeme = "" } };
        }

        self.skipWhitespace();
        if (self.isAtEnd()) {
            return Token{ .Eof = .{ .lexeme = "" } };
        }

        const start_pos = self.pos;
        const first_char = self.input[self.pos];

        // Handle symbols separately as they're single characters
        if (Lexer.isSymbol(first_char)) {
            self.pos += 1;
            return Token{ .Symbol = .{ .lexeme = self.input[start_pos..self.pos] } };
        }

        // Extract token until whitespace or symbol
        while (!self.isAtEnd() and !self.isWhitespace(self.input[self.pos]) and !Lexer.isSymbol(self.input[self.pos])) {
            self.pos += 1;
        }

        const token_lexeme = self.input[start_pos..self.pos];

        // Determine token type
        if (Lexer.isKeyword(token_lexeme)) {
            return Token{ .Keyword = .{ .lexeme = token_lexeme } };
        } else {
            return Token{ .Identifier = .{ .lexeme = token_lexeme } };
        }
    }

    /// Peek at the next token without advancing the position
    fn peekToken(self: *Lexer) !Token {
        const saved_pos = self.pos;
        defer self.pos = saved_pos;

        return try self.nextToken();
    }

    /// Check if a character is whitespace
    fn isWhitespace(self: *Lexer, c: u8) bool {
        _ = self; // Silence unused parameter warning
        return c == ' ' or c == '\t' or c == '\n' or c == '\r';
    }

    /// Check if we've reached the end of input
    fn isAtEnd(self: *Lexer) bool {
        return self.pos >= self.input.len;
    }

    /// Skip all whitespace characters
    fn skipWhitespace(self: *Lexer) void {
        while (!self.isAtEnd() and self.isWhitespace(self.input[self.pos])) {
            self.pos += 1;
        }
    }

    /// Parse the entire input string into tokens
    pub fn tokenize(self: *Lexer) ![]const Token {
        // Clear any existing tokens
        self.tokens.clearRetainingCapacity();
        self.pos = 0;

        // Process all tokens
        while (true) {
            const token = try self.nextToken();
            try self.tokens.append(token);

            if (token == .Eof) break;
        }

        return self.tokens.items;
    }
};

// Tests
const testing = std.testing;

test "Lexer - initialization and resources" {
    const input = "SELECT name FROM table";
    var lexer = Lexer.init(input, testing.allocator);
    defer lexer.deinit();

    try testing.expectEqualStrings(input, lexer.input);
    try testing.expect(lexer.pos == 0);
}

test "Lexer - tokenize simple query" {
    const input = "SELECT name FROM table";
    var lexer = Lexer.init(input, testing.allocator);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    try testing.expectEqual(@as(usize, 5), tokens.len); // 4 tokens + EOF

    try testing.expect(tokens[0] == .Keyword);
    switch (tokens[0]) {
        .Keyword => |kw| try testing.expectEqualStrings("SELECT", kw.lexeme),
        else => return error.TestUnexpectedToken,
    }

    try testing.expect(tokens[1] == .Identifier);
    switch (tokens[1]) {
        .Identifier => |id| try testing.expectEqualStrings("name", id.lexeme),
        else => return error.TestUnexpectedToken,
    }

    try testing.expect(tokens[2] == .Keyword);
    switch (tokens[2]) {
        .Keyword => |kw| try testing.expectEqualStrings("FROM", kw.lexeme),
        else => return error.TestUnexpectedToken,
    }

    try testing.expect(tokens[3] == .Identifier);
    switch (tokens[3]) {
        .Identifier => |id| try testing.expectEqualStrings("table", id.lexeme),
        else => return error.TestUnexpectedToken,
    }

    try testing.expect(tokens[4] == .Eof);
}

test "Lexer - whitespace handling" {
    const input = "SELECT\t*\nFROM\r\ntable";
    var lexer = Lexer.init(input, testing.allocator);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();

    try testing.expectEqual(@as(usize, 5), tokens.len); // 4 tokens + EOF

    try testing.expect(tokens[0] == .Keyword);
    switch (tokens[0]) {
        .Keyword => |kw| try testing.expectEqualStrings("SELECT", kw.lexeme),
        else => return error.TestUnexpectedToken,
    }

    try testing.expect(tokens[1] == .Symbol);
    switch (tokens[1]) {
        .Symbol => |s| try testing.expectEqualStrings("*", s.lexeme),
        else => return error.TestUnexpectedToken,
    }
}

test "Lexer - symbol handling" {
    const input = "SELECT * FROM table;";
    var lexer = Lexer.init(input, testing.allocator);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();

    try testing.expectEqual(@as(usize, 6), tokens.len); // 5 tokens + EOF

    try testing.expect(tokens[1] == .Symbol);
    switch (tokens[1]) {
        .Symbol => |s| try testing.expectEqualStrings("*", s.lexeme),
        else => return error.TestUnexpectedToken,
    }

    try testing.expect(tokens[4] == .Symbol);
    switch (tokens[4]) {
        .Symbol => |s| try testing.expectEqualStrings(";", s.lexeme),
        else => return error.TestUnexpectedToken,
    }
}

test "Lexer - EOF handling" {
    const input = ";";
    var lexer = Lexer.init(input, testing.allocator);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();

    try testing.expectEqual(@as(usize, 2), tokens.len);
    try testing.expect(tokens[0] == .Symbol);
    try testing.expect(tokens[1] == .Eof);
}

test "Lexer - peekToken does not advance position" {
    const input = "SELECT name";
    var lexer = Lexer.init(input, testing.allocator);
    defer lexer.deinit();

    const original_pos = lexer.pos;

    const peeked_token = try lexer.peekToken();
    try testing.expectEqual(original_pos, lexer.pos);

    switch (peeked_token) {
        .Keyword => |kw| try testing.expectEqualStrings("SELECT", kw.lexeme),
        else => return error.TestUnexpectedToken,
    }

    const actual_token = try lexer.nextToken();
    try testing.expect(lexer.pos > original_pos);

    switch (actual_token) {
        .Keyword => |kw| try testing.expectEqualStrings("SELECT", kw.lexeme),
        else => return error.TestUnexpectedToken,
    }
}

test "Token - toString" {
    const allocator = testing.allocator;

    const sym_tok = Token{ .Symbol = .{ .lexeme = "*" } };
    const sym_str = try sym_tok.toString(allocator);
    defer allocator.free(sym_str);
    try testing.expectEqualStrings("Symbol(*)", sym_str);

    const kw_tok = Token{ .Keyword = .{ .lexeme = "SELECT" } };
    const kw_str = try kw_tok.toString(allocator);
    defer allocator.free(kw_str);
    try testing.expectEqualStrings("Keyword(SELECT)", kw_str);

    const id_tok = Token{ .Identifier = .{ .lexeme = "name" } };
    const id_str = try id_tok.toString(allocator);
    defer allocator.free(id_str);
    try testing.expectEqualStrings("Identifier(name)", id_str);

    const eof_tok = Token{ .Eof = .{ .lexeme = "" } };
    const eof_str = try eof_tok.toString(allocator);
    defer allocator.free(eof_str);
    try testing.expectEqualStrings("EOF", eof_str);
}
