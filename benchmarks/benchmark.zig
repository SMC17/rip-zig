const std = @import("std");
const types = @import("types.zig");
const crypto = @import("crypto.zig");
const ledger = @import("ledger.zig");
const transaction = @import("transaction.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== rippled-zig Performance Benchmarks ===\n\n", .{});

    // Benchmark 1: Key Generation
    try benchmarkKeyGeneration(allocator);

    // Benchmark 2: Transaction Signing
    try benchmarkTransactionSigning(allocator);

    // Benchmark 3: Ledger Operations
    try benchmarkLedgerOperations(allocator);

    // Benchmark 4: Transaction Validation
    try benchmarkTransactionValidation(allocator);

    // Benchmark 5: Memory Usage
    try benchmarkMemoryUsage(allocator);

    std.debug.print("\n=== Benchmarks Complete ===\n\n", .{});
}

fn benchmarkKeyGeneration(allocator: std.mem.Allocator) !void {
    std.debug.print("Benchmark: Ed25519 Key Generation\n", .{});

    const iterations: usize = 1000;
    var timer = try std.time.Timer.start();

    for (0..iterations) |_| {
        var keys = try crypto.KeyPair.generateEd25519(allocator);
        keys.deinit();
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;
    const ops_per_sec = (iterations * 1_000_000_000) / elapsed;

    std.debug.print("  - Iterations: {d}\n", .{iterations});
    std.debug.print("  - Time per operation: {d} ns\n", .{ns_per_op});
    std.debug.print("  - Operations per second: {d}\n\n", .{ops_per_sec});
}

fn benchmarkTransactionSigning(allocator: std.mem.Allocator) !void {
    std.debug.print("Benchmark: Transaction Signing\n", .{});

    var keys = try crypto.KeyPair.generateEd25519(allocator);
    defer keys.deinit();

    const sender = keys.getAccountID();
    const receiver = [_]u8{2} ** 20;

    const iterations: usize = 1000;
    var timer = try std.time.Timer.start();

    for (0..iterations) |_| {
        var payment = transaction.PaymentTransaction.create(
            sender,
            receiver,
            types.Amount.fromXRP(100 * types.XRP),
            types.MIN_TX_FEE,
            1,
            keys.public_key[0..33].*,
        );
        try payment.sign(keys, allocator);
        if (payment.base.txn_signature) |sig| {
            allocator.free(sig);
        }
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;
    const ops_per_sec = (iterations * 1_000_000_000) / elapsed;

    std.debug.print("  - Iterations: {d}\n", .{iterations});
    std.debug.print("  - Time per operation: {d} ns\n", .{ns_per_op});
    std.debug.print("  - Operations per second: {d}\n\n", .{ops_per_sec});
}

fn benchmarkLedgerOperations(allocator: std.mem.Allocator) !void {
    std.debug.print("Benchmark: Ledger Operations\n", .{});

    var manager = try ledger.LedgerManager.init(allocator);
    defer manager.deinit();

    const iterations: usize = 100;
    var timer = try std.time.Timer.start();

    const empty_txs: []const types.Transaction = &[_]types.Transaction{};
    for (0..iterations) |_| {
        _ = try manager.closeLedger(empty_txs);
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;
    const ops_per_sec = (iterations * 1_000_000_000) / elapsed;

    std.debug.print("  - Iterations: {d}\n", .{iterations});
    std.debug.print("  - Time per ledger close: {d} ns\n", .{ns_per_op});
    std.debug.print("  - Ledger closes per second: {d}\n\n", .{ops_per_sec});
}

fn benchmarkTransactionValidation(allocator: std.mem.Allocator) !void {
    std.debug.print("Benchmark: Transaction Validation\n", .{});

    var processor = try transaction.TransactionProcessor.init(allocator);
    defer processor.deinit();

    var state = ledger.AccountState.init(allocator);
    defer state.deinit();

    // Create test account
    const account_id = [_]u8{1} ** 20;
    const account = types.AccountRoot{
        .account = account_id,
        .balance = 1_000_000 * types.XRP,
        .flags = .{},
        .owner_count = 0,
        .previous_txn_id = [_]u8{0} ** 32,
        .previous_txn_lgr_seq = 1,
        .sequence = 1,
    };
    try state.putAccount(account);

    const tx = types.Transaction{
        .tx_type = .payment,
        .account = account_id,
        .fee = types.MIN_TX_FEE,
        .sequence = 1,
        .signing_pub_key = [_]u8{0} ** 33,
    };

    const iterations: usize = 10000;
    var timer = try std.time.Timer.start();

    for (0..iterations) |_| {
        _ = try processor.validateTransaction(&tx, &state);
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;
    const ops_per_sec = (iterations * 1_000_000_000) / elapsed;

    std.debug.print("  - Iterations: {d}\n", .{iterations});
    std.debug.print("  - Time per validation: {d} ns\n", .{ns_per_op});
    std.debug.print("  - Validations per second: {d}\n\n", .{ops_per_sec});
}

fn benchmarkMemoryUsage(allocator: std.mem.Allocator) !void {
    std.debug.print("Benchmark: Memory Usage\n", .{});

    // Get initial memory
    const initial = try std.process.totalSystemMemory();
    
    // Create a bunch of objects
    var manager = try ledger.LedgerManager.init(allocator);
    defer manager.deinit();

    var state = ledger.AccountState.init(allocator);
    defer state.deinit();

    // Add 1000 accounts
    for (0..1000) |i| {
        var account_id: [20]u8 = undefined;
        std.mem.writeInt(u160, &account_id, @intCast(i), .big);
        
        const account = types.AccountRoot{
            .account = account_id,
            .balance = 1_000 * types.XRP,
            .flags = .{},
            .owner_count = 0,
            .previous_txn_id = [_]u8{0} ** 32,
            .previous_txn_lgr_seq = 1,
            .sequence = 1,
        };
        try state.putAccount(account);
    }

    // Close 100 ledgers
    const empty_txs: []const types.Transaction = &[_]types.Transaction{};
    for (0..100) |_| {
        _ = try manager.closeLedger(empty_txs);
    }

    const final = try std.process.totalSystemMemory();
    const used = final - initial;

    std.debug.print("  - Accounts created: 1000\n", .{});
    std.debug.print("  - Ledgers closed: 100\n", .{});
    std.debug.print("  - Approximate memory used: {d} bytes\n\n", .{used});
}

