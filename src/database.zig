const std = @import("std");
const types = @import("types.zig");
const ledger = @import("ledger.zig");

/// Simple key-value database for ledger persistence
/// In production, this would use RocksDB or NuDB
/// For now, we implement a working file-based solution
pub const Database = struct {
    allocator: std.mem.Allocator,
    data_dir: []const u8,
    ledger_cache: std.StringHashMap([]u8),
    account_cache: std.AutoHashMap(types.AccountID, []u8),
    
    pub fn init(allocator: std.mem.Allocator, data_dir: []const u8) !Database {
        // Create data directory
        std.fs.cwd().makeDir(data_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };
        
        return Database{
            .allocator = allocator,
            .data_dir = data_dir,
            .ledger_cache = std.StringHashMap([]u8).init(allocator),
            .account_cache = std.AutoHashMap(types.AccountID, []u8).init(allocator),
        };
    }
    
    pub fn deinit(self: *Database) void {
        // Free cached data
        var it = self.ledger_cache.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.ledger_cache.deinit();
        
        var it2 = self.account_cache.iterator();
        while (it2.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.account_cache.deinit();
    }
    
    /// Store a ledger
    pub fn putLedger(self: *Database, ledger_seq: types.LedgerSequence, data: []const u8) !void {
        // Create filename
        const filename = try std.fmt.allocPrint(
            self.allocator,
            "{s}/ledger_{d}.bin",
            .{ self.data_dir, ledger_seq },
        );
        defer self.allocator.free(filename);
        
        // Write to file
        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();
        try file.writeAll(data);
        
        // Update cache
        const key = try std.fmt.allocPrint(self.allocator, "{d}", .{ledger_seq});
        const value = try self.allocator.dupe(u8, data);
        try self.ledger_cache.put(key, value);
    }
    
    /// Get a ledger
    pub fn getLedger(self: *Database, ledger_seq: types.LedgerSequence) !?[]u8 {
        // Check cache first
        const key_str = try std.fmt.allocPrint(self.allocator, "{d}", .{ledger_seq});
        defer self.allocator.free(key_str);
        
        if (self.ledger_cache.get(key_str)) |cached| {
            return try self.allocator.dupe(u8, cached);
        }
        
        // Read from file
        const filename = try std.fmt.allocPrint(
            self.allocator,
            "{s}/ledger_{d}.bin",
            .{ self.data_dir, ledger_seq },
        );
        defer self.allocator.free(filename);
        
        const file = std.fs.cwd().openFile(filename, .{}) catch |err| {
            if (err == error.FileNotFound) return null;
            return err;
        };
        defer file.close();
        
        const data = try file.readToEndAlloc(self.allocator, 10 * 1024 * 1024); // 10MB limit
        return data;
    }
    
    /// Store an account
    pub fn putAccount(self: *Database, account_id: types.AccountID, data: []const u8) !void {
        const value = try self.allocator.dupe(u8, data);
        try self.account_cache.put(account_id, value);
        
        // Also persist to disk
        const filename = try std.fmt.allocPrint(
            self.allocator,
            "{s}/account_{}.bin",
            .{ self.data_dir, std.fmt.fmtSliceHexUpper(account_id[0..8]) },
        );
        defer self.allocator.free(filename);
        
        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();
        try file.writeAll(data);
    }
    
    /// Get an account
    pub fn getAccount(self: *Database, account_id: types.AccountID) !?[]u8 {
        // Check cache
        if (self.account_cache.get(account_id)) |cached| {
            return try self.allocator.dupe(u8, cached);
        }
        
        // Read from disk
        const filename = try std.fmt.allocPrint(
            self.allocator,
            "{s}/account_{}.bin",
            .{ self.data_dir, std.fmt.fmtSliceHexUpper(account_id[0..8]) },
        );
        defer self.allocator.free(filename);
        
        const file = std.fs.cwd().openFile(filename, .{}) catch |err| {
            if (err == error.FileNotFound) return null;
            return err;
        };
        defer file.close();
        
        const data = try file.readToEndAlloc(self.allocator, 1024 * 1024); // 1MB limit
        return data;
    }
    
    /// Batch write operation (atomic)
    pub fn batch(self: *Database, operations: []const BatchOp) !void {
        // In production, this would be a transaction
        for (operations) |op| {
            switch (op) {
                .put_ledger => |kv| try self.putLedger(kv.key, kv.value),
                .put_account => |kv| try self.putAccount(kv.key, kv.value),
                .delete_ledger => |seq| {
                    const filename = try std.fmt.allocPrint(
                        self.allocator,
                        "{s}/ledger_{d}.bin",
                        .{ self.data_dir, seq },
                    );
                    defer self.allocator.free(filename);
                    std.fs.cwd().deleteFile(filename) catch {};
                },
            }
        }
    }
    
    /// Get database statistics
    pub fn getStats(self: *const Database) DatabaseStats {
        return DatabaseStats{
            .ledger_cache_size = self.ledger_cache.count(),
            .account_cache_size = self.account_cache.count(),
        };
    }
};

/// Batch operation types
pub const BatchOp = union(enum) {
    put_ledger: struct { key: types.LedgerSequence, value: []const u8 },
    put_account: struct { key: types.AccountID, value: []const u8 },
    delete_ledger: types.LedgerSequence,
};

/// Database statistics
pub const DatabaseStats = struct {
    ledger_cache_size: usize,
    account_cache_size: usize,
};

test "database operations" {
    const allocator = std.testing.allocator;
    var db = try Database.init(allocator, ".test_db");
    defer db.deinit();
    defer std.fs.cwd().deleteTree(".test_db") catch {};
    
    // Store and retrieve ledger
    const test_data = "test ledger data";
    try db.putLedger(1, test_data);
    
    const retrieved = try db.getLedger(1);
    try std.testing.expect(retrieved != null);
    if (retrieved) |data| {
        defer allocator.free(data);
        try std.testing.expectEqualStrings(test_data, data);
    }
}

test "database caching" {
    const allocator = std.testing.allocator;
    var db = try Database.init(allocator, ".test_db2");
    defer db.deinit();
    defer std.fs.cwd().deleteTree(".test_db2") catch {};
    
    // Store data
    try db.putLedger(1, "data");
    
    // Check cache
    const stats = db.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.ledger_cache_size);
}

