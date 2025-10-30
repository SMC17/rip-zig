const std = @import("std");
const types = @import("types.zig");
const crypto = @import("crypto.zig");
const ledger = @import("ledger.zig");

/// Transaction validation and processing
pub const TransactionProcessor = struct {
    allocator: std.mem.Allocator,
    pending_transactions: std.ArrayList(types.Transaction),

    pub fn init(allocator: std.mem.Allocator) !TransactionProcessor {
        return TransactionProcessor{
            .allocator = allocator,
            .pending_transactions = try std.ArrayList(types.Transaction).initCapacity(allocator, 0),
        };
    }

    pub fn deinit(self: *TransactionProcessor) void {
        self.pending_transactions.deinit(self.allocator);
    }

    /// Validate a transaction
    pub fn validateTransaction(self: *const TransactionProcessor, tx: *const types.Transaction, account_state: *const ledger.AccountState) !types.TransactionResult {
        _ = self;

        // Check if account exists
        const account = account_state.getAccount(tx.account) orelse {
            return .tel_local_error;
        };

        // Validate fee
        if (tx.fee < types.MIN_TX_FEE) {
            return .tem_malformed;
        }

        // Check if account has enough balance to pay the fee
        if (account.balance < tx.fee) {
            return .tec_claim;
        }

        // Validate sequence number
        if (tx.sequence != account.sequence) {
            return .ter_retry;
        }

        // Transaction-specific validation would go here
        switch (tx.tx_type) {
            .payment => {
                // Validate payment-specific fields
            },
            .account_set => {
                // Validate account_set fields
            },
            else => {
                // Other transaction types
            },
        }

        return .tes_success;
    }

    /// Submit a transaction to the pending queue
    pub fn submitTransaction(self: *TransactionProcessor, tx: types.Transaction) !void {
        try self.pending_transactions.append(self.allocator, tx);
        std.debug.print("Transaction submitted: type={s}, fee={d}\n", .{
            @tagName(tx.tx_type),
            tx.fee,
        });
    }

    /// Get pending transactions for the next ledger
    pub fn getPendingTransactions(self: *const TransactionProcessor) []const types.Transaction {
        return self.pending_transactions.items;
    }

    /// Clear pending transactions (after ledger close)
    pub fn clearPending(self: *TransactionProcessor) void {
        self.pending_transactions.clearRetainingCapacity();
    }
};

/// Payment transaction (most common transaction type)
pub const PaymentTransaction = struct {
    base: types.Transaction,
    destination: types.AccountID,
    amount: types.Amount,
    destination_tag: ?u32 = null,
    send_max: ?types.Amount = null,

    /// Create a new payment transaction
    pub fn create(
        account: types.AccountID,
        destination: types.AccountID,
        amount: types.Amount,
        fee: types.Drops,
        sequence: u32,
        signing_pub_key: [33]u8,
    ) PaymentTransaction {
        return PaymentTransaction{
            .base = types.Transaction{
                .tx_type = .payment,
                .account = account,
                .fee = fee,
                .sequence = sequence,
                .signing_pub_key = signing_pub_key,
            },
            .destination = destination,
            .amount = amount,
        };
    }

    /// Sign the payment transaction
    pub fn sign(self: *PaymentTransaction, key_pair: crypto.KeyPair, allocator: std.mem.Allocator) !void {
        // Serialize the transaction for signing
        const tx_data = try self.serialize(allocator);
        defer allocator.free(tx_data);

        // Sign the serialized data
        const signature = try key_pair.sign(tx_data, allocator);
        self.base.txn_signature = signature;
    }

    /// Serialize transaction for signing or transmission
    pub fn serialize(self: *const PaymentTransaction, allocator: std.mem.Allocator) ![]u8 {
        // TODO: Implement proper serialization (canonical field ordering, binary format)
        // For now, simplified version
        var list = try std.ArrayList(u8).initCapacity(allocator, 128);
        errdefer list.deinit(allocator);

        try list.appendSlice(allocator, &self.base.account);
        try list.appendSlice(allocator, &self.destination);
        try list.appendSlice(allocator, std.mem.asBytes(&self.base.fee));
        try list.appendSlice(allocator, std.mem.asBytes(&self.base.sequence));

        return list.toOwnedSlice(allocator);
    }
};

/// Account Set transaction - modify account settings
pub const AccountSetTransaction = struct {
    base: types.Transaction,
    clear_flag: ?u32 = null,
    set_flag: ?u32 = null,
    transfer_rate: ?u32 = null,
    email_hash: ?[16]u8 = null,

    pub fn create(
        account: types.AccountID,
        fee: types.Drops,
        sequence: u32,
        signing_pub_key: [33]u8,
    ) AccountSetTransaction {
        return AccountSetTransaction{
            .base = types.Transaction{
                .tx_type = .account_set,
                .account = account,
                .fee = fee,
                .sequence = sequence,
                .signing_pub_key = signing_pub_key,
            },
        };
    }
};

/// Trust Set transaction - create or modify a trust line
pub const TrustSetTransaction = struct {
    base: types.Transaction,
    limit_amount: types.Amount,
    quality_in: ?u32 = null,
    quality_out: ?u32 = null,

    pub fn create(
        account: types.AccountID,
        limit_amount: types.Amount,
        fee: types.Drops,
        sequence: u32,
        signing_pub_key: [33]u8,
    ) TrustSetTransaction {
        return TrustSetTransaction{
            .base = types.Transaction{
                .tx_type = .trust_set,
                .account = account,
                .fee = fee,
                .sequence = sequence,
                .signing_pub_key = signing_pub_key,
            },
            .limit_amount = limit_amount,
        };
    }
};

test "transaction validation" {
    const allocator = std.testing.allocator;
    var processor = try TransactionProcessor.init(allocator);
    defer processor.deinit();

    var state = ledger.AccountState.init(allocator);
    defer state.deinit();

    // Create an account
    const account_id = [_]u8{1} ** 20;
    const account = types.AccountRoot{
        .account = account_id,
        .balance = 1000 * types.XRP,
        .flags = .{},
        .owner_count = 0,
        .previous_txn_id = [_]u8{0} ** 32,
        .previous_txn_lgr_seq = 1,
        .sequence = 1,
    };
    try state.putAccount(account);

    // Create a valid transaction
    const tx = types.Transaction{
        .tx_type = .payment,
        .account = account_id,
        .fee = types.MIN_TX_FEE,
        .sequence = 1,
        .signing_pub_key = [_]u8{0} ** 33,
    };

    const result = try processor.validateTransaction(&tx, &state);
    try std.testing.expectEqual(types.TransactionResult.tes_success, result);
}

test "payment transaction creation" {
    const sender = [_]u8{1} ** 20;
    const receiver = [_]u8{2} ** 20;
    const amount = types.Amount.fromXRP(100 * types.XRP);

    const payment = PaymentTransaction.create(
        sender,
        receiver,
        amount,
        types.MIN_TX_FEE,
        1,
        [_]u8{0} ** 33,
    );

    try std.testing.expectEqual(types.TransactionType.payment, payment.base.tx_type);
    try std.testing.expectEqual(amount, payment.amount);
}
