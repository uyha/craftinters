const std = @import("std");
const Scanner = @import("scanner.zig").Scanner;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer allocator.free(args);

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
    const tokens = try scanner.scanTokens();

    std.debug.print("{any}\n", .{tokens});
}
