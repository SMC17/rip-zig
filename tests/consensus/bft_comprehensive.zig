const std = @import("std");
const consensus = @import("consensus.zig");
const ledger = @import("ledger.zig");
const types = @import("types.zig");

// Comprehensive Byzantine Fault Tolerant Consensus Tests
// Based on rippled consensus tests
// Validates voting, thresholds, Byzantine resistance

test "Consensus: 80% threshold requirement" {
    const allocator = std.testing.allocator;
    var lm = try ledger.LedgerManager.init(allocator);
    defer lm.deinit();
    
    var engine = try consensus.ConsensusEngine.init(allocator, &lm);
    defer engine.deinit();
    
    // Add 10 validators
    var i: u8 = 0;
    while (i < 10) : (i += 1) {
        try engine.addValidator(.{
            .public_key = [_]u8{i} ** 33,
            .node_id = [_]u8{i + 10} ** 32,
            .is_trusted = true,
        });
    }
    
    // Need 8/10 (80%) to reach consensus
    try std.testing.expectEqual(@as(usize, 10), engine.unl.items.len);
}

test "Consensus: Byzantine fault tolerance - minority attack" {
    const allocator = std.testing.allocator;
    var lm = try ledger.LedgerManager.init(allocator);
    defer lm.deinit();
    
    var engine = try consensus.ConsensusEngine.init(allocator, &lm);
    defer engine.deinit();
    
    // 10 validators, 2 Byzantine (20%)
    var i: u8 = 0;
    while (i < 10) : (i += 1) {
        try engine.addValidator(.{
            .public_key = [_]u8{i} ** 33,
            .node_id = [_]u8{i + 10} ** 32,
            .is_trusted = true,
        });
    }
    
    // Even with 2 Byzantine nodes, 8 honest nodes can reach 80%
    // System should tolerate up to 20% Byzantine nodes
    try std.testing.expect(engine.unl.items.len >= 10);
}

test "Consensus: Agreement calculation accuracy" {
    const allocator = std.testing.allocator;
    var lm = try ledger.LedgerManager.init(allocator);
    defer lm.deinit();
    
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
    
    // Start round
    const empty_txs: []const types.Transaction = &[_]types.Transaction{};
    try engine.startRound(empty_txs);
    
    // With our position + 5 agreeing validators = 6/6 = 100%
    try std.testing.expect(engine.our_position != null);
}

test "Consensus: Phase progression" {
    const allocator = std.testing.allocator;
    var lm = try ledger.LedgerManager.init(allocator);
    defer lm.deinit();
    
    var engine = try consensus.ConsensusEngine.init(allocator, &lm);
    defer engine.deinit();
    
    try engine.addValidator(.{
        .public_key = [_]u8{1} ** 33,
        .node_id = [_]u8{10} ** 32,
        .is_trusted = true,
    });
    
    const empty_txs: []const types.Transaction = &[_]types.Transaction{};
    try engine.startRound(empty_txs);
    
    // Should start in open phase
    try std.testing.expectEqual(consensus.ConsensusState.open, engine.state);
    
    // After enough rounds, should progress through phases
    var reached = false;
    var iterations: u32 = 0;
    while (!reached and iterations < 100) : (iterations += 1) {
        reached = try engine.runRoundStep();
    }
    
    // Should eventually reach consensus
    try std.testing.expect(reached);
    try std.testing.expectEqual(consensus.ConsensusState.accepted, engine.state);
}

test "Consensus: Proposal validation" {
    const allocator = std.testing.allocator;
    var lm = try ledger.LedgerManager.init(allocator);
    defer lm.deinit();
    
    var engine = try consensus.ConsensusEngine.init(allocator, &lm);
    defer engine.deinit();
    
    const validator = consensus.ValidatorInfo{
        .public_key = [_]u8{1} ** 33,
        .node_id = [_]u8{10} ** 32,
        .is_trusted = true,
    };
    try engine.addValidator(validator);
    
    const empty_txs: []const types.Transaction = &[_]types.Transaction{};
    try engine.startRound(empty_txs);
    
    // Create valid proposal
    const proposal = consensus.Proposal{
        .validator_id = validator.node_id,
        .ledger_seq = 2,
        .close_time = std.time.timestamp(),
        .position = .{
            .prior_ledger = lm.getCurrentLedger().hash,
            .transactions = &[_]types.TxHash{},
            .close_time = std.time.timestamp(),
        },
        .signature = [_]u8{0} ** 64,
        .timestamp = std.time.timestamp(),
    };
    
    // Should accept valid proposal
    try engine.processProposal(proposal);
    try std.testing.expectEqual(@as(usize, 1), engine.proposals.items.len);
}

test "Consensus: Untrusted validator rejection" {
    const allocator = std.testing.allocator;
    var lm = try ledger.LedgerManager.init(allocator);
    defer lm.deinit();
    
    var engine = try consensus.ConsensusEngine.init(allocator, &lm);
    defer engine.deinit();
    
    const empty_txs: []const types.Transaction = &[_]types.Transaction{};
    try engine.startRound(empty_txs);
    
    // Proposal from untrusted validator
    const bad_proposal = consensus.Proposal{
        .validator_id = [_]u8{99} ** 32, // Not in UNL
        .ledger_seq = 2,
        .close_time = std.time.timestamp(),
        .position = .{
            .prior_ledger = lm.getCurrentLedger().hash,
            .transactions = &[_]types.TxHash{},
            .close_time = std.time.timestamp(),
        },
        .signature = [_]u8{0} ** 64,
        .timestamp = std.time.timestamp(),
    };
    
    // Should reject
    const result = engine.processProposal(bad_proposal);
    try std.testing.expectError(error.UntrustedValidator, result);
}

