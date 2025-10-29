const std = @import("std");
const ledger = @import("../src/ledger.zig");
const consensus = @import("../src/consensus.zig");
const transaction = @import("../src/transaction.zig");
const types = @import("../src/types.zig");
const crypto = @import("../src/crypto.zig");
const network = @import("../src/network.zig");
const rpc_methods = @import("../src/rpc_methods.zig");
const database = @import("../src/database.zig");

/// Integration test: Full consensus round with transaction processing
test "full consensus round with payment" {
    const allocator = std.testing.allocator;
    
    // Setup ledger
    var lm = try ledger.LedgerManager.init(allocator);
    defer lm.deinit();
    
    // Setup account state
    var state = ledger.AccountState.init(allocator);
    defer state.deinit();
    
    // Create sender account
    const sender_id = [_]u8{1} ** 20;
    const sender_account = types.AccountRoot{
        .account = sender_id,
        .balance = 1_000_000 * types.XRP,
        .flags = .{},
        .owner_count = 0,
        .previous_txn_id = [_]u8{0} ** 32,
        .previous_txn_lgr_seq = 1,
        .sequence = 1,
    };
    try state.putAccount(sender_account);
    
    // Setup consensus
    var engine = try consensus.ConsensusEngine.init(allocator, &lm);
    defer engine.deinit();
    
    // Add validators
    var i: u8 = 0;
    while (i < 5) : (i += 1) {
        try engine.addValidator(.{
            .public_key = [_]u8{i} ** 33,
            .node_id = [_]u8{i + 10} ** 32,
            .is_trusted = true,
        });
    }
    
    // Create payment transaction
    const receiver_id = [_]u8{2} ** 20;
    var payment = transaction.PaymentTransaction.create(
        sender_id,
        receiver_id,
        types.Amount.fromXRP(100 * types.XRP),
        types.MIN_TX_FEE,
        1,
        [_]u8{0} ** 33,
    );
    
    // Validate transaction
    var processor = try transaction.TransactionProcessor.init(allocator);
    defer processor.deinit();
    
    const validation_result = try processor.validateTransaction(&payment.base, &state);
    try std.testing.expectEqual(types.TransactionResult.tes_success, validation_result);
    
    // Submit transaction
    try processor.submitTransaction(payment.base);
    
    // Start consensus round
    const txs = processor.getPendingTransactions();
    try engine.startRound(txs);
    
    // Simulate validator proposals
    const current_hash = lm.getCurrentLedger().hash;
    for (engine.unl.items) |validator| {
        try engine.processProposal(.{
            .validator_id = validator.node_id,
            .ledger_seq = 2,
            .close_time = std.time.timestamp(),
            .position = .{
                .prior_ledger = current_hash,
                .transactions = &[_]types.TxHash{},
                .close_time = std.time.timestamp(),
            },
            .signature = [_]u8{0} ** 64,
            .timestamp = std.time.timestamp(),
        });
    }
    
    // Run consensus
    var consensus_reached = false;
    var iterations: u32 = 0;
    while (!consensus_reached and iterations < 100) : (iterations += 1) {
        consensus_reached = try engine.runRoundStep();
    }
    
    try std.testing.expect(consensus_reached);
    
    // Finalize
    const result = try engine.finalizeRound();
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(types.LedgerSequence, 2), result.final_ledger_seq);
}

/// Integration test: Network + RPC
test "network message passing" {
    const allocator = std.testing.allocator;
    
    var net = try network.Network.init(allocator, 51235);
    defer net.deinit();
    
    // Create and serialize a ping message
    const ping_msg = network.Message.ping();
    const serialized = try ping_msg.serialize(allocator);
    defer allocator.free(serialized);
    
    // Deserialize
    const deserialized = try network.Message.deserialize(serialized, allocator);
    defer allocator.free(deserialized.payload);
    
    try std.testing.expectEqual(network.MessageType.ping, deserialized.msg_type);
}

/// Integration test: Database persistence
test "database ledger persistence" {
    const allocator = std.testing.allocator;
    
    var db = try database.Database.init(allocator, ".test_integration_db");
    defer db.deinit();
    defer std.fs.cwd().deleteTree(".test_integration_db") catch {};
    
    // Create ledger
    var lm = try ledger.LedgerManager.init(allocator);
    defer lm.deinit();
    
    // Close some ledgers
    const empty_txs: []const types.Transaction = &[_]types.Transaction{};
    for (0..5) |_| {
        _ = try lm.closeLedger(empty_txs);
    }
    
    // Store to database
    try db.putLedger(2, "ledger 2 data");
    try db.putLedger(3, "ledger 3 data");
    
    // Retrieve
    const data2 = try db.getLedger(2);
    try std.testing.expect(data2 != null);
    if (data2) |d| {
        defer allocator.free(d);
        try std.testing.expectEqualStrings("ledger 2 data", d);
    }
}

/// Integration test: RPC methods with real state
test "rpc methods with ledger state" {
    const allocator = std.testing.allocator;
    
    var lm = try ledger.LedgerManager.init(allocator);
    defer lm.deinit();
    
    var state = ledger.AccountState.init(allocator);
    defer state.deinit();
    
    var processor = try transaction.TransactionProcessor.init(allocator);
    defer processor.deinit();
    
    // Add test account
    const account_id = [_]u8{1} ** 20;
    try state.putAccount(.{
        .account = account_id,
        .balance = 5000 * types.XRP,
        .flags = .{},
        .owner_count = 0,
        .previous_txn_id = [_]u8{0} ** 32,
        .previous_txn_lgr_seq = 1,
        .sequence = 1,
    });
    
    var methods = rpc_methods.RpcMethods.init(allocator, &lm, &state, &processor);
    
    // Test account_info
    const account_info_result = try methods.accountInfo(account_id);
    defer allocator.free(account_info_result);
    try std.testing.expect(std.mem.indexOf(u8, account_info_result, "5000000000") != null);
    
    // Test ledger_current
    const ledger_current_result = try methods.ledgerCurrent();
    defer allocator.free(ledger_current_result);
    try std.testing.expect(std.mem.indexOf(u8, ledger_current_result, "ledger_current_index") != null);
}

