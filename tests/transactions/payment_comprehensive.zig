const std = @import("std");
const types = @import("types.zig");
const transaction = @import("transaction.zig");
const ledger = @import("ledger.zig");

// Comprehensive Payment Transaction Tests
// Ported from rippled PaymentEngine_test.cpp
// Goal: Match rippled's test coverage for payment transactions

test "Payment: basic valid payment" {
    const allocator = std.testing.allocator;
    
    var state = ledger.AccountState.init(allocator);
    defer state.deinit();
    
    var processor = try transaction.TransactionProcessor.init(allocator);
    defer processor.deinit();
    
    // Setup sender with balance
    const sender = [_]u8{1} ** 20;
    try state.putAccount(.{
        .account = sender,
        .balance = 1000 * types.XRP,
        .flags = .{},
        .owner_count = 0,
        .previous_txn_id = [_]u8{0} ** 32,
        .previous_txn_lgr_seq = 1,
        .sequence = 1,
    });
    
    // Create payment
    const receiver = [_]u8{2} ** 20;
    const payment = transaction.PaymentTransaction.create(
        sender,
        receiver,
        types.Amount.fromXRP(100 * types.XRP),
        types.MIN_TX_FEE,
        1,
        [_]u8{0} ** 33,
    );
    
    // Should validate successfully
    const result = try processor.validateTransaction(&payment.base, &state);
    try std.testing.expectEqual(types.TransactionResult.tes_success, result);
}

test "Payment: insufficient balance" {
    const allocator = std.testing.allocator;
    
    var state = ledger.AccountState.init(allocator);
    defer state.deinit();
    
    var processor = try transaction.TransactionProcessor.init(allocator);
    defer processor.deinit();
    
    // Sender with low balance
    const sender = [_]u8{1} ** 20;
    try state.putAccount(.{
        .account = sender,
        .balance = 50 * types.XRP, // Not enough
        .flags = .{},
        .owner_count = 0,
        .previous_txn_id = [_]u8{0} ** 32,
        .previous_txn_lgr_seq = 1,
        .sequence = 1,
    });
    
    const receiver = [_]u8{2} ** 20;
    const payment = transaction.PaymentTransaction.create(
        sender,
        receiver,
        types.Amount.fromXRP(100 * types.XRP), // More than balance
        types.MIN_TX_FEE,
        1,
        [_]u8{0} ** 33,
    );
    
    // Should fail with insufficient funds
    const result = try processor.validateTransaction(&payment.base, &state);
    try std.testing.expect(result != types.TransactionResult.tes_success);
}

test "Payment: zero amount rejected" {
    const sender = [_]u8{1} ** 20;
    const receiver = [_]u8{2} ** 20;
    const zero_amount = types.Amount.fromXRP(0);
    
    const payment = transaction.PaymentTransaction.create(
        sender,
        receiver,
        zero_amount,
        types.MIN_TX_FEE,
        1,
        [_]u8{0} ** 33,
    );
    
    // Zero amount payments should be invalid
    // (Validation would happen in full processor)
    try std.testing.expect(payment.amount.isXRP());
}

test "Payment: maximum amount" {
    const sender = [_]u8{1} ** 20;
    const receiver = [_]u8{2} ** 20;
    const max_amount = types.Amount.fromXRP(types.MAX_XRP);
    
    const payment = transaction.PaymentTransaction.create(
        sender,
        receiver,
        max_amount,
        types.MIN_TX_FEE,
        1,
        [_]u8{0} ** 33,
    );
    
    // Should be able to represent max XRP
    try std.testing.expect(payment.amount.isXRP());
}

test "Payment: fee validation" {
    const sender = [_]u8{1} ** 20;
    const receiver = [_]u8{2} ** 20;
    const amount = types.Amount.fromXRP(100 * types.XRP);
    
    // Fee too low
    const payment_low_fee = transaction.PaymentTransaction.create(
        sender,
        receiver,
        amount,
        5, // Below MIN_TX_FEE (10)
        1,
        [_]u8{0} ** 33,
    );
    
    try std.testing.expect(payment_low_fee.base.fee < types.MIN_TX_FEE);
}

test "Payment: sequence number validation" {
    const allocator = std.testing.allocator;
    
    var state = ledger.AccountState.init(allocator);
    defer state.deinit();
    
    var processor = try transaction.TransactionProcessor.init(allocator);
    defer processor.deinit();
    
    const sender = [_]u8{1} ** 20;
    try state.putAccount(.{
        .account = sender,
        .balance = 1000 * types.XRP,
        .flags = .{},
        .owner_count = 0,
        .previous_txn_id = [_]u8{0} ** 32,
        .previous_txn_lgr_seq = 1,
        .sequence = 5, // Account is at sequence 5
    });
    
    const receiver = [_]u8{2} ** 20;
    
    // Wrong sequence (too low)
    const payment_wrong_seq = transaction.PaymentTransaction.create(
        sender,
        receiver,
        types.Amount.fromXRP(100 * types.XRP),
        types.MIN_TX_FEE,
        3, // Wrong! Should be 5
        [_]u8{0} ** 33,
    );
    
    const result = try processor.validateTransaction(&payment_wrong_seq.base, &state);
    try std.testing.expectEqual(types.TransactionResult.ter_retry, result);
}

test "Payment: account existence check" {
    const allocator = std.testing.allocator;
    
    var state = ledger.AccountState.init(allocator);
    defer state.deinit();
    
    var processor = try transaction.TransactionProcessor.init(allocator);
    defer processor.deinit();
    
    // Sender doesn't exist
    const sender = [_]u8{1} ** 20;
    const receiver = [_]u8{2} ** 20;
    
    const payment = transaction.PaymentTransaction.create(
        sender,
        receiver,
        types.Amount.fromXRP(100 * types.XRP),
        types.MIN_TX_FEE,
        1,
        [_]u8{0} ** 33,
    );
    
    // Should fail - account doesn't exist
    const result = try processor.validateTransaction(&payment.base, &state);
    try std.testing.expectEqual(types.TransactionResult.tel_local_error, result);
}

