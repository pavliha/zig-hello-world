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

test "multi defer" {
    var x: f32 = 5;
    {
        defer x += 2;
        defer x /= 2;
    }
    try expect(x == 4.5);
}

const FileOpenError = error{ AccessDenied, OutOfMemory, FileNotFound };

const AllocationError = error{OutOfMemory};

test "coerce error from a subset to a superset" {
    const err: FileOpenError = AllocationError.OutOfMemory;
    try expect(err == FileOpenError.OutOfMemory);
}

test "error union" {
    const maybe_error: AllocationError!u16 = 10;
    const no_error = maybe_error catch 0;

    try expect(@TypeOf(no_error) == u16);
    try expect(no_error == 10);
}

fn failingFunction() error{Oops}!void {
    return error.Oops;
}

test "returning error" {
    failingFunction() catch |err| {
        try expect(err == error.Oops);
        return;
    };
}

var problems: u32 = 98;

fn failFnCounter() error{Oops}!void {
    errdefer problems += 1;
    try failingFunction();
}

test "errdefer" {
    failFnCounter() catch |err| {
        try expect(err == error.Oops);
        try expect(problems == 99);
        return;
    };
}

test "switch statement" {
    var x: i8 = 10;

    switch (x) {
        -1...1 => {
            x = -x;
        },

        10, 100 => {
            x = @divExact(x, 10);
        },
        else => {},
    }

    try expect(x == 1);
}

test "switch expression" {
    var x: i8 = 10;

    x = switch (x) {
        -1...1 => -x,
        10, 100 => @divExact(x, 10),
        else => x,
    };
}

test "out of bounds" {
    @setRuntimeSafety(false);
    const a = [3]u8{ 1, 2, 3 };
    // std.debug.print("\n", .{});
    var index: u8 = 255;
    const b = a[index];

    index = index;

    // std.debug.print("Value: {any}\n", .{b});

    try expect(b == 0);
}

fn doupleAllManyPointer(buffer: [*]u8, byte_count: usize) void {
    var i: usize = 0;
    while (i < byte_count) : (i += 1) buffer[i] *= 2;
}

test "many items pointer" {
    var buffer: [100]u8 = [_]u8{1} ** 100;
    const buffer_ptr: *[100]u8 = &buffer;
    const many_items_ptr: [*]u8 = buffer_ptr;
    doupleAllManyPointer(many_items_ptr, buffer.len);
    for (buffer) |byte| try expect(byte == 2);
}

fn total(values: []const u8) usize {
    var sum: usize = 0;
    for (values) |value| sum += value;

    return sum;
}

test "slices" {
    const array = [_]u8{ 1, 2, 3, 4, 5 };
    const slice = array[0..3];

    try expect(total(slice) == 6);
}

test "slices: type of slice" {
    const array = [_]u8{ 1, 2, 3, 4, 5 };
    const slice = array[0..3];

    try expect(@TypeOf(slice) == *const [3]u8);
}

test "slices: to the end" {
    const array = [_]u8{ 1, 2, 3, 4, 5 };
    const slice = array[0..];

    //  std.debug.print("Total, {d}", .{total(slice)});
    try expect(total(slice) == 15);
}

test "enums: enum original value " {
    // const Direction = enum { north, west, south, east };
    const Value = enum(u8) { zero, one, two };

    try expect(@intFromEnum(Value.one) == 1);
}

test "enums: enum overrides" {
    const NumericThreshold = enum(u32) { hundred = 100, thousand = 1000, million = 1000000, next };

    try expect(@intFromEnum(NumericThreshold.hundred) == 100);
    try expect(@intFromEnum(NumericThreshold.next) == 1000001);
}

test "enums with methods" {
    const Suit = enum {
        clubs,
        spades,
        diamonds,
        hearts,
        pub fn isClubs(self: @This()) bool {
            return self == .clubs;
        }
    };

    try expect(Suit.spades.isClubs() == Suit.isClubs(.spades));
}

test "enums: namespaced variables" {
    const Mode = enum {
        var count: u32 = 0;
        on,
        off,
    };

    Mode.count += 1;
    try expect(Mode.count == 1);
}

test "structs: basics" {
    const Position = struct { x: f32, y: f32, z: f32 = 0 };
    const my_position = Position{ .x = 1, .y = 2 };

    try expect(my_position.x == 1);
    try expect(my_position.y == 2);
}

test "structs: automatic dereference" {
    const Stuff = struct {
        x: f32,
        y: f32,
        fn swap(self: @This()) void {
            const tmp: f32 = self.y;
            self.y == self.x;
            self.x = tmp;
        }
    };
    var thing = Stuff{ .x = 10, .y = 20 };

    thing.swap();

    try expect(thing.x == 20);
    try expect(thing.y == 10);
}
