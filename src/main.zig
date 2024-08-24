const std = @import("std");
const expr = @import("expr.zig");

const Expr = expr.Expr;
const Literal = expr.Literal;

const Token = @import("token.zig").Token;
const token = @import("token.zig").token;

const Scanner = @import("scanner.zig").Scanner;
const Parser = @import("parser.zig").Parser;

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(general_purpose_allocator.deinit() == .ok);

    const allocator = general_purpose_allocator.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 2) {
        _ = try std.io.getStdErr().write("Usage: jlox [script]");
    } else if (args.len == 2) {
        try runFile(allocator, args[1]);
    } else {
        try runPrompt(allocator);
    }
}

fn runFile(allocator: std.mem.Allocator, path: []const u8) !void {
    const file = try std.fs.openFileAbsolute(path, .{ .mode = .read_only });
    const metadata = try file.metadata();
    try run(allocator, try file.readToEndAlloc(allocator, metadata.size()));
}

fn runPrompt(
    allocator: std.mem.Allocator,
) !void {
    const reader = std.io.getStdIn().reader();
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    while (true) {
        _ = try std.io.getStdOut().write("> ");
        reader.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| switch (err) {
            error.EndOfStream => {
                _ = try std.io.getStdOut().write("\nBye\n");
                return;
            },
            else => return err,
        };
        try run(allocator, buffer.items);

        try buffer.resize(0);
    }
}

fn run(allocator: std.mem.Allocator, bytes: []const u8) !void {
    var scanner = Scanner.init(allocator, bytes);
    defer scanner.deinit();

    const tokens = try scanner.scanTokens();

    var parser = Parser.init(tokens.items, allocator);
    defer parser.deinit();

    const expression = try parser.parse();
    try expr.print(std.io.getStdOut().writer(), expression);
}
