const std = @import("std");
const expect = std.testing.expect;

test "variables" {
    const constant: i32 = 5;
    var variable: i32 = 2;

    variable = variable + 1;

    const inferred_constant = @as(i32, variable);
    try expect(constant == 5);
    try expect(variable == 3);
    try expect(inferred_constant == 3);
}

test "arrays" {
    const a = [5]u8{ 1, 2, 3, 4, 5 };
    const b = [_]u8{ 'w', 'o', 'r', 'l', 'd' };

    try expect(a.len == 5);
    try expect(b.len == 5);
}

test "if statements" {
    const a = true;
    var x: u8 = 0;
    if (a) {
        x += 1;
    } else {
        x += 2;
    }
    try expect(x == 1);

    const y = if (a) 1 else 2;

    try expect(y == 1);
}

test "while loops" {
    var i: u8 = 2;
    var sum: u32 = 0;

    while (i < 10) : (i += 1) {
        if (i == 3) break;
        sum += i;
        std.debug.print("Iteration {d}. Sum {d}\n", .{ i, sum });
    }

    std.debug.print("Exec {d}\n", .{sum});

    try expect(i == 3);
}

test "for loops" {
    const string = [_]u8{ 'a', 'b', 'c' };
    std.debug.print("\n", .{});
    for (string, 0..) |character, i| {
        std.debug.print("Character {c}. Position {d}\n", .{ character, i });
    }
}

fn sumNumbers(first: u32, last: u32) u32 {
    return first * last;
}

fn fibbonacci(n: u16) u16 {
    if (n == 0 or n == 1) return n;
    std.debug.print("Position {d}\n", .{n});
    return fibbonacci(n - 1) + fibbonacci(n - 2);
}

test "functions" {
    const val = sumNumbers(1, 2);
    try expect(sumNumbers(1, 2) == 2);
    try expect(@TypeOf(val) == u32);

    try expect(fibbonacci(10) == 55);
}
