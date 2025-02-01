// src/tests.zig
const std = @import("std");
const testing = std.testing;
const RtspRequest = @import("rtsp.zig").RtspRequest;
const RtspResponse = @import("rtsp.zig").RtspResponse;
const RtspMethod = @import("rtsp.zig").RtspMethod;
const RtspServer = @import("main.zig").RtspServer;

test "parse basic RTSP request" {
    const request_str =
        \\OPTIONS rtsp://example.com/test RTSP/1.0\r
        \\CSeq: 1\r
        \\User-Agent: TestClient\r
        \\
        \\
    ;

    var request = try RtspRequest.parse(testing.allocator, request_str);
    defer request.deinit();

    try testing.expectEqual(RtspMethod.OPTIONS, request.method_type);
    try testing.expectEqualStrings("OPTIONS", request.method);
    try testing.expectEqualStrings("rtsp://example.com/test", request.uri);
    try testing.expectEqualStrings("RTSP/1.0", request.version);
    try testing.expectEqualStrings("1", request.headers.get("CSeq").?);
    try testing.expectEqualStrings("TestClient", request.headers.get("User-Agent").?);
}

test "parse RTSP request with body" {
    const request_str =
        \\ANNOUNCE rtsp://example.com/test RTSP/1.0\r
        \\CSeq: 2\r
        \\Content-Type: application/sdp\r
        \\Content-Length: 26\r
        \\
        \\v=0
        \\o=- 12345 12345 IN IP4
    ;

    var request = try RtspRequest.parse(testing.allocator, request_str);
    defer request.deinit();

    try testing.expect(request.body != null);
    if (request.body) |body| {
        try testing.expectEqualStrings("v=0\no=- 12345 12345 IN IP4", body);
    }
}

test "create and format RTSP response" {
    var response = try RtspResponse.init(200, "OK", testing.allocator);
    defer response.deinit();

    try response.setHeader("CSeq", "1");
    try response.setHeader("Server", "TestServer");

    const formatted = try response.format(testing.allocator);
    defer testing.allocator.free(formatted);

    const expected_response =
        \\RTSP/1.0 200 OK\r
        \\CSeq: 1\r
        \\Server: TestServer\r
        \\
        \\
    ;

    try testing.expectEqualStrings(expected_response, formatted);
}

test "RTSP server initialization" {
    var server = try RtspServer.init(testing.allocator, 8554);
    defer server.deinit();

    try testing.expect(!server.running);
    try testing.expectEqual(@as(u16, 8554), server.port);
}

test "RTSP response - DESCRIBE method" {
    var server = try RtspServer.init(testing.allocator, 8554);
    defer server.deinit();

    const request_str =
        \\DESCRIBE rtsp://example.com/test RTSP/1.0\r
        \\CSeq: 3\r
        \\User-Agent: TestClient\r
        \\
        \\
    ;

    var request = try RtspRequest.parse(testing.allocator, request_str);
    defer request.deinit();

    var response = try server.handleRequest(&request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status_code);
    try testing.expectEqualStrings("OK", response.status_text);

    const content_type = response.headers.get("Content-Type");
    try testing.expect(content_type != null);
    if (content_type) |ct| {
        try testing.expectEqualStrings("application/sdp", ct);
    }
}

test "RTSP response - OPTIONS method" {
    var server = try RtspServer.init(testing.allocator, 8554);
    defer server.deinit();

    const request_str =
        \\OPTIONS rtsp://example.com/test RTSP/1.0\r
        \\CSeq: 4\r
        \\
        \\
    ;

    var request = try RtspRequest.parse(testing.allocator, request_str);
    defer request.deinit();

    var response = try server.handleRequest(&request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status_code);

    const public_header = response.headers.get("Public");
    try testing.expect(public_header != null);
    if (public_header) |ph| {
        try testing.expectEqualStrings("OPTIONS, DESCRIBE, SETUP, PLAY, PAUSE, TEARDOWN", ph);
    }
}

test "RTSP response - SETUP method" {
    var server = try RtspServer.init(testing.allocator, 8554);
    defer server.deinit();

    const request_str =
        \\SETUP rtsp://example.com/test RTSP/1.0\r
        \\CSeq: 5\r
        \\Transport: RTP/AVP;unicast;client_port=8000-8001\r
        \\
        \\
    ;

    var request = try RtspRequest.parse(testing.allocator, request_str);
    defer request.deinit();

    var response = try server.handleRequest(&request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status_code);

    const session = response.headers.get("Session");
    try testing.expect(session != null);

    const transport = response.headers.get("Transport");
    try testing.expect(transport != null);
    if (transport) |t| {
        try testing.expect(std.mem.indexOf(u8, t, "server_port=") != null);
    }
}

test "handle invalid RTSP request" {
    const invalid_request = "NOT_A_VALID_REQUEST\r\n";

    testing.expectError(error.InvalidRequest, RtspRequest.parse(testing.allocator, invalid_request));
}

// Mock network client for testing server connections
const MockClient = struct {
    allocator: std.mem.Allocator,
    received_data: std.ArrayList(u8),

    fn init(allocator: std.mem.Allocator) !*MockClient {
        const client = try allocator.create(MockClient);
        client.* = .{
            .allocator = allocator,
            .received_data = std.ArrayList(u8).init(allocator),
        };
        return client;
    }

    fn deinit(self: *MockClient) void {
        self.received_data.deinit();
        self.allocator.destroy(self);
    }

    fn sendRequest(self: *MockClient, server: *RtspServer, request: []const u8) !void {
        _ = self;
        _ = server;
        _ = request;
        // In a real implementation, this would send data to the server
        // For now, we'll just simulate the server's response generation
    }
};

test "mock client-server interaction" {
    var client = try MockClient.init(testing.allocator);
    defer client.deinit();

    var server = try RtspServer.init(testing.allocator, 8554);
    defer server.deinit();

    // This is a basic test - in a real implementation, you'd want to test
    // actual network communication
    const request_str =
        \\OPTIONS rtsp://example.com/test RTSP/1.0\r
        \\CSeq: 6\r
        \\
        \\
    ;

    try client.sendRequest(server, request_str);
    // In a real implementation, you'd verify the response here
}
