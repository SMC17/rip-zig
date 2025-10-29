const std = @import("std");
const types = @import("types.zig");
const ledger = @import("ledger.zig");

/// Storage layer for ledger history and state
/// In production XRPL, this uses RocksDB or NuDB
pub const Storage = struct {
    allocator: std.mem.Allocator,
    data_dir: []const u8,
    
    pub fn init(allocator: std.mem.Allocator, data_dir: []const u8) !Storage {
        // Ensure data directory exists
        std.fs.cwd().makeDir(data_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };
        
        return Storage{
            .allocator = allocator,
            .data_dir = data_dir,
        };
    }
    
    pub fn deinit(self: *Storage) void {
        _ = self;
    }
    
    /// Store a ledger to disk
    pub fn storeLedger(self: *Storage, ledger_data: ledger.Ledger) !void {
        const filename = try std.fmt.allocPrint(
            self.allocator,
            "{s}/ledger_{d}.bin",
            .{ self.data_dir, ledger_data.sequence },
        );
        defer self.allocator.free(filename);
        
        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();
        
        // TODO: Serialize ledger in binary format
        // For now, just write the sequence number
        const bytes = std.mem.asBytes(&ledger_data.sequence);
        try file.writeAll(bytes);
        
        std.debug.print("Stored ledger {d} to disk\n", .{ledger_data.sequence});
    }
    
    /// Load a ledger from disk
    pub fn loadLedger(self: *Storage, sequence: types.LedgerSequence) !?ledger.Ledger {
        const filename = try std.fmt.allocPrint(
            self.allocator,
            "{s}/ledger_{d}.bin",
            .{ self.data_dir, sequence },
        );
        defer self.allocator.free(filename);
        
        const file = std.fs.cwd().openFile(filename, .{}) catch |err| {
            if (err == error.FileNotFound) return null;
            return err;
        };
        defer file.close();
        
        // TODO: Deserialize ledger from binary format
        var seq: types.LedgerSequence = undefined;
        const bytes_read = try file.readAll(std.mem.asBytes(&seq));
        if (bytes_read != @sizeOf(types.LedgerSequence)) {
            return error.InvalidLedgerData;
        }
        
        // For now, return a placeholder
        return ledger.Ledger{
            .sequence = seq,
            .hash = [_]u8{0} ** 32,
            .parent_hash = [_]u8{0} ** 32,
            .close_time = 0,
            .close_time_resolution = 10,
            .total_coins = types.MAX_XRP,
            .account_state_hash = [_]u8{0} ** 32,
            .transaction_hash = [_]u8{0} ** 32,
        };
    }
    
    /// Store account state
    pub fn storeAccountState(self: *Storage, account: types.AccountRoot) !void {
        _ = account;
        _ = self;
        // TODO: Implement account state storage
    }
    
    /// Load account state
    pub fn loadAccountState(self: *Storage, account_id: types.AccountID) !?types.AccountRoot {
        _ = account_id;
        _ = self;
        // TODO: Implement account state loading
        return null;
    }
};

/// In-memory cache for recent ledgers and frequently accessed data
pub const Cache = struct {
    allocator: std.mem.Allocator,
    ledger_cache: std.AutoHashMap(types.LedgerSequence, ledger.Ledger),
    max_size: usize,
    
    pub fn init(allocator: std.mem.Allocator, max_size: usize) Cache {
        return Cache{
            .allocator = allocator,
            .ledger_cache = std.AutoHashMap(types.LedgerSequence, ledger.Ledger).init(allocator),
            .max_size = max_size,
        };
    }
    
    pub fn deinit(self: *Cache) void {
        self.ledger_cache.deinit();
    }
    
    /// Cache a ledger
    pub fn cacheLedger(self: *Cache, ledger_data: ledger.Ledger) !void {
        // Evict oldest if cache is full
        if (self.ledger_cache.count() >= self.max_size) {
            // TODO: Implement LRU eviction
        }
        
        try self.ledger_cache.put(ledger_data.sequence, ledger_data);
    }
    
    /// Get a cached ledger
    pub fn getCachedLedger(self: *const Cache, sequence: types.LedgerSequence) ?ledger.Ledger {
        return self.ledger_cache.get(sequence);
    }
};

test "storage initialization" {
    const allocator = std.testing.allocator;
    var storage = try Storage.init(allocator, ".test_data");
    defer storage.deinit();
    
    // Clean up test directory
    std.fs.cwd().deleteTree(".test_data") catch {};
}

test "cache operations" {
    const allocator = std.testing.allocator;
    var cache = Cache.init(allocator, 10);
    defer cache.deinit();
    
    const test_ledger = ledger.Ledger.genesis();
    try cache.cacheLedger(test_ledger);
    
    const cached = cache.getCachedLedger(1);
    try std.testing.expect(cached != null);
    try std.testing.expectEqual(@as(types.LedgerSequence, 1), cached.?.sequence);
}

