const std = @import("std");
const ledger = @import("../src/ledger.zig");
const consensus = @import("../src/consensus.zig");
const rpc_methods = @import("../src/rpc_methods.zig");
const transaction = @import("../src/transaction.zig");
const types = @import("../src/types.zig");
const crypto = @import("../src/crypto.zig");
const canonical = @import("../src/canonical.zig");

test "WEEK 3 DAY 17: Hash calculation performance" {
    const allocator = std.testing.allocator;

    std.debug.print("\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("  WEEK 3 DAY 17: HASH CALCULATION BENCHMARK\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});

    const iterations = 10000;
    const test_data = "This is test data for hash calculation performance benchmark";

    // Warmup
    _ = crypto.Hash.sha512Half(test_data);

    // Benchmark SHA-512 Half
    const start = std.time.nanoTimestamp();
    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        _ = crypto.Hash.sha512Half(test_data);
    }
    const end = std.time.nanoTimestamp();
    const elapsed_ns = @as(f64, @floatFromInt(end - start));
    const elapsed_us = elapsed_ns / 1000.0;
    const elapsed_ms = elapsed_us / 1000.0;
    const ops_per_sec = (@as(f64, @floatFromInt(iterations)) / elapsed_ns) * 1_000_000_000.0;
    const avg_us = elapsed_us / @as(f64, @floatFromInt(iterations));

    std.debug.print("\n", .{});
    std.debug.print("SHA-512 Half Performance:\n", .{});
    std.debug.print("  Iterations: {d}\n", .{iterations});
    std.debug.print("  Total time: {d:.3} ms\n", .{elapsed_ms});
    std.debug.print("  Average: {d:.3} μs per hash\n", .{avg_us});
    std.debug.print("  Throughput: {d:.0} hashes/sec\n", .{ops_per_sec});

    std.debug.print("\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
}

test "WEEK 3 DAY 17: Canonical serialization performance" {
    const allocator = std.testing.allocator;

    std.debug.print("\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("  WEEK 3 DAY 17: CANONICAL SERIALIZATION BENCHMARK\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});

    const iterations = 10000;

    // Warmup
    var serializer = canonical.CanonicalSerializer.init(allocator);
    defer serializer.deinit();
    serializer.addUInt16(.{ .transaction_type = 1 }, 1);
    serializer.addUInt32(.{ .fee = 2 }, 1000);
    serializer.addAccountID(.{ .account = 3 }, [_]u8{1} ** 20);
    _ = try serializer.finish();

    // Benchmark
    const start = std.time.nanoTimestamp();
    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        var ser = canonical.CanonicalSerializer.init(allocator);
        defer ser.deinit();
        ser.addUInt16(.{ .transaction_type = 1 }, 1);
        ser.addUInt32(.{ .fee = 2 }, 1000);
        ser.addAccountID(.{ .account = 3 }, [_]u8{1} ** 20);
        const result = try ser.finish();
        allocator.free(result);
    }
    const end = std.time.nanoTimestamp();
    const elapsed_ns = @as(f64, @floatFromInt(end - start));
    const elapsed_us = elapsed_ns / 1000.0;
    const elapsed_ms = elapsed_us / 1000.0;
    const ops_per_sec = (@as(f64, @floatFromInt(iterations)) / elapsed_ns) * 1_000_000_000.0;
    const avg_us = elapsed_us / @as(f64, @floatFromInt(iterations));

    std.debug.print("\n", .{});
    std.debug.print("Canonical Serialization Performance:\n", .{});
    std.debug.print("  Iterations: {d}\n", .{iterations});
    std.debug.print("  Total time: {d:.3} ms\n", .{elapsed_ms});
    std.debug.print("  Average: {d:.3} μs per serialization\n", .{avg_us});
    std.debug.print("  Throughput: {d:.0} serializations/sec\n", .{ops_per_sec});

    std.debug.print("\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
}

test "WEEK 3 DAY 17: Consensus stress test (100 rounds)" {
    const allocator = std.testing.allocator;

    std.debug.print("\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("  WEEK 3 DAY 17: CONSENSUS STRESS TEST\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});

    var lm = try ledger.LedgerManager.init(allocator);
    defer lm.deinit();

    var engine = try consensus.ConsensusEngine.init(allocator, &lm);
    defer engine.deinit();

    // Add validators for quorum
    var i: u8 = 0;
    while (i < 4) : (i += 1) {
        const validator = consensus.ValidatorInfo{
            .public_key = [_]u8{i} ** 33,
            .node_id = [_]u8{i + 10} ** 32,
            .is_trusted = true,
        };
        try engine.addValidator(validator);
    }

    const num_rounds = 100;
    const empty_txs: []const types.Transaction = &[_]types.Transaction{};

    const start = std.time.nanoTimestamp();

    var successful_rounds: u32 = 0;
    var round: u32 = 0;
    while (round < num_rounds) : (round += 1) {
        // Start round
        try engine.startRound(empty_txs);

        // Simulate proposals from validators
        const current_ledger_hash = engine.ledger_manager.getCurrentLedger().hash;
        for (engine.unl.items) |validator| {
            const proposal = consensus.Proposal{
                .validator_id = validator.node_id,
                .ledger_seq = @intCast(engine.ledger_manager.getCurrentLedger().sequence + 1),
                .close_time = std.time.timestamp(),
                .position = consensus.Position{
                    .prior_ledger = current_ledger_hash,
                    .transactions = &[_]types.TxHash{},
                    .close_time = std.time.timestamp(),
                },
                .signature = [_]u8{0} ** 64,
                .timestamp = std.time.timestamp(),
            };
            engine.processProposal(proposal) catch {};
        }

        // Run consensus to completion
        var consensus_reached = false;
        var iterations: u32 = 0;
        while (!consensus_reached and iterations < 100) : (iterations += 1) {
            consensus_reached = try engine.runRoundStep();
        }

        if (consensus_reached and engine.state == .accepted) {
            successful_rounds += 1;

            // Close ledger
            try lm.closeLedger(empty_txs);
        }
    }

    const end = std.time.nanoTimestamp();
    const elapsed_ns = @as(f64, @floatFromInt(end - start));
    const elapsed_us = elapsed_ns / 1000.0;
    const elapsed_ms = elapsed_us / 1000.0;
    const elapsed_sec = elapsed_ms / 1000.0;
    const avg_ms_per_round = elapsed_ms / @as(f64, @floatFromInt(num_rounds));
    const rounds_per_sec = (@as(f64, @floatFromInt(num_rounds)) / elapsed_ns) * 1_000_000_000.0;

    std.debug.print("\n", .{});
    std.debug.print("Consensus Stress Test Results:\n", .{});
    std.debug.print("  Total rounds: {d}\n", .{num_rounds});
    std.debug.print("  Successful rounds: {d}\n", .{successful_rounds});
    std.debug.print("  Success rate: {d:.1}%\n", .{(@as(f64, @floatFromInt(successful_rounds)) / @as(f64, @floatFromInt(num_rounds))) * 100.0});
    std.debug.print("  Total time: {d:.3} seconds\n", .{elapsed_sec});
    std.debug.print("  Average: {d:.3} ms per round\n", .{avg_ms_per_round});
    std.debug.print("  Throughput: {d:.1} rounds/sec\n", .{rounds_per_sec});

    std.debug.print("\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});

    // Verify we completed most rounds successfully
    try std.testing.expect(successful_rounds >= num_rounds * 0.9); // 90% success rate
}

test "WEEK 3 DAY 18: RPC load test (simulated)" {
    const allocator = std.testing.allocator;

    std.debug.print("\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("  WEEK 3 DAY 18: RPC LOAD TEST\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});

    var lm = try ledger.LedgerManager.init(allocator);
    defer lm.deinit();

    var state = ledger.AccountState.init(allocator);
    defer state.deinit();

    var processor = try transaction.TransactionProcessor.init(allocator);
    defer processor.deinit();

    var rpc = rpc_methods.RpcMethods.init(allocator, &lm, &state, &processor);

    const num_requests = 1000;
    const num_methods = 4; // server_info, ledger, fee, ledger_current

    const start = std.time.nanoTimestamp();

    var req: u32 = 0;
    while (req < num_requests) : (req += 1) {
        // Simulate different RPC methods
        const method = req % num_methods;
        var result: []u8 = undefined;

        switch (method) {
            0 => {
                result = try rpc.serverInfo(1000);
                allocator.free(result);
            },
            1 => {
                result = try rpc.ledgerInfo(null);
                allocator.free(result);
            },
            2 => {
                result = try rpc.fee();
                allocator.free(result);
            },
            3 => {
                result = try rpc.ledgerCurrent();
                allocator.free(result);
            },
            else => unreachable,
        }
    }

    const end = std.time.nanoTimestamp();
    const elapsed_ns = @as(f64, @floatFromInt(end - start));
    const elapsed_us = elapsed_ns / 1000.0;
    const elapsed_ms = elapsed_us / 1000.0;
    const elapsed_sec = elapsed_ms / 1000.0;
    const avg_us_per_request = elapsed_us / @as(f64, @floatFromInt(num_requests));
    const requests_per_sec = (@as(f64, @floatFromInt(num_requests)) / elapsed_ns) * 1_000_000_000.0;

    std.debug.print("\n", .{});
    std.debug.print("RPC Load Test Results:\n", .{});
    std.debug.print("  Total requests: {d}\n", .{num_requests});
    std.debug.print("  Methods tested: server_info, ledger, fee, ledger_current\n", .{});
    std.debug.print("  Total time: {d:.3} seconds\n", .{elapsed_sec});
    std.debug.print("  Average: {d:.3} μs per request\n", .{avg_us_per_request});
    std.debug.print("  Throughput: {d:.0} requests/sec\n", .{requests_per_sec});

    std.debug.print("\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
}

test "WEEK 3 DAY 18: Memory allocation patterns" {
    const allocator = std.testing.allocator;

    std.debug.print("\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("  WEEK 3 DAY 18: MEMORY ALLOCATION PATTERNS\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});

    const iterations = 1000;

    // Test ledger operations
    {
        var lm = try ledger.LedgerManager.init(allocator);
        defer lm.deinit();

        const start = std.time.nanoTimestamp();
        var i: u32 = 0;
        while (i < iterations) : (i += 1) {
            const empty_txs: []const types.Transaction = &[_]types.Transaction{};
            try lm.closeLedger(empty_txs);
        }
        const end = std.time.nanoTimestamp();
        const elapsed_ms = (@as(f64, @floatFromInt(end - start)) / 1000.0) / 1000.0;

        std.debug.print("\n", .{});
        std.debug.print("Ledger Operations:\n", .{});
        std.debug.print("  Operations: {d} ledger closes\n", .{iterations});
        std.debug.print("  Total time: {d:.3} ms\n", .{elapsed_ms});
        std.debug.print("  Average: {d:.3} μs per operation\n", .{(elapsed_ms * 1000.0) / @as(f64, @floatFromInt(iterations))});
    }

    // Test account creation
    {
        var state = ledger.AccountState.init(allocator);
        defer state.deinit();

        const start = std.time.nanoTimestamp();
        var i: u32 = 0;
        while (i < iterations) : (i += 1) {
            var account_id: types.AccountID = undefined;
            @memset(&account_id, @intCast(i % 256));
            try state.createAccount(account_id, 1000000);
        }
        const end = std.time.nanoTimestamp();
        const elapsed_ms = (@as(f64, @floatFromInt(end - start)) / 1000.0) / 1000.0;

        std.debug.print("\n", .{});
        std.debug.print("Account Creation:\n", .{});
        std.debug.print("  Operations: {d} account creations\n", .{iterations});
        std.debug.print("  Total time: {d:.3} ms\n", .{elapsed_ms});
        std.debug.print("  Average: {d:.3} μs per operation\n", .{(elapsed_ms * 1000.0) / @as(f64, @floatFromInt(iterations))});
    }

    std.debug.print("\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
}

test "WEEK 3 DAY 18: Performance summary" {
    std.debug.print("\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("  WEEK 3 DAYS 17-18: PERFORMANCE SUMMARY\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});

    std.debug.print("\n", .{});
    std.debug.print("Performance Benchmarks Completed:\n", .{});
    std.debug.print("  ✅ Hash calculation (SHA-512 Half)\n", .{});
    std.debug.print("  ✅ Canonical serialization\n", .{});
    std.debug.print("  ✅ Consensus stress test (100 rounds)\n", .{});
    std.debug.print("  ✅ RPC load test (1000 requests)\n", .{});
    std.debug.print("  ✅ Memory allocation patterns\n", .{});

    std.debug.print("\n", .{});
    std.debug.print("Next Steps:\n", .{});
    std.debug.print("  - Review hot paths identified\n", .{});
    std.debug.print("  - Optimize allocation patterns\n", .{});
    std.debug.print("  - Document performance characteristics\n", .{});

    std.debug.print("\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
}
