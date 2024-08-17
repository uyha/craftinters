const std = @import("std");

pub const TokenType = enum {
    left_paren,
    right_paren,
    left_brace,
    right_brace,
    comma,
    dot,
    minus,
    plus,
    semicolon,
    slash,
    star,

    // one or two character tokens.
    bang,
    bang_equal,
    equal,
    equal_equal,
    greater,
    greater_equal,
    less,
    less_equal,

    // literals.
    identifier,
    string,
    number,

    // keywords.
    @"and",
    class,
    @"else",
    false,
    fun,
    @"for",
    @"if",
    nil,
    @"or",
    print,
    @"return",
    super,
    this,
    true,
    @"var",
    @"while",

    eof,
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    literal: ?[]const u8,
    line: u32,

    pub fn format(self: Token, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        if (self.literal) |literal| {
            return std.fmt.format(writer, "{any} {s} {s}", .{
                self.type,
                self.lexeme,
                literal,
            });
        }
        return std.fmt.format(writer, "{any} {s}", .{ self.type, self.lexeme });
    }
};

pub fn token(token_type: TokenType, lexeme: []const u8, literal: ?[]const u8, line: u32) Token {
    return .{
        .type = token_type,
        .lexeme = lexeme,
        .literal = literal,
        .line = line,
    };
}
