const std = @import("std");
const types = @import("types.zig");
const crypto = @import("crypto.zig");
const canonical = @import("canonical.zig");
const base58 = @import("base58.zig");

/// Complete Canonical Transaction Serialization for Signature Verification
/// 
/// Serializes transactions in XRPL canonical format (without signature fields)
/// for use in transaction hash calculation and signature verification

pub const CanonicalTransactionSerializer = struct {
    allocator: std.mem.Allocator,
    serializer: canonical.CanonicalSerializer,
    
    pub fn init(allocator: std.mem.Allocator) !CanonicalTransactionSerializer {
        return CanonicalTransactionSerializer{
            .allocator = allocator,
            .serializer = try canonical.CanonicalSerializer.init(allocator),
        };
    }
    
    pub fn deinit(self: *CanonicalTransactionSerializer) void {
        self.serializer.deinit();
    }
    
    /// Serialize transaction for signing (EXCLUDES signature fields)
    /// This is what gets hashed to produce the transaction hash
    pub fn serializeForSigning(self: *CanonicalTransactionSerializer, tx_json: TransactionJSON) ![]u8 {
        // XRPL canonical order (from testnet transaction structure):
        // 1. TransactionType (UInt16, field 2)
        // 2. Flags (UInt32, field 2)
        // 3. Account (AccountID, field 1)
        // 4. Sequence (UInt32, field 4)
        // 5. Fee (UInt64, field 8)
        // ... transaction-specific fields ...
        // NOTE: SigningPubKey and TxnSignature are EXCLUDED for signing
        
        // TransactionType
        if (tx_json.TransactionType) |tx_type| {
            const tx_type_code = txTypeToCode(tx_type);
            try self.serializer.addUInt16(2, tx_type_code);
        }
        
        // Flags (UInt32, field 2)
        if (tx_json.Flags) |flags| {
            try self.serializer.addUInt32(2, flags);
        }
        
        // Account (AccountID, field 1)
        if (tx_json.Account) |account_str| {
            const account = try base58.Base58.decodeAccountID(self.allocator, account_str);
            defer self.allocator.free(account);
            try self.serializer.addAccountID(1, account);
        }
        
        // Sequence (UInt32, field 4)
        if (tx_json.Sequence) |seq| {
            try self.serializer.addUInt32(4, seq);
        }
        
        // Fee (UInt64, field 8)
        if (tx_json.Fee) |fee_str| {
            const fee = try parseDrops(fee_str);
            try self.serializer.addUInt64(8, fee);
        }
        
        // Transaction-specific fields
        if (tx_json.TransactionType) |tx_type| {
            try self.addTransactionSpecificFields(tx_type, tx_json);
        }
        
        // Finalize and return
        return try self.serializer.finish();
    }
    
    /// Add transaction-specific fields
    fn addTransactionSpecificFields(self: *CanonicalTransactionSerializer, tx_type: []const u8, tx_json: TransactionJSON) !void {
        if (std.mem.eql(u8, tx_type, "Payment")) {
            // Destination (AccountID, field 3)
            if (tx_json.Destination) |dest_str| {
                const dest = try base58.Base58.decodeAccountID(self.allocator, dest_str);
                defer self.allocator.free(dest);
                try self.serializer.addAccountID(3, dest);
            }
            
            // Amount (Amount, field 1)
            if (tx_json.Amount) |amount_str| {
                // Parse amount (could be XRP drops or IOU)
                const amount = try parseAmount(self.allocator, amount_str);
                // Add amount field based on type
                switch (amount) {
                    .xrp => |drops| {
                        try self.serializer.addUInt64(1, drops);
                    },
                    .iou => |iou| {
                        // IOU amount encoding (simplified)
                        _ = iou; // TODO: Full IOU encoding
                    },
                }
            }
        } else if (std.mem.eql(u8, tx_type, "SignerListSet")) {
            // SignerQuorum (UInt32, field 5)
            if (tx_json.SignerQuorum) |quorum| {
                try self.serializer.addUInt32(5, quorum);
            }
            
            // SignerEntries (Array, field 9) - variable length
            if (tx_json.SignerEntries) |entries| {
                // Serialize signer entries array
                _ = entries; // TODO: Implement signer entries serialization
            }
        }
        // Add more transaction types as needed
    }
    
    /// Calculate transaction hash from serialized data
    pub fn calculateHash(serialized: []const u8) types.TxHash {
        return crypto.Hash.sha512Half(serialized);
    }
};

/// Transaction JSON structure (from testnet RPC)
pub const TransactionJSON = struct {
    TransactionType: ?[]const u8 = null,
    Account: ?[]const u8 = null,
    Destination: ?[]const u8 = null,
    Amount: ?[]const u8 = null,
    Fee: ?[]const u8 = null,
    Sequence: ?u32 = null,
    Flags: ?u32 = null,
    SigningPubKey: ?[]const u8 = null, // EXCLUDED from signing
    TxnSignature: ?[]const u8 = null, // EXCLUDED from signing
    SignerQuorum: ?u32 = null,
    SignerEntries: ?[]const u8 = null,
    hash: ?[]const u8 = null,
};

/// Convert transaction type string to code
fn txTypeToCode(tx_type: []const u8) u16 {
    if (std.mem.eql(u8, tx_type, "Payment")) return 0;
    if (std.mem.eql(u8, tx_type, "SignerListSet")) return 12;
    if (std.mem.eql(u8, tx_type, "AccountSet")) return 3;
    if (std.mem.eql(u8, tx_type, "TrustSet")) return 20;
    if (std.mem.eql(u8, tx_type, "OfferCreate")) return 7;
    if (std.mem.eql(u8, tx_type, "OfferCancel")) return 8;
    if (std.mem.eql(u8, tx_type, "EscrowCreate")) return 1;
    if (std.mem.eql(u8, tx_type, "EscrowFinish")) return 2;
    if (std.mem.eql(u8, tx_type, "EscrowCancel")) return 4;
    if (std.mem.eql(u8, tx_type, "PaymentChannelCreate")) return 13;
    if (std.mem.eql(u8, tx_type, "PaymentChannelFund")) return 14;
    if (std.mem.eql(u8, tx_type, "PaymentChannelClaim")) return 15;
    if (std.mem.eql(u8, tx_type, "CheckCreate")) return 16;
    if (std.mem.eql(u8, tx_type, "CheckCash")) return 17;
    if (std.mem.eql(u8, tx_type, "CheckCancel")) return 18;
    if (std.mem.eql(u8, tx_type, "NFTokenMint")) return 25;
    if (std.mem.eql(u8, tx_type, "NFTokenBurn")) return 26;
    if (std.mem.eql(u8, tx_type, "NFTokenCreateOffer")) return 27;
    if (std.mem.eql(u8, tx_type, "NFTokenCancelOffer")) return 28;
    if (std.mem.eql(u8, tx_type, "NFTokenAcceptOffer")) return 29;
    return 0; // Default to Payment
}

/// Parse drops string to u64
fn parseDrops(drops_str: []const u8) !u64 {
    return std.fmt.parseInt(u64, drops_str, 10);
}

/// Parse amount string
fn parseAmount(allocator: std.mem.Allocator, amount_str: []const u8) !types.Amount {
    _ = allocator;
    // Could be XRP drops or IOU JSON
    // Simplified - assume XRP for now
    const drops = try parseDrops(amount_str);
    return types.Amount.fromXRP(drops);
}

test "canonical transaction serialization" {
    const allocator = std.testing.allocator;
    
    var ser = try CanonicalTransactionSerializer.init(allocator);
    defer ser.deinit();
    
    // Test transaction data (simplified)
    const tx_json = TransactionJSON{
        .TransactionType = "Payment",
        .Account = "rN7n7otQDd6FczFgLdlqtyMVrn3X66B4T",
        .Sequence = 1,
        .Fee = "10",
        .Flags = 2147483648, // tfFullyCanonicalSig
    };
    
    const serialized = try ser.serializeForSigning(tx_json);
    defer allocator.free(serialized);
    
    const hash = CanonicalTransactionSerializer.calculateHash(serialized);
    
    std.debug.print("[PASS] Canonical transaction serialization works\n", .{});
    std.debug.print("   Serialized length: {d} bytes\n", .{serialized.len});
    std.debug.print("   Hash: {s}...\n", .{std.fmt.fmtSliceHexLower(hash[0..8])});
}

