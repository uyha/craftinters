const std = @import("std");

const log = @import("log.zig");
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;

pub const Scanner = struct {
    source: []const u8,
    tokens: std.ArrayList(Token),
    start: u32 = 0,
    current: u32 = 0,
    line: u32 = 1,

    const keywords = .{
        .{ "and", TokenType.@"and" },
        .{ "class", TokenType.class },
        .{ "else", TokenType.@"else" },
        .{ "false", TokenType.false },
        .{ "for", TokenType.@"for" },
        .{ "fun", TokenType.fun },
        .{ "if", TokenType.@"if" },
        .{ "nil", TokenType.nil },
        .{ "or", TokenType.@"or" },
        .{ "print", TokenType.print },
        .{ "return", TokenType.@"return" },
        .{ "super", TokenType.super },
        .{ "this", TokenType.this },
        .{ "true", TokenType.true },
        .{ "var", TokenType.@"var" },
        .{ "while", TokenType.@"while" },
    };

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Scanner {
        return .{
            .source = source,
            .tokens = std.ArrayList(Token).init(allocator),
        };
    }

    pub fn deinit(self: Scanner) void {
        self.tokens.deinit();
    }

    pub fn scanTokens(self: *Scanner) !std.ArrayList(Token) {
        while (!self.isAtEnd()) {
            self.start = self.current;
            try self.scanToken();
        }

        try self.tokens.append(.{
            .type = .eof,
            .lexeme = "",
            .literal = null,
            .line = self.line,
        });
        return self.tokens;
    }

    fn isAtEnd(self: Scanner) bool {
        return self.current >= self.source.len;
    }

    fn scanToken(self: *Scanner) !void {
        const c = self.advance();
        try switch (c) {
            '(' => self.addToken(.left_paren),
            ')' => self.addToken(.right_paren),
            '{' => self.addToken(.left_brace),
            '}' => self.addToken(.right_brace),
            ',' => self.addToken(.comma),
            '.' => self.addToken(.dot),
            '-' => self.addToken(.minus),
            '+' => self.addToken(.plus),
            ';' => self.addToken(.semicolon),
            '*' => self.addToken(.star),
            '!' => self.addToken(if (self.match('=')) .bang_equal else .bang),
            '=' => self.addToken(if (self.match('=')) .equal_equal else .equal),
            '<' => self.addToken(if (self.match('=')) .less_equal else .less),
            '>' => self.addToken(if (self.match('=')) .greater_equal else .greater),
            '/' => {
                if (self.match('/')) {
                    while (self.peek() != '\n' and !self.isAtEnd()) {
                        _ = self.advance();
                    }
                }
                if (self.match('*')) {
                    self.blockComment();
                } else {
                    try self.addToken(.slash);
                }
            },
            ' ', '\r', '\t' => {},
            '\n' => self.line += 1,
            '"' => self.string(),
            else => {
                if (isDigit(c)) {
                    try self.number();
                } else if (isAlpha(c)) {
                    try self.identifier();
                } else {
                    try log.@"error"(self.line, "Unexpected character");
                }
            },
        };
    }

    fn advance(self: *Scanner) u8 {
        const c = self.source[self.current];
        self.current += 1;
        return c;
    }
    fn addToken(self: *Scanner, @"type": TokenType) !void {
        return self.addTokenLiteral(@"type", null);
    }
    fn addTokenLiteral(self: *Scanner, @"type": TokenType, literal: ?[]const u8) !void {
        try self.tokens.append(.{
            .type = @"type",
            .lexeme = self.source[self.start..self.current],
            .literal = literal,
            .line = self.line,
        });
    }
    fn match(self: *Scanner, expected: u8) bool {
        if (self.isAtEnd()) {
            return false;
        }
        if (self.source[self.current] != expected) return false;

        self.current += 1;
        return true;
    }
    fn peek(self: *const Scanner) u8 {
        return if (!self.isAtEnd()) self.source[self.current] else 0;
    }
    fn peekNext(self: *const Scanner) u8 {
        return if (self.source.len <= self.current + 1) 0 else self.source[self.current + 1];
    }
    fn string(self: *Scanner) !void {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') {
                self.line += 1;
            }
            _ = self.advance();
        }

        if (self.isAtEnd()) {
            try log.@"error"(self.line, "Unterminated string..");
            return;
        }

        // The closing "
        _ = self.advance();
        return self.addTokenLiteral(
            .string,
            self.source[self.start + 1 .. self.current - 1],
        );
    }
    fn number(self: *Scanner) !void {
        while (isDigit(self.peek())) {
            _ = self.advance();
        }

        if (self.peek() == '.' and isDigit(self.peekNext())) {
            _ = self.advance();

            while (isDigit(self.peek())) {
                _ = self.advance();
            }
        }

        return self.addTokenLiteral(.number, self.source[self.start..self.current]);
    }
    fn identifier(self: *Scanner) !void {
        while (isAlphaNumeric(self.peek())) {
            _ = self.advance();
        }

        const text = self.source[self.start..self.current];
        inline for (keywords) |keyword| {
            if (std.mem.eql(u8, text, keyword[0])) {
                return self.addToken(keyword[1]);
            }
        }

        return self.addToken(.identifier);
    }

    fn blockComment(self: *Scanner) void {
        while (true) {
            const c = self.advance();
            switch (c) {
                '*' => if (self.match('/')) return,
                '/' => if (self.match('*')) self.blockComment(),
                else => {},
            }
        }
    }
    fn isDigit(c: u8) bool {
        return '0' <= c and c <= '9';
    }
    fn isAlpha(c: u8) bool {
        return ('a' <= c and c <= 'z') or ('A' <= c and c <= 'Z') or c == '_';
    }
    fn isAlphaNumeric(c: u8) bool {
        return isDigit(c) or isAlpha(c);
    }
};
