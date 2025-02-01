const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;

pub const Error = error{
    InvalidRequest,
};

pub const RtspMethod = enum {
    OPTIONS,
    DESCRIBE,
    SETUP,
    PLAY,
    PAUSE,
    TEARDOWN,
    UNKNOWN,
};

pub const RtspRequest = struct {
    method_type: RtspMethod,
    method: []const u8,
    uri: []const u8,
    version: []const u8,
    headers: StringHashMap([]const u8),
    body: ?[]const u8,
    allocator: Allocator,

    pub fn parse(allocator: Allocator, raw_request: []const u8) !RtspRequest {
        // Split the raw request on CRLF.
        var lines = std.mem.split(u8, raw_request, "\r\n");

        // Parse the request line.
        const request_line = lines.next() orelse return Error.InvalidRequest;
        var parts = std.mem.split(u8, request_line, " ");

        const method = try allocator.dupe(u8, parts.next() orelse return Error.InvalidRequest);
        const uri = try allocator.dupe(u8, parts.next() orelse return Error.InvalidRequest);
        const version = try allocator.dupe(u8, parts.next() orelse return Error.InvalidRequest);

        // Create headers map.
        var headers = StringHashMap([]const u8).init(allocator);

        // Parse headers until we hit an empty line.
        while (true) {
            const line = lines.next() orelse break;
            if (line.len == 0) break;
            if (std.mem.indexOf(u8, line, ": ")) |colon_pos| {
                const key = try allocator.dupe(u8, line[0..colon_pos]);
                const value = try allocator.dupe(u8, line[colon_pos + 2 ..]);
                try headers.put(key, value);
            }
        }

        // Parse body if Content-Length is present.
        var body: ?[]const u8 = null;
        if (headers.get("Content-Length")) |length_str| {
            const length = try std.fmt.parseInt(usize, length_str, 10);
            if (length > 0) {
                const body_buffer = try allocator.alloc(u8, length);
                if (lines.next()) |body_content| {
                    // Copy body_content into our allocated buffer.
                    std.mem.copy(u8, body_buffer, body_content);
                    body = body_buffer;
                }
            }
        }

        return RtspRequest{
            .method_type = methodFromString(method),
            .method = method,
            .uri = uri,
            .version = version,
            .headers = headers,
            .body = body,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RtspRequest) void {
        self.allocator.free(self.method);
        self.allocator.free(self.uri);
        self.allocator.free(self.version);

        var it = self.headers.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();

        if (self.body) |b| {
            self.allocator.free(b);
        }
    }
};

pub const RtspResponse = struct {
    status_code: u16,
    status_text: []const u8,
    headers: StringHashMap([]const u8),
    body: ?[]const u8,
    allocator: Allocator,

    pub fn init(status_code: u16, status_text: []const u8, allocator: Allocator) !RtspResponse {
        const headers = StringHashMap([]const u8).init(allocator);
        return RtspResponse{
            .status_code = status_code,
            .status_text = try allocator.dupe(u8, status_text),
            .headers = headers,
            .body = null,
            .allocator = allocator,
        };
    }

    pub fn setHeader(self: *RtspResponse, name: []const u8, value: []const u8) !void {
        const key = try self.allocator.dupe(u8, name);
        const val = try self.allocator.dupe(u8, value);
        try self.headers.put(key, val);
    }

    // We now use the stored allocator rather than taking one as an argument.
    pub fn format(self: *RtspResponse) ![]const u8 {
        var list = std.ArrayList(u8).init(self.allocator);
        defer list.deinit();

        // Write the status line.
        try std.fmt.format(list.writer(), "RTSP/1.0 {d} {s}\r\n", .{ self.status_code, self.status_text });

        // Write all the headers.
        var it = self.headers.iterator();
        while (it.next()) |entry| {
            try std.fmt.format(list.writer(), "{s}: {s}\r\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }

        // Write a blank line.
        try list.appendSlice("\r\n");

        // Append the body if present.
        if (self.body) |b| {
            try list.appendSlice(b);
        }

        return try list.toOwnedSlice();
    }

    pub fn deinit(self: *RtspResponse) void {
        self.allocator.free(self.status_text);

        var it = self.headers.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();

        if (self.body) |b| {
            self.allocator.free(b);
        }
    }
};

fn methodFromString(method: []const u8) RtspMethod {
    if (std.mem.eql(u8, method, "OPTIONS")) return .OPTIONS;
    if (std.mem.eql(u8, method, "DESCRIBE")) return .DESCRIBE;
    if (std.mem.eql(u8, method, "SETUP")) return .SETUP;
    if (std.mem.eql(u8, method, "PLAY")) return .PLAY;
    if (std.mem.eql(u8, method, "PAUSE")) return .PAUSE;
    if (std.mem.eql(u8, method, "TEARDOWN")) return .TEARDOWN;
    return .UNKNOWN;
}

test "parse RTSP request with body" {
    const request_str =
        "ANNOUNCE rtsp://example.com/test RTSP/1.0\r\n" ++
        "CSeq: 2\r\n" ++
        "Content-Type: application/sdp\r\n" ++
        "Content-Length: 26\r\n" ++
        "\r\n" ++
        "v=0\no=- 12345 12345 IN IP4";

    var request = try RtspRequest.parse(testing.allocator, request_str);
    defer request.deinit();

    try testing.expectEqual(request.method_type, RtspMethod.UNKNOWN);
    try testing.expectEqualStrings("ANNOUNCE", request.method);
    if (request.body) |b| {
        try testing.expectEqualStrings("v=0\no=- 12345 12345 IN IP4", b);
    }
}

test "create and format RTSP response" {
    var response = try RtspResponse.init(200, "OK", testing.allocator);
    defer response.deinit();

    try response.setHeader("CSeq", "1");
    try response.setHeader("Server", "TestServer");

    const formatted = try response.format();
    defer testing.allocator.free(formatted);

    const expected_response =
        "RTSP/1.0 200 OK\r\n" ++
        "CSeq: 1\r\n" ++
        "Server: TestServer\r\n" ++
        "\r\n";

    try testing.expectEqualStrings(expected_response, formatted);
}
