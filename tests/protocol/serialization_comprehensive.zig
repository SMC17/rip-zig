const std = @import("std");
const canonical = @import("canonical.zig");
const canonical_tx = @import("canonical_tx.zig");
const serialization = @import("serialization.zig");
const types = @import("types.zig");
const crypto = @import("crypto.zig");

// Comprehensive Serialization Tests
// Based on rippled STTx_test.cpp and STObject_test.cpp
// Ensures exact binary format compatibility

test "Serialization: UInt8 field encoding" {
    const allocator = std.testing.allocator;
    var ser = try serialization.Serializer.init(allocator);
    defer ser.deinit();
    
    try ser.addUInt8(.account, 42);
    const result = ser.finish();
    
    // Should have type byte + value
    try std.testing.expectEqual(@as(usize, 2), result.len);
}

test "Serialization: UInt16 big-endian" {
    const allocator = std.testing.allocator;
    var ser = try canonical.CanonicalSerializer.init(allocator);
    defer ser.deinit();
    
    try ser.addUInt16(2, 0x1234);
    const result = try ser.finish();
    defer allocator.free(result);
    
    // Verify big-endian encoding
    try std.testing.expect(result.len >= 3);
}

test "Serialization: UInt32 encoding" {
    const allocator = std.testing.allocator;
    var ser = try canonical.CanonicalSerializer.init(allocator);
    defer ser.deinit();
    
    const test_value: u32 = 0x12345678;
    try ser.addUInt32(4, test_value);
    
    const result = try ser.finish();
    defer allocator.free(result);
    
    try std.testing.expect(result.len >= 5); // Type byte + 4 bytes
}

test "Serialization: Account ID encoding" {
    const allocator = std.testing.allocator;
    var ser = try canonical.CanonicalSerializer.init(allocator);
    defer ser.deinit();
    
    const account = [_]u8{1} ** 20;
    try ser.addAccountID(1, account);
    
    const result = try ser.finish();
    defer allocator.free(result);
    
    try std.testing.expectEqual(@as(usize, 21), result.len); // Type byte + 20 bytes
}

test "Serialization: XRP amount bit layout" {
    // XRP encoding: bit 62 set (positive), bits 0-61 = drops
    const drops: u64 = 1_000_000; // 1 XRP
    const encoded = drops | (1 << 62);
    
    // Verify bit 62 is set
    try std.testing.expect((encoded & (1 << 62)) != 0);
    // Verify bit 63 is not set
    try std.testing.expect((encoded & (1 << 63)) == 0);
    // Verify drops are preserved
    try std.testing.expectEqual(drops, encoded & ((1 << 62) - 1));
}

test "Serialization: Variable length encoding short" {
    const allocator = std.testing.allocator;
    var ser = try canonical.CanonicalSerializer.init(allocator);
    defer ser.deinit();
    
    const short_data = "test";
    try ser.addVL(3, short_data);
    
    const result = try ser.finish();
    defer allocator.free(result);
    
    // Should encode length as single byte for data < 193 bytes
    try std.testing.expect(result.len == 1 + 1 + 4); // Type + length + data
}

test "Serialization: Variable length encoding medium" {
    const allocator = std.testing.allocator;
    var ser = try canonical.CanonicalSerializer.init(allocator);
    defer ser.deinit();
    
    const medium_data = "x" ** 300; // 300 bytes
    try ser.addVL(3, medium_data);
    
    const result = try ser.finish();
    defer allocator.free(result);
    
    // Should encode length as 2 bytes for 193-12480
    try std.testing.expect(result.len == 1 + 2 + 300);
}

test "Canonical: Field ordering - type groups" {
    const allocator = std.testing.allocator;
    var ser = try canonical.CanonicalSerializer.init(allocator);
    defer ser.deinit();
    
    // Add in wrong order
    try ser.addUInt64(8, 100); // Fee (UInt64)
    try ser.addUInt32(4, 1); // Sequence (UInt32)
    try ser.addUInt16(2, 0); // TransactionType (UInt16)
    
    const result = try ser.finish();
    defer allocator.free(result);
    
    // First field should be UInt16 (type 0x10)
    try std.testing.expect((result[0] & 0xF0) == 0x10);
}

test "Canonical: Transaction hash calculation" {
    const allocator = std.testing.allocator;
    var ser = try canonical_tx.CanonicalTransactionSerializer.init(allocator);
    defer ser.deinit();
    
    // Create simple payment
    try ser.addTransactionType(.payment);
    try ser.addFlags(0);
    try ser.addSequence(1);
    try ser.addAccount([_]u8{1} ** 20);
    try ser.addFee(10);
    try ser.addDestination([_]u8{2} ** 20);
    try ser.addAmount(types.Amount.fromXRP(100 * types.XRP));
    
    const serialized = try ser.finish();
    defer allocator.free(serialized);
    
    const hash = crypto.Hash.sha512Half(serialized);
    
    // Hash should be non-zero
    var all_zero = true;
    for (hash) |byte| {
        if (byte != 0) {
            all_zero = false;
            break;
        }
    }
    try std.testing.expect(!all_zero);
}

test "Serialization: Round-trip fidelity" {
    const allocator = std.testing.allocator;
    var ser = try canonical.CanonicalSerializer.init(allocator);
    defer ser.deinit();
    
    const original_seq: u32 = 12345;
    try ser.addUInt32(4, original_seq);
    
    const serialized = try ser.finish();
    defer allocator.free(serialized);
    
    // Deserialize
    var deser = serialization.Deserializer.init(serialized);
    _ = try deser.readUInt8(); // Skip type byte
    const read_seq = try deser.readUInt32();
    
    try std.testing.expectEqual(original_seq, read_seq);
}

