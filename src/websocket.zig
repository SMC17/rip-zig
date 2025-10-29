const std = @import("std");
const types = @import("types.zig");
const ledger = @import("ledger.zig");

/// WebSocket server for real-time subscriptions
pub const WebSocketServer = struct {
    allocator: std.mem.Allocator,
    port: u16,
    clients: std.ArrayList(WebSocketClient),
    server: ?std.net.Server,
    running: std.atomic.Value(bool),
    ledger_manager: *ledger.LedgerManager,
    
    pub fn init(allocator: std.mem.Allocator, port: u16, ledger_manager: *ledger.LedgerManager) !WebSocketServer {
        return WebSocketServer{
            .allocator = allocator,
            .port = port,
            .clients = try std.ArrayList(WebSocketClient).initCapacity(allocator, 0),
            .server = null,
            .running = std.atomic.Value(bool).init(false),
            .ledger_manager = ledger_manager,
        };
    }
    
    pub fn deinit(self: *WebSocketServer) void {
        self.stop();
        for (self.clients.items) |*client| {
            client.deinit();
        }
        self.clients.deinit(self.allocator);
    }
    
    /// Start WebSocket server
    pub fn start(self: *WebSocketServer) !void {
        const address = try std.net.Address.parseIp("127.0.0.1", self.port);
        var server = try address.listen(.{
            .reuse_address = true,
            .reuse_port = true,
        });
        
        self.server = server;
        self.running.store(true, .seq_cst);
        
        std.debug.print("WebSocket server listening on ws://127.0.0.1:{d}\n", .{self.port});
        
        while (self.running.load(.seq_cst)) {
            var connection = server.accept() catch |err| switch (err) {
                error.ConnectionResetByPeer => continue,
                error.ConnectionAborted => continue,
                else => return err,
            };
            
            // Handle WebSocket upgrade
            self.handleConnection(connection.stream) catch |err| {
                std.debug.print("WebSocket connection error: {}\n", .{err});
                connection.stream.close();
            };
        }
    }
    
    /// Stop WebSocket server
    pub fn stop(self: *WebSocketServer) void {
        self.running.store(false, .seq_cst);
        if (self.server) |*server| {
            server.deinit();
            self.server = null;
        }
    }
    
    /// Handle a new connection
    fn handleConnection(self: *WebSocketServer, stream: std.net.Stream) !void {
        var buffer: [4096]u8 = undefined;
        const bytes_read = try stream.read(&buffer);
        
        if (bytes_read == 0) return;
        
        // Check for WebSocket upgrade request
        if (std.mem.indexOf(u8, buffer[0..bytes_read], "Upgrade: websocket")) |_| {
            try self.performHandshake(stream, buffer[0..bytes_read]);
            
            // Add client
            const client = WebSocketClient{
                .stream = stream,
                .subscriptions = std.ArrayList(Subscription).init(self.allocator),
                .allocator = self.allocator,
            };
            try self.clients.append(self.allocator, client);
        }
    }
    
    /// Perform WebSocket handshake
    fn performHandshake(self: *WebSocketServer, stream: std.net.Stream, request: []const u8) !void {
        _ = self;
        // Extract WebSocket key
        const key_start = std.mem.indexOf(u8, request, "Sec-WebSocket-Key: ") orelse return error.MissingKey;
        const key_line = request[key_start + 19 ..];
        const key_end = std.mem.indexOf(u8, key_line, "\r\n") orelse return error.InvalidKey;
        const key = key_line[0..key_end];
        
        // Generate accept key (simplified - should use SHA-1 hash)
        const magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
        _ = magic;
        _ = key;
        
        // Send upgrade response
        const response =
            \\HTTP/1.1 101 Switching Protocols
            \\Upgrade: websocket
            \\Connection: Upgrade
            \\Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
            \\
            \\
        ;
        
        _ = try stream.write(response);
    }
    
    /// Broadcast ledger close to all subscribed clients
    pub fn broadcastLedgerClose(self: *WebSocketServer, ledger_seq: types.LedgerSequence) !void {
        const message = try std.fmt.allocPrint(self.allocator,
            \\{{
            \\  "type": "ledgerClosed",
            \\  "ledger_index": {d},
            \\  "ledger_hash": "placeholder"
            \\}}
        , .{ledger_seq});
        defer self.allocator.free(message);
        
        for (self.clients.items) |*client| {
            for (client.subscriptions.items) |sub| {
                if (sub == .ledger) {
                    client.send(message) catch |err| {
                        std.debug.print("Failed to send to client: {}\n", .{err});
                    };
                }
            }
        }
    }
};

/// WebSocket client connection
pub const WebSocketClient = struct {
    stream: std.net.Stream,
    subscriptions: std.ArrayList(Subscription),
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *WebSocketClient) void {
        self.stream.close();
        self.subscriptions.deinit(self.allocator);
    }
    
    /// Send message to client
    pub fn send(self: *WebSocketClient, message: []const u8) !void {
        // WebSocket frame format (simplified)
        // In production, would implement full WebSocket framing
        _ = try self.stream.write(message);
    }
    
    /// Subscribe to a stream
    pub fn subscribe(self: *WebSocketClient, sub: Subscription) !void {
        try self.subscriptions.append(self.allocator, sub);
    }
};

/// Subscription types
pub const Subscription = enum {
    ledger,
    transactions,
    validations,
    manifests,
    peer_status,
    consensus,
    server,
};

test "websocket initialization" {
    const allocator = std.testing.allocator;
    var lm = try ledger.LedgerManager.init(allocator);
    defer lm.deinit();
    
    var ws = try WebSocketServer.init(allocator, 6006, &lm);
    defer ws.deinit();
    
    try std.testing.expectEqual(@as(u16, 6006), ws.port);
    try std.testing.expectEqual(@as(usize, 0), ws.clients.items.len);
}

