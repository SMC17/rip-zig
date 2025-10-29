const std = @import("std");
const consensus = @import("consensus.zig");
const ledger = @import("ledger.zig");
const types = @import("types.zig");
const crypto = @import("crypto.zig");
const network = @import("network.zig");
const transaction = @import("transaction.zig");
const rpc = @import("rpc.zig");
const storage = @import("storage.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("XRP Ledger Daemon (Zig Implementation)\n", .{});
    std.debug.print("======================================\n\n", .{});

    // Initialize core components
    var node = try Node.init(allocator);
    defer node.deinit();

    std.debug.print("Node initialized successfully\n", .{});
    std.debug.print("Node ID: {any}\n", .{node.id[0..8]});

    // Start the node
    try node.run();
}

/// Main node structure that coordinates all components
pub const Node = struct {
    allocator: std.mem.Allocator,
    id: [32]u8,
    ledger_manager: ledger.LedgerManager,
    consensus_engine: consensus.ConsensusEngine,
    tx_processor: transaction.TransactionProcessor,
    rpc_server: rpc.RpcServer,
    storage: storage.Storage,
    
    pub fn init(allocator: std.mem.Allocator) !Node {
        // Generate random node ID
        var id: [32]u8 = undefined;
        std.crypto.random.bytes(&id);

        var ledger_manager = try ledger.LedgerManager.init(allocator);
        const node_storage = try storage.Storage.init(allocator, "data");

        const consensus_engine = try consensus.ConsensusEngine.init(allocator, &ledger_manager);
        
        return Node{
            .allocator = allocator,
            .id = id,
            .ledger_manager = ledger_manager,
            .consensus_engine = consensus_engine,
            .tx_processor = try transaction.TransactionProcessor.init(allocator),
            .rpc_server = rpc.RpcServer.init(allocator, 5005, &ledger_manager),
            .storage = node_storage,
        };
    }

    pub fn deinit(self: *Node) void {
        self.ledger_manager.deinit();
        self.consensus_engine.deinit();
        self.tx_processor.deinit();
        self.rpc_server.deinit();
        self.storage.deinit();
    }

    pub fn run(self: *Node) !void {
        std.debug.print("\nStarting XRP Ledger daemon...\n", .{});
        std.debug.print("Consensus algorithm: XRP Ledger Consensus Protocol\n", .{});
        std.debug.print("Network: Testnet (for development)\n\n", .{});

        // TODO: Start network listener
        // TODO: Connect to peer network
        // TODO: Start consensus rounds
        // TODO: Start RPC server

        std.debug.print("Node is running. Press Ctrl+C to stop.\n", .{});
        
        // For now, just keep the process alive
        // In production, this would be the main event loop
        _ = self;
    }
};

test "basic node initialization" {
    const allocator = std.testing.allocator;
    var node = try Node.init(allocator);
    defer node.deinit();
    
    try std.testing.expect(node.id.len == 32);
}

