const std = @import("std");
const ledger = @import("ledger.zig");
const rpc = @import("rpc.zig");
const types = @import("types.zig");

/// Demonstration of the working HTTP RPC server
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== HTTP RPC Server Demo ===\n\n", .{});

    // Initialize ledger
    var ledger_manager = try ledger.LedgerManager.init(allocator);
    defer ledger_manager.deinit();

    // Close a few ledgers to have some history
    const empty_txs: []const types.Transaction = &[_]types.Transaction{};
    for (0..5) |_| {
        _ = try ledger_manager.closeLedger(empty_txs);
    }

    std.debug.print("Current ledger sequence: {d}\n\n", .{ledger_manager.getCurrentLedger().sequence});

    // Create RPC server
    var server = rpc.RpcServer.init(allocator, 8080, &ledger_manager);
    defer server.deinit();

    std.debug.print("Starting HTTP server on http://127.0.0.1:8080\n", .{});
    std.debug.print("\nAvailable endpoints:\n", .{});
    std.debug.print("  - GET  /server_info - Server information\n", .{});
    std.debug.print("  - GET  /ledger      - Current ledger info\n", .{});
    std.debug.print("  - GET  /health      - Health check\n", .{});
    std.debug.print("  - POST /            - JSON-RPC endpoint\n", .{});
    std.debug.print("\nTest with:\n", .{});
    std.debug.print("  curl http://127.0.0.1:8080/server_info\n", .{});
    std.debug.print("  curl http://127.0.0.1:8080/ledger\n", .{});
    std.debug.print("  curl http://127.0.0.1:8080/health\n\n", .{});
    std.debug.print("Press Ctrl+C to stop the server.\n\n", .{});

    // Start server (blocks)
    try server.start();
}
