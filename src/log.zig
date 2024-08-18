const std = @import("std");

fn @"error"(line: u32, message: []const u8) !void {
    return report(line, "", message);
}

fn report(line: u32, where: []const u8, message: []const u8) !void {
    try std.fmt.format(std.io.getStdErr().writer(), "[line {}] Error {s}: {s}\n", .{
        line,
        where,
        message,
    });
}
