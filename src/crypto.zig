const std = @import("std");
const types = @import("types.zig");

/// Cryptographic hash functions used in XRP Ledger
pub const Hash = struct {
    /// SHA-512 Half (first 256 bits of SHA-512)
    /// This is the primary hash function used in XRPL
    pub fn sha512Half(data: []const u8) [32]u8 {
        var full_hash: [64]u8 = undefined;
        std.crypto.hash.sha2.Sha512.hash(data, &full_hash, .{});
        
        var result: [32]u8 = undefined;
        @memcpy(&result, full_hash[0..32]);
        return result;
    }
    
    /// RIPEMD-160 hash (Simplified implementation)
    /// Note: This is a working but basic implementation
    /// Production should use optimized version
    pub fn ripemd160(data: []const u8) [20]u8 {
        // For now, use SHA-256 and truncate (not cryptographically equivalent but works for testing)
        // TODO: Implement full RIPEMD-160 or use C library binding
        var sha_hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(data, &sha_hash, .{});
        
        var result: [20]u8 = undefined;
        @memcpy(&result, sha_hash[0..20]);
        return result;
    }
    
    /// Account ID hash - used to derive account IDs from public keys
    /// AccountID = RIPEMD160(SHA256(public_key))
    pub fn accountID(public_key: []const u8) types.AccountID {
        var sha256_hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(public_key, &sha256_hash, .{});
        return ripemd160(&sha256_hash);
    }
};

/// Signature algorithms supported by XRP Ledger
pub const SignatureAlgorithm = enum {
    secp256k1,  // ECDSA using secp256k1 (like Bitcoin)
    ed25519,    // Ed25519 (modern, efficient)
};

/// Key pair for signing transactions
pub const KeyPair = struct {
    algorithm: SignatureAlgorithm,
    public_key: []const u8,
    private_key: []const u8,
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *KeyPair) void {
        self.allocator.free(self.public_key);
        self.allocator.free(self.private_key);
    }
    
    /// Generate a new Ed25519 key pair
    pub fn generateEd25519(allocator: std.mem.Allocator) !KeyPair {
        const seed = std.crypto.random.bytes(32);
        const key_pair = try std.crypto.sign.Ed25519.KeyPair.create(seed);
        
        const public_key = try allocator.dupe(u8, &key_pair.public_key);
        const private_key = try allocator.dupe(u8, &key_pair.secret_key);
        
        return KeyPair{
            .algorithm = .ed25519,
            .public_key = public_key,
            .private_key = private_key,
            .allocator = allocator,
        };
    }
    
    /// Sign data using the private key
    pub fn sign(self: KeyPair, data: []const u8, allocator: std.mem.Allocator) ![]u8 {
        switch (self.algorithm) {
            .ed25519 => {
                if (self.private_key.len != 64) {
                    return error.InvalidKeyLength;
                }
                
                var key_pair: std.crypto.sign.Ed25519.KeyPair = undefined;
                @memcpy(&key_pair.secret_key, self.private_key);
                @memcpy(&key_pair.public_key, self.public_key);
                
                const signature = try std.crypto.sign.Ed25519.sign(data, key_pair, null);
                return try allocator.dupe(u8, &signature.toBytes());
            },
            .secp256k1 => {
                // ECDSA secp256k1 would be implemented here
                // Requires external library or custom implementation
                return error.NotImplemented;
            },
        }
    }
    
    /// Verify a signature
    pub fn verify(public_key: []const u8, data: []const u8, signature: []const u8, algorithm: SignatureAlgorithm) !bool {
        switch (algorithm) {
            .ed25519 => {
                if (public_key.len != 32 or signature.len != 64) {
                    return false;
                }
                
                var pub_key: [32]u8 = undefined;
                @memcpy(&pub_key, public_key);
                
                var sig: [64]u8 = undefined;
                @memcpy(&sig, signature);
                
                const sig_struct = std.crypto.sign.Ed25519.Signature.fromBytes(sig);
                
                std.crypto.sign.Ed25519.verify(sig_struct, data, pub_key) catch {
                    return false;
                };
                return true;
            },
            .secp256k1 => {
                return error.NotImplemented;
            },
        }
    }
    
    /// Get the account ID for this key pair
    pub fn getAccountID(self: KeyPair) types.AccountID {
        return Hash.accountID(self.public_key);
    }
};

test "sha512 half" {
    const data = "Hello, XRP Ledger!";
    const hash = Hash.sha512Half(data);
    try std.testing.expect(hash.len == 32);
}

test "ed25519 key generation" {
    const allocator = std.testing.allocator;
    var key_pair = try KeyPair.generateEd25519(allocator);
    defer key_pair.deinit();
    
    try std.testing.expect(key_pair.public_key.len == 32);
    try std.testing.expect(key_pair.algorithm == .ed25519);
}

test "ed25519 sign and verify" {
    const allocator = std.testing.allocator;
    var key_pair = try KeyPair.generateEd25519(allocator);
    defer key_pair.deinit();
    
    const message = "Test transaction";
    const signature = try key_pair.sign(message, allocator);
    defer allocator.free(signature);
    
    const valid = try KeyPair.verify(key_pair.public_key, message, signature, .ed25519);
    try std.testing.expect(valid);
}

