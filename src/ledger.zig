const std = @import("std");
const types = @import("types.zig");
const crypto = @import("crypto.zig");

/// A ledger version - an immutable snapshot of all account states
pub const Ledger = struct {
    sequence: types.LedgerSequence,
    hash: types.LedgerHash,
    parent_hash: types.LedgerHash,
    close_time: i64,  // Unix timestamp
    close_time_resolution: u32,
    total_coins: types.Drops,
    account_state_hash: [32]u8,
    transaction_hash: [32]u8,
    
    /// Genesis ledger - the first ledger in the chain
    pub fn genesis() Ledger {
        return Ledger{
            .sequence = 1,
            .hash = [_]u8{0} ** 32,
            .parent_hash = [_]u8{0} ** 32,
            .close_time = 0,
            .close_time_resolution = 10,
            .total_coins = types.MAX_XRP,
            .account_state_hash = [_]u8{0} ** 32,
            .transaction_hash = [_]u8{0} ** 32,
        };
    }
    
    /// Calculate the hash of this ledger
    pub fn calculateHash(self: *const Ledger) types.LedgerHash {
        // In production, this would serialize all ledger fields and hash them
        // For now, simplified version
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        
        const seq_bytes = std.mem.asBytes(&self.sequence);
        hasher.update(seq_bytes);
        hasher.update(&self.parent_hash);
        hasher.update(std.mem.asBytes(&self.close_time));
        hasher.update(&self.account_state_hash);
        hasher.update(&self.transaction_hash);
        
        var hash: [32]u8 = undefined;
        hasher.final(&hash);
        return hash;
    }
};

/// Manages the ledger chain and state
pub const LedgerManager = struct {
    allocator: std.mem.Allocator,
    current_ledger: Ledger,
    ledger_history: std.ArrayList(Ledger),
    
    pub fn init(allocator: std.mem.Allocator) !LedgerManager {
        var history = try std.ArrayList(Ledger).initCapacity(allocator, 100);
        const genesis = Ledger.genesis();
        try history.append(allocator, genesis);
        
        return LedgerManager{
            .allocator = allocator,
            .current_ledger = genesis,
            .ledger_history = history,
        };
    }
    
    pub fn deinit(self: *LedgerManager) void {
        self.ledger_history.deinit(self.allocator);
    }
    
    /// Get the current validated ledger
    pub fn getCurrentLedger(self: *const LedgerManager) Ledger {
        return self.current_ledger;
    }
    
    /// Get a ledger by sequence number
    pub fn getLedger(self: *const LedgerManager, sequence: types.LedgerSequence) ?Ledger {
        if (sequence == 0 or sequence > self.ledger_history.items.len) {
            return null;
        }
        return self.ledger_history.items[sequence - 1];
    }
    
    /// Close the current ledger and create a new one
    pub fn closeLedger(self: *LedgerManager, transactions: []const types.Transaction) !Ledger {
        _ = transactions; // TODO: Process transactions
        
        const now = std.time.timestamp();
        var new_ledger = Ledger{
            .sequence = self.current_ledger.sequence + 1,
            .hash = undefined,
            .parent_hash = self.current_ledger.hash,
            .close_time = now,
            .close_time_resolution = 10,
            .total_coins = self.current_ledger.total_coins,
            .account_state_hash = [_]u8{0} ** 32, // TODO: Calculate from state tree
            .transaction_hash = [_]u8{0} ** 32,   // TODO: Calculate from transactions
        };
        
        new_ledger.hash = new_ledger.calculateHash();
        
        try self.ledger_history.append(self.allocator, new_ledger);
        self.current_ledger = new_ledger;
        
        std.debug.print("Ledger closed: seq={d}, hash={any}\n", .{
            new_ledger.sequence,
            new_ledger.hash[0..8],
        });
        
        return new_ledger;
    }
    
    /// Validate a ledger hash
    pub fn validateLedger(ledger: *const Ledger) bool {
        const calculated = ledger.calculateHash();
        return std.mem.eql(u8, &calculated, &ledger.hash);
    }
};

/// Account state stored in the ledger
pub const AccountState = struct {
    accounts: std.AutoHashMap(types.AccountID, types.AccountRoot),
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) AccountState {
        return AccountState{
            .accounts = std.AutoHashMap(types.AccountID, types.AccountRoot).init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *AccountState) void {
        self.accounts.deinit();
    }
    
    /// Get an account from the state
    pub fn getAccount(self: *const AccountState, account_id: types.AccountID) ?types.AccountRoot {
        return self.accounts.get(account_id);
    }
    
    /// Create or update an account
    pub fn putAccount(self: *AccountState, account: types.AccountRoot) !void {
        try self.accounts.put(account.account, account);
    }
    
    /// Check if an account exists
    pub fn hasAccount(self: *const AccountState, account_id: types.AccountID) bool {
        return self.accounts.contains(account_id);
    }
};

test "genesis ledger" {
    const genesis = Ledger.genesis();
    try std.testing.expectEqual(@as(types.LedgerSequence, 1), genesis.sequence);
    try std.testing.expectEqual(types.MAX_XRP, genesis.total_coins);
}

test "ledger manager" {
    const allocator = std.testing.allocator;
    var manager = try LedgerManager.init(allocator);
    defer manager.deinit();
    
    const current = manager.getCurrentLedger();
    try std.testing.expectEqual(@as(types.LedgerSequence, 1), current.sequence);
    
    // Close a ledger
    const empty_txs: []const types.Transaction = &[_]types.Transaction{};
    const new_ledger = try manager.closeLedger(empty_txs);
    try std.testing.expectEqual(@as(types.LedgerSequence, 2), new_ledger.sequence);
}

test "account state" {
    const allocator = std.testing.allocator;
    var state = AccountState.init(allocator);
    defer state.deinit();
    
    const account_id = [_]u8{1} ** 20;
    try std.testing.expect(!state.hasAccount(account_id));
    
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
    try std.testing.expect(state.hasAccount(account_id));
    
    const retrieved = state.getAccount(account_id).?;
    try std.testing.expectEqual(account.balance, retrieved.balance);
}

