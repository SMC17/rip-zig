const std = @import("std");
const ledger = @import("../src/ledger.zig");
const crypto = @import("../src/crypto.zig");

/// DAY 13: Ledger Hash Algorithm Fix Validation
/// Verify that ledger hash now uses SHA-512 Half instead of SHA-256

test "DAY 13: Verify ledger hash uses SHA-512 Half" {
    std.debug.print("\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("  DAY 13: LEDGER HASH ALGORITHM FIX VALIDATION\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    
    // Create a test ledger
    const test_ledger = ledger.Ledger{
        .sequence = 12345,
        .hash = [_]u8{0} ** 32,
        .parent_hash = [_]u8{0xAA} ** 32,
        .close_time = 1234567890,
        .close_time_resolution = 10,
        .total_coins = 1000000000,
        .account_state_hash = [_]u8{0xBB} ** 32,
        .transaction_hash = [_]u8{0xCC} ** 32,
        .close_flags = 1,
        .parent_close_time = 1234567880,
    };
    
    // Calculate hash
    const calculated_hash = test_ledger.calculateHash();
    
    std.debug.print("Test Ledger:\n", .{});
    std.debug.print("  Sequence: {d}\n", .{test_ledger.sequence});
    std.debug.print("  Close time: {d}\n", .{test_ledger.close_time});
    std.debug.print("  Close flags: {d}\n", .{test_ledger.close_flags});
    
    std.debug.print("\n", .{});
    std.debug.print("Calculated Hash:\n", .{});
    std.debug.print("  Length: {d} bytes (correct)\n", .{calculated_hash.len});
    std.debug.print("  Hash: ", .{});
    for (calculated_hash[0..16]) |byte| {
        std.debug.print("{X:0>2}", .{byte});
    }
    std.debug.print("...\n", .{});
    
    // Verify it's not all zeros
    var all_zeros = true;
    for (calculated_hash) |byte| {
        if (byte != 0) {
            all_zeros = false;
            break;
        }
    }
    
    try std.testing.expect(!all_zeros);
    try std.testing.expectEqual(@as(usize, 32), calculated_hash.len);
    
    std.debug.print("\n", .{});
    std.debug.print("✅ Ledger hash calculation works\n", .{});
    std.debug.print("✅ Hash is non-zero\n", .{});
    std.debug.print("✅ Hash length is correct (32 bytes)\n", .{});
    
    // Verify it uses SHA-512 Half (not SHA-256)
    // We can verify by calculating what SHA-256 would give vs SHA-512 Half
    // For the same input, they should produce different results
    
    // Manually calculate what we're hashing
    var buffer: [200]u8 = undefined;
    var offset: usize = 0;
    
    std.mem.writeInt(u32, buffer[offset..][0..4], test_ledger.sequence, .big);
    offset += 4;
    @memcpy(buffer[offset..][0..32], &test_ledger.parent_hash);
    offset += 32;
    std.mem.writeInt(i64, buffer[offset..][0..8], test_ledger.close_time, .big);
    offset += 8;
    @memcpy(buffer[offset..][0..32], &test_ledger.account_state_hash);
    offset += 32;
    @memcpy(buffer[offset..][0..32], &test_ledger.transaction_hash);
    offset += 32;
    std.mem.writeInt(u32, buffer[offset..][0..4], test_ledger.close_flags, .big);
    offset += 4;
    
    // Calculate SHA-512 Half
    const sha512half_result = crypto.Hash.sha512Half(buffer[0..offset]);
    
    // Calculate SHA-256 for comparison
    var sha256_result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(buffer[0..offset], &sha256_result, .{});
    
    // Verify our hash matches SHA-512 Half (not SHA-256)
    const matches_sha512half = std.mem.eql(u8, &calculated_hash, &sha512half_result);
    const matches_sha256 = std.mem.eql(u8, &calculated_hash, &sha256_result);
    
    try std.testing.expect(matches_sha512half);
    try std.testing.expect(!matches_sha256);
    
    std.debug.print("\n", .{});
    std.debug.print("Algorithm Verification:\n", .{});
    std.debug.print("  ✅ Matches SHA-512 Half: {any}\n", .{matches_sha512half});
    std.debug.print("  ✅ Does NOT match SHA-256: {any}\n", .{!matches_sha256});
    
    std.debug.print("\n", .{});
    std.debug.print("✅ LEDGER HASH ALGORITHM FIX VERIFIED\n", .{});
    std.debug.print("   Now using SHA-512 Half (per XRPL spec)\n", .{});
    std.debug.print("   Previously used SHA-256 (incorrect)\n", .{});
    
    std.debug.print("\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
}

test "DAY 13: Ledger hash consistency test" {
    // Test that same ledger produces same hash (deterministic)
    const test_ledger = ledger.Ledger{
        .sequence = 1,
        .hash = [_]u8{0} ** 32,
        .parent_hash = [_]u8{1} ** 32,
        .close_time = 1000000,
        .close_time_resolution = 10,
        .total_coins = 1000000,
        .account_state_hash = [_]u8{2} ** 32,
        .transaction_hash = [_]u8{3} ** 32,
        .close_flags = 0,
        .parent_close_time = 999999,
    };
    
    const hash1 = test_ledger.calculateHash();
    const hash2 = test_ledger.calculateHash();
    
    // Should be deterministic
    try std.testing.expectEqualSlices(u8, &hash1, &hash2);
    
    std.debug.print("✅ Ledger hash is deterministic\n", .{});
}

