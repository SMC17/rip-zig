const std = @import("std");

/// XRP is the native currency of the XRP Ledger
/// Internally stored as "drops" where 1 XRP = 1,000,000 drops
pub const Drops = u64;

/// 1 XRP in drops
pub const XRP: Drops = 1_000_000;

/// Maximum XRP supply (100 billion XRP)
pub const MAX_XRP: Drops = 100_000_000_000 * XRP;

/// Minimum transaction fee (10 drops)
pub const MIN_TX_FEE: Drops = 10;

/// Account address (20 bytes, displayed as base58 with checksum)
pub const AccountID = [20]u8;

/// Ledger sequence number
pub const LedgerSequence = u32;

/// Ledger hash (SHA-512 Half)
pub const LedgerHash = [32]u8;

/// Transaction hash
pub const TxHash = [32]u8;

/// Currency code (3-letter ISO 4217 or 160-bit hex)
pub const Currency = union(enum) {
    xrp: void,
    standard: [3]u8,  // e.g., USD, EUR
    custom: [20]u8,   // Custom currency code
    
    pub fn isXRP(self: Currency) bool {
        return self == .xrp;
    }
};

/// Amount can be XRP (in drops) or IOU (issued currency)
pub const Amount = union(enum) {
    xrp: Drops,
    iou: struct {
        currency: Currency,
        value: i64,      // Mantissa
        exponent: i8,    // For decimal representation
        issuer: AccountID,
    },
    
    pub fn fromXRP(drops: Drops) Amount {
        return .{ .xrp = drops };
    }
    
    pub fn isXRP(self: Amount) bool {
        return self == .xrp;
    }
};

/// Transaction types supported by XRP Ledger
pub const TransactionType = enum(u16) {
    payment = 0,
    escrow_create = 1,
    escrow_finish = 2,
    account_set = 3,
    escrow_cancel = 4,
    regular_key_set = 5,
    offer_create = 7,
    offer_cancel = 8,
    signer_list_set = 12,
    payment_channel_create = 13,
    payment_channel_fund = 14,
    payment_channel_claim = 15,
    check_create = 16,
    check_cash = 17,
    check_cancel = 18,
    deposit_preauth = 19,
    trust_set = 20,
    account_delete = 21,
    nftoken_mint = 25,
    nftoken_burn = 26,
    nftoken_create_offer = 27,
    nftoken_cancel_offer = 28,
    nftoken_accept_offer = 29,
};

/// Transaction result codes
pub const TransactionResult = enum {
    success,
    tec_claim,              // Fee claimed, but transaction failed
    tef_failure,            // Failed, fee not claimed
    tel_local_error,        // Local error
    tem_malformed,          // Malformed transaction
    ter_retry,              // Retry transaction
    tes_success,            // Success
};

/// Base transaction structure
pub const Transaction = struct {
    tx_type: TransactionType,
    account: AccountID,
    fee: Drops,
    sequence: u32,
    account_txn_id: ?TxHash = null,
    last_ledger_sequence: ?LedgerSequence = null,
    signing_pub_key: [33]u8,
    txn_signature: ?[]const u8 = null,
    
    // Transaction-specific fields would be added here
    // For now, we'll use a union or comptime to handle different types
};

/// Ledger entry types
pub const LedgerEntryType = enum(u16) {
    account_root = 0x61,
    ripple_state = 0x72,
    offer = 0x6f,
    directory_node = 0x64,
    amendments = 0x66,
    fee_settings = 0x73,
};

/// Account flags
pub const AccountFlags = packed struct {
    require_dest_tag: bool = false,
    require_auth: bool = false,
    disallow_xrp: bool = false,
    disable_master: bool = false,
    no_freeze: bool = false,
    global_freeze: bool = false,
    default_ripple: bool = false,
    deposit_auth: bool = false,
    _padding: u24 = 0,
};

/// Account root (the main account object in the ledger)
pub const AccountRoot = struct {
    account: AccountID,
    balance: Drops,
    flags: AccountFlags,
    owner_count: u32,
    previous_txn_id: TxHash,
    previous_txn_lgr_seq: LedgerSequence,
    sequence: u32,
    transfer_rate: ?u32 = null,
    email_hash: ?[16]u8 = null,
};

test "drops conversion" {
    try std.testing.expectEqual(@as(Drops, 1_000_000), XRP);
    try std.testing.expectEqual(@as(Drops, 100_000_000_000_000_000), MAX_XRP);
}

test "amount creation" {
    const amount = Amount.fromXRP(1000);
    try std.testing.expect(amount.isXRP());
}

test "currency types" {
    const xrp = Currency.xrp;
    try std.testing.expect(xrp == .xrp);
    
    const usd = Currency{ .standard = .{ 'U', 'S', 'D' } };
    try std.testing.expect(usd == .standard);
}

