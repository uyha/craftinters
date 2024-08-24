const std = @import("std");
const Allocator = std.mem.Allocator;

const log = @import("log.zig");

const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;

const Expr = @import("expr.zig").Expr;
const ExprAllocator = @import("expr.zig").ExprAllocator;

pub const Parser = struct {
    pub const Error = ExprAllocator.Error;
    pub const SyntaxErrorTrace = struct {
        stacktrace: ?std.builtin.StackTrace,
    };

    tokens: []const Token,
    current: u32 = 0,
    allocator: ExprAllocator,
    traces: std.ArrayList(SyntaxErrorTrace),

    pub fn init(tokens: []const Token, allocator: Allocator) Parser {
        return .{
            .tokens = tokens,
            .allocator = ExprAllocator.init(allocator),
            .traces = std.ArrayList(SyntaxErrorTrace).init(allocator),
        };
    }
    pub fn deinit(self: *Parser) void {
        self.allocator.deinit();
    }

    pub fn parse(self: *Parser) Error!*Expr {
        return self.expression();
    }

    fn expression(self: *Parser) Error!*Expr {
        return self.equality();
    }

    fn equality(self: *Parser) Error!*Expr {
        var expr = try self.comparison();

        while (self.match(.{ .bang_equal, .equal_equal })) {
            const operator = self.previous();
            const right = try self.comparison();
            expr = try self.allocator.binary(expr, operator, right);
        }

        return expr;
    }

    fn comparison(self: *Parser) Error!*Expr {
        var expr = try self.term();

        while (self.match(.{ .greater, .greater_equal, .less, .less_equal })) {
            const operator = self.previous();
            const right = try self.term();
            expr = try self.allocator.binary(expr, operator, right);
        }

        return expr;
    }

    fn term(self: *Parser) Error!*Expr {
        var expr = try self.factor();

        while (self.match(.{ .minus, .plus })) {
            const operator = self.previous();
            const right = try self.factor();
            expr = try self.allocator.binary(expr, operator, right);
        }

        return expr;
    }

    fn factor(self: *Parser) Error!*Expr {
        var expr = try self.unary();

        while (self.match(.{ .slash, .star })) {
            const operator = self.previous();
            const right = try self.unary();
            expr = try self.allocator.binary(expr, operator, right);
        }

        return expr;
    }

    fn unary(self: *Parser) Error!*Expr {
        if (self.match(.{ TokenType.bang, TokenType.minus })) {
            const operator = self.previous();
            const right = try self.unary();
            return try self.allocator.unary(operator, right);
        }

        return self.primary();
    }

    fn primary(self: *Parser) Error!*Expr {
        if (self.match(.false)) return self.allocator.literal(.{ .bool = false });
        if (self.match(.true)) return self.allocator.literal(.{ .bool = true });
        if (self.match(.nil)) return self.allocator.literal(.{ .nil = {} });

        if (self.match(.number)) {
            return self.allocator.literal(.{
                .number = self.previous().literal orelse @panic("No way a token without literal can be qualified as a number"),
            });
        }
        if (self.match(.string)) {
            return self.allocator.literal(.{ .string = self.previous().literal orelse @panic("No way a token without literal can be qualified as a string") });
        }

        if (self.match(.left_paren)) {
            const expr = try self.expression();
            _ = try self.consume(.right_paren, "Expect ')' after expression");
            return self.allocator.grouping(expr);
        }

        @panic("Expect expression");
    }

    fn synchronize(self: *Parser) void {
        _ = self.advance();

        while (!self.isAtEnd()) {
            if (self.previous().type == .semicolon) return;

            switch (self.peek().type) {
                .class, .fun, .@"var", .@"for", .@"if", .@"while", .print, .@"return" => return,
                else => _ = self.advance(),
            }
        }
    }

    fn match(self: *Parser, args: anytype) bool {
        switch (comptime @typeInfo(@TypeOf(args))) {
            .Struct => inline for (args) |token_type| {
                if (self.check(@as(TokenType, token_type))) {
                    _ = self.advance();
                    return true;
                }
            },
            .EnumLiteral => {
                if (self.check(@as(TokenType, args))) {
                    _ = self.advance();
                    return true;
                }
            },
            else => @compileError("args must be a tuple of TokenType or Token"),
        }

        return false;
    }

    fn check(self: *const Parser, token_type: TokenType) bool {
        if (self.isAtEnd()) return false;
        return self.peek().type == token_type;
    }

    fn advance(self: *Parser) Token {
        if (!self.isAtEnd()) self.current += 1;
        return self.previous();
    }

    fn isAtEnd(self: *const Parser) bool {
        return self.peek().type == .eof;
    }

    fn peek(self: *const Parser) Token {
        return self.tokens[self.current];
    }
    fn previous(self: *const Parser) Token {
        return self.tokens[self.current - 1];
    }

    fn consume(self: *Parser, token_type: TokenType, message: []const u8) Error!Token {
        if (self.check(token_type)) return self.advance();

        @panic(message);
    }
};
