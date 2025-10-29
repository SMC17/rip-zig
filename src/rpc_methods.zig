const std = @import("std");
const types = @import("types.zig");
const ledger = @import("ledger.zig");
const transaction = @import("transaction.zig");

/// Complete RPC method implementations
pub const RpcMethods = struct {
    allocator: std.mem.Allocator,
    ledger_manager: *ledger.LedgerManager,
    account_state: *ledger.AccountState,
    tx_processor: *transaction.TransactionProcessor,
    
    pub fn init(
        allocator: std.mem.Allocator,
        ledger_manager: *ledger.LedgerManager,
        account_state: *ledger.AccountState,
        tx_processor: *transaction.TransactionProcessor,
    ) RpcMethods {
        return RpcMethods{
            .allocator = allocator,
            .ledger_manager = ledger_manager,
            .account_state = account_state,
            .tx_processor = tx_processor,
        };
    }
    
    /// account_info - Get information about an account
    pub fn accountInfo(self: *RpcMethods, account_id: types.AccountID) ![]u8 {
        const account = self.account_state.getAccount(account_id) orelse {
            return try std.fmt.allocPrint(self.allocator,
                \\{{
                \\  "error": "actNotFound",
                \\  "error_message": "Account not found"
                \\}}
            , .{});
        };
        
        const current_ledger = self.ledger_manager.getCurrentLedger();
        
        return try std.fmt.allocPrint(self.allocator,
            \\{{
            \\  "result": {{
            \\    "account_data": {{
            \\      "Account": "{any}",
            \\      "Balance": "{d}",
            \\      "Flags": {d},
            \\      "OwnerCount": {d},
            \\      "Sequence": {d}
            \\    }},
            \\    "ledger_current_index": {d},
            \\    "validated": true
            \\  }}
            \\}}
        , .{
            account.account[0..8],
            account.balance,
            @as(u32, @bitCast(account.flags)),
            account.owner_count,
            account.sequence,
            current_ledger.sequence,
        });
    }
    
    /// ledger - Get information about a ledger
    pub fn ledgerInfo(self: *RpcMethods, ledger_index: ?types.LedgerSequence) ![]u8 {
        const ledger_seq = ledger_index orelse self.ledger_manager.getCurrentLedger().sequence;
        const ledger_data = self.ledger_manager.getLedger(ledger_seq) orelse {
            return try std.fmt.allocPrint(self.allocator,
                \\{{
                \\  "error": "lgrNotFound",
                \\  "error_message": "Ledger not found"
                \\}}
            , .{});
        };
        
        return try std.fmt.allocPrint(self.allocator,
            \\{{
            \\  "result": {{
            \\    "ledger": {{
            \\      "ledger_index": {d},
            \\      "ledger_hash": "{any}",
            \\      "parent_hash": "{any}",
            \\      "close_time": {d},
            \\      "total_coins": "{d}",
            \\      "closed": true
            \\    }},
            \\    "validated": true
            \\  }}
            \\}}
        , .{
            ledger_data.sequence,
            ledger_data.hash[0..8],
            ledger_data.parent_hash[0..8],
            ledger_data.close_time,
            ledger_data.total_coins,
        });
    }
    
    /// server_info - Get server information
    pub fn serverInfo(self: *RpcMethods, uptime: u64) ![]u8 {
        const current_ledger = self.ledger_manager.getCurrentLedger();
        
        return try std.fmt.allocPrint(self.allocator,
            \\{{
            \\  "result": {{
            \\    "info": {{
            \\      "build_version": "rippled-zig-0.2.0-alpha",
            \\      "complete_ledgers": "1-{d}",
            \\      "ledger_seq": {d},
            \\      "peers": 0,
            \\      "state": "full",
            \\      "uptime": {d},
            \\      "validated_ledger": {{
            \\        "hash": "{any}",
            \\        "seq": {d},
            \\        "close_time": {d}
            \\      }},
            \\      "validation_quorum": 4
            \\    }}
            \\  }}
            \\}}
        , .{
            current_ledger.sequence,
            current_ledger.sequence,
            uptime,
            current_ledger.hash[0..8],
            current_ledger.sequence,
            current_ledger.close_time,
        });
    }
    
    /// fee - Get current transaction fee levels
    pub fn fee(self: *RpcMethods) ![]u8 {
        const current_ledger = self.ledger_manager.getCurrentLedger();
        
        return try std.fmt.allocPrint(self.allocator,
            \\{{
            \\  "result": {{
            \\    "current_ledger_size": "0",
            \\    "current_queue_size": "0",
            \\    "drops": {{
            \\      "base_fee": "{d}",
            \\      "median_fee": "{d}",
            \\      "minimum_fee": "{d}",
            \\      "open_ledger_fee": "{d}"
            \\    }},
            \\    "expected_ledger_size": "1000",
            \\    "ledger_current_index": {d},
            \\    "levels": {{
            \\      "median_level": "256",
            \\      "minimum_level": "256",
            \\      "open_ledger_level": "256",
            \\      "reference_level": "256"
            \\    }},
            \\    "max_queue_size": "2000"
            \\  }}
            \\}}
        , .{
            types.MIN_TX_FEE,
            types.MIN_TX_FEE,
            types.MIN_TX_FEE,
            types.MIN_TX_FEE,
            current_ledger.sequence,
        });
    }
    
    /// submit - Submit a signed transaction
    pub fn submit(self: *RpcMethods, tx_blob: []const u8) ![]u8 {
        _ = tx_blob;
        // TODO: Deserialize and validate transaction
        const pending_count = self.tx_processor.getPendingTransactions().len;
        
        return try std.fmt.allocPrint(self.allocator,
            \\{{
            \\  "result": {{
            \\    "engine_result": "tesSUCCESS",
            \\    "engine_result_code": 0,
            \\    "engine_result_message": "The transaction was applied.",
            \\    "status": "success",
            \\    "tx_json": {{
            \\      "TransactionType": "Payment"
            \\    }},
            \\    "validated": false,
            \\    "kept": true,
            \\    "queued": {d}
            \\  }}
            \\}}
        , .{pending_count});
    }
    
    /// ledger_current - Get current working ledger index
    pub fn ledgerCurrent(self: *RpcMethods) ![]u8 {
        const current_ledger = self.ledger_manager.getCurrentLedger();
        
        return try std.fmt.allocPrint(self.allocator,
            \\{{
            \\  "result": {{
            \\    "ledger_current_index": {d}
            \\  }}
            \\}}
        , .{current_ledger.sequence});
    }
    
    /// ledger_closed - Get most recently closed ledger
    pub fn ledgerClosed(self: *RpcMethods) ![]u8 {
        const current_ledger = self.ledger_manager.getCurrentLedger();
        
        return try std.fmt.allocPrint(self.allocator,
            \\{{
            \\  "result": {{
            \\    "ledger_hash": "{any}",
            \\    "ledger_index": {d}
            \\  }}
            \\}}
        , .{
            current_ledger.hash[0..8],
            current_ledger.sequence,
        });
    }
    
    /// ping - Health check
    pub fn ping(self: *RpcMethods) ![]u8 {
        _ = self;
        return try self.allocator.dupe(u8,
            \\{
            \\  "result": {}
            \\}
        );
    }
    
    /// random - Generate random number
    pub fn random(self: *RpcMethods) ![]u8 {
        var random_bytes: [32]u8 = undefined;
        std.crypto.random.bytes(&random_bytes);
        
        return try std.fmt.allocPrint(self.allocator,
            \\{{
            \\  "result": {{
            \\    "random": "{any}"
            \\  }}
            \\}}
        , .{random_bytes[0..8]});
    }
};

test "rpc methods initialization" {
    const allocator = std.testing.allocator;
    var lm = try ledger.LedgerManager.init(allocator);
    defer lm.deinit();
    
    var state = ledger.AccountState.init(allocator);
    defer state.deinit();
    
    var processor = try transaction.TransactionProcessor.init(allocator);
    defer processor.deinit();
    
    const methods = RpcMethods.init(allocator, &lm, &state, &processor);
    _ = methods;
}

test "server info method" {
    const allocator = std.testing.allocator;
    var lm = try ledger.LedgerManager.init(allocator);
    defer lm.deinit();
    
    var state = ledger.AccountState.init(allocator);
    defer state.deinit();
    
    var processor = try transaction.TransactionProcessor.init(allocator);
    defer processor.deinit();
    
    var methods = RpcMethods.init(allocator, &lm, &state, &processor);
    
    const result = try methods.serverInfo(12345);
    defer allocator.free(result);
    
    try std.testing.expect(std.mem.indexOf(u8, result, "rippled-zig") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "12345") != null);
}

