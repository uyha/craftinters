const Token = @import("Token.zig").Token;

const Expr = union(enum) {
    binary: struct { left: *Expr, operator: Token, right: *Expr },
    grouping: struct { expression: *Expr },
    literal: struct { value: *anyopaque },
    unary: struct { operator: Token, right: *Expr },
};
