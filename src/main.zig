const std = @import("std");

fn fibbonacci(n: u64) u64 {
    if (n == 0 or n == 1) return n;
    return fibbonacci(n - 1) + fibbonacci(n - 2);
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    var buffer: [100]u8 = undefined;

    try stdout.print("Enter number: ", .{});

    if (try stdin.readUntilDelimiterOrEof(buffer[0..], '\n')) |user_input| {
        const number = std.fmt.parseInt(u64, user_input, 10) catch |err| {
            try stdout.print("Error: Invalid number ({s})\n", .{@errorName(err)});
            return;
        };
        try stdout.print("Fibbonacci:  {d}\n", .{fibbonacci(number)});
    }
}
