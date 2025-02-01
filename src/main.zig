// src/main.zig
const std = @import("std");
const net = std.net;
const RtspRequest = @import("rtsp.zig").RtspRequest;
const RtspResponse = @import("rtsp.zig").RtspResponse;

pub const RtspServer = struct {
    allocator: std.mem.Allocator,
    server: net.StreamServer,
    port: u16,
    running: bool,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, port: u16) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .server = net.StreamServer.init(.{}),
            .port = port,
            .running = false,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.stop();
        self.server.deinit();
        self.allocator.destroy(self);
    }

    pub fn start(self: *Self) !void {
        if (self.running) return;

        const address = try net.Address.parseIp("0.0.0.0", self.port);
        try self.server.listen(address);
        self.running = true;

        std.debug.print("RTSP Server listening on port {d}\n", .{self.port});

        while (self.running) {
            const connection = try self.server.accept();
            try self.handleConnection(connection);
        }
    }

    pub fn stop(self: *Self) void {
        if (!self.running) return;
        self.running = false;
        self.server.close();
    }

    fn handleConnection(self: *Self, connection: net.StreamServer.Connection) !void {
        defer connection.stream.close();

        var buffer: [4096]u8 = undefined;
        while (true) {
            // Read request
            const bytes_read = try connection.stream.read(&buffer);
            if (bytes_read == 0) break; // Connection closed

            // Parse RTSP request
            var request = RtspRequest.parse(self.allocator, buffer[0..bytes_read]) catch |err| {
                std.debug.print("Error parsing request: {}\n", .{err});
                continue;
            };
            defer request.deinit();

            // Handle the request
            const response = try self.handleRequest(&request);
            defer response.deinit();

            // Send response
            const response_str = try response.format(self.allocator);
            defer self.allocator.free(response_str);
            _ = try connection.stream.write(response_str);
        }
    }

    fn handleRequest(self: *Self, request: *const RtspRequest) !RtspResponse {
        std.debug.print("Received {s} request for {s}\n", .{ request.method, request.uri });

        return switch (request.method_type) {
            .OPTIONS => self.handleOptions(request),
            .DESCRIBE => self.handleDescribe(request),
            .SETUP => self.handleSetup(request),
            .PLAY => self.handlePlay(request),
            .PAUSE => self.handlePause(request),
            .TEARDOWN => self.handleTeardown(request),
            else => RtspResponse.init(501, "Not Implemented", self.allocator),
        };
    }

    fn handleOptions(self: *Self, request: *const RtspRequest) !RtspResponse {
        _ = request;
        var response = try RtspResponse.init(200, "OK", self.allocator);
        try response.setHeader("Public", "OPTIONS, DESCRIBE, SETUP, PLAY, PAUSE, TEARDOWN");
        return response;
    }

    fn handleDescribe(self: *Self, request: *const RtspRequest) !RtspResponse {
        _ = request;
        var response = try RtspResponse.init(200, "OK", self.allocator);
        const sdp =
            \\v=0
            \\o=- 1234567890 1234567890 IN IP4 127.0.0.1
            \\s=Sample Stream
            \\t=0 0
            \\m=video 0 RTP/AVP 96
            \\a=rtpmap:96 H264/90000
        ;
        try response.setHeader("Content-Type", "application/sdp");
        try response.setHeader("Content-Length", try std.fmt.allocPrint(self.allocator, "{d}", .{sdp.len}));
        response.body = try self.allocator.dupe(u8, sdp);
        return response;
    }

    fn handleSetup(self: *Self, request: *const RtspRequest) !RtspResponse {
        _ = request;
        var response = try RtspResponse.init(200, "OK", self.allocator);
        try response.setHeader("Session", "12345");
        try response.setHeader("Transport", "RTP/AVP;unicast;client_port=8000-8001;server_port=9000-9001");
        return response;
    }

    fn handlePlay(self: *Self, request: *const RtspRequest) !RtspResponse {
        _ = request;
        var response = try RtspResponse.init(200, "OK", self.allocator);
        try response.setHeader("Session", "12345");
        try response.setHeader("Range", "npt=0.000-");
        return response;
    }

    fn handlePause(self: *Self, request: *const RtspRequest) !RtspResponse {
        _ = request;
        var response = try RtspResponse.init(200, "OK", self.allocator);
        try response.setHeader("Session", "12345");
        return response;
    }

    fn handleTeardown(self: *Self, request: *const RtspRequest) !RtspResponse {
        _ = request;
        return RtspResponse.init(200, "OK", self.allocator);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var server = try RtspServer.init(allocator, 8554);
    defer server.deinit();

    try server.start();
}
