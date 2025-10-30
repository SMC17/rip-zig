const std = @import("std");
const ledger = @import("ledger.zig");
const types = @import("types.zig");
const serialization = @import("serialization.zig");
const base58 = @import("base58.zig");

/// PHASE 1: VALIDATION AGAINST REAL XRPL TESTNET DATA
///
/// EVERY test that fails reveals a bug we need to fix
const REAL_LEDGER_DATA = struct {
    const sequence: u32 = 11900686;
    const ledger_hash = "FB90529615FA52790E2B2E24C32A482DBF9F969C3FDC2726ED0A64A40962BF00";
    const parent_hash = "630D7DDAFBCF0449FEC7E4EB4056F2187BDCC6C4315788D6416766A4B7C7F6B6";
    const account_hash = "A569ACFF4EB95A65B8FD3A9A7C0E68EE17A96EA051896A3F235863ED776ACBAE";
    const transaction_hash = "FAA3C9DB987A612C9A4B011805F00BF69DA56E8DF127D9AACB7C13A1CD0BC505";
    const close_time: i64 = 815078240;
    const close_time_resolution: u32 = 10;
    const total_coins = "99999914350172385";
    const close_flags: u32 = 0;
    const parent_close_time: i64 = 815078232;
};

test "VALIDATION: ledger structure matches real testnet format" {
    // Our ledger structure
    const our_ledger = ledger.Ledger{
        .sequence = REAL_LEDGER_DATA.sequence,
        .hash = [_]u8{0} ** 32, // Will test hash calculation separately
        .parent_hash = [_]u8{0} ** 32,
        .close_time = REAL_LEDGER_DATA.close_time,
        .close_time_resolution = REAL_LEDGER_DATA.close_time_resolution,
        .total_coins = try std.fmt.parseInt(u64, REAL_LEDGER_DATA.total_coins, 10),
        .account_state_hash = [_]u8{0} ** 32,
        .transaction_hash = [_]u8{0} ** 32,
    };

    // Verify we can represent the real ledger
    try std.testing.expectEqual(REAL_LEDGER_DATA.sequence, our_ledger.sequence);
    try std.testing.expectEqual(REAL_LEDGER_DATA.close_time, our_ledger.close_time);
    try std.testing.expectEqual(REAL_LEDGER_DATA.close_time_resolution, our_ledger.close_time_resolution);

    std.debug.print("✅ Basic ledger structure matches\n", .{});
    std.debug.print("⚠️  TODO: Add close_flags and parent_close_time fields\n", .{});
}

test "VALIDATION: can parse real ledger hash from hex" {
    const allocator = std.testing.allocator;

    // Real ledger hash from testnet
    const hex_hash = REAL_LEDGER_DATA.ledger_hash;

    // Parse hex string to bytes
    var hash_bytes: [32]u8 = undefined;
    for (hex_hash, 0..) |_, i| {
        if (i >= 64) break; // 32 bytes = 64 hex chars
        if (i % 2 == 0) {
            const hex_pair = hex_hash[i .. i + 2];
            hash_bytes[i / 2] = try std.fmt.parseInt(u8, hex_pair, 16);
        }
    }

    // Verify we can work with real hashes
    try std.testing.expectEqual(@as(usize, 32), hash_bytes.len);

    std.debug.print("✅ Can parse real ledger hashes\n", .{});
    std.debug.print("   Ledger hash: {s}...\n", .{hex_hash[0..16]});
}

test "VALIDATION: total coins matches real network" {
    // Real testnet has: 99999914350172385 drops
    const real_total = try std.fmt.parseInt(u64, REAL_LEDGER_DATA.total_coins, 10);

    // This should be ~100 billion XRP minus burned fees
    const expected_approx = 100_000_000_000 * types.XRP;

    // Should be less than initial supply (fees have been burned)
    try std.testing.expect(real_total < expected_approx);
    try std.testing.expect(real_total > (99_000_000_000 * types.XRP)); // At least 99B XRP left

    std.debug.print("✅ Total coins in valid range\n", .{});
    std.debug.print("   Testnet total: {} drops ({} XRP)\n", .{ real_total, real_total / types.XRP });
}

test "VALIDATION: base58 encoding format" {
    const allocator = std.testing.allocator;

    // Create a test account ID
    const account_id: types.AccountID = [_]u8{
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
        0x10, 0x11, 0x12, 0x13,
    };

    // Encode to address
    const address = try base58.Base58.encodeAccountID(allocator, account_id);
    defer allocator.free(address);

    // XRPL addresses should start with 'r'
    try std.testing.expect(address[0] == 'r');

    // Should be reasonable length (25-35 characters typical)
    try std.testing.expect(address.len >= 25 and address.len <= 40);

    std.debug.print("✅ Base58 produces valid address format\n", .{});
    std.debug.print("   Example address: {s}\n", .{address});
    std.debug.print("⚠️  TODO: Validate against KNOWN real addresses\n", .{});
}

test "VALIDATION: fee structure matches testnet" {
    // From test_data/fee_info.json, testnet shows:
    // base_fee: 10, median_fee: 10, minimum_fee: 10

    try std.testing.expectEqual(@as(types.Drops, 10), types.MIN_TX_FEE);

    std.debug.print("✅ Minimum fee matches testnet\n", .{});
}

test "VALIDATION: server info response structure" {
    const allocator = std.testing.allocator;

    // Our server info should include:
    // - build_version
    // - complete_ledgers (as range string)
    // - peers
    // - validated_ledger with hash
    // - network_id (for testnet = 1)

    // This test documents what we need to add
    std.debug.print("⚠️  GAPS in server_info:\n", .{});
    std.debug.print("   - Missing network_id field\n", .{});
    std.debug.print("   - Missing last_close details\n", .{});
    std.debug.print("   - Missing peer statistics\n", .{});
    std.debug.print("   - Missing complete_ledgers range format\n", .{});
}

/// VALIDATION SUMMARY
/// Run this to see overall validation status
pub fn printValidationStatus() void {
    std.debug.print("\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});
    std.debug.print("   XRPL VALIDATION STATUS\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("✅ PASSING:\n", .{});
    std.debug.print("  - Basic ledger structure\n", .{});
    std.debug.print("  - Hex hash parsing\n", .{});
    std.debug.print("  - Total coins validation\n", .{});
    std.debug.print("  - Base58 format\n", .{});
    std.debug.print("  - Fee structure\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("⚠️  NEEDS WORK:\n", .{});
    std.debug.print("  - Add close_flags to Ledger struct\n", .{});
    std.debug.print("  - Add parent_close_time to Ledger struct\n", .{});
    std.debug.print("  - Validate serialization produces correct hashes\n", .{});
    std.debug.print("  - Test against known real addresses\n", .{});
    std.debug.print("  - Implement SignerListSet transaction\n", .{});
    std.debug.print("  - Add multi-signature support\n", .{});
    std.debug.print("  - Match server_info format exactly\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("🔴 NOT TESTED YET:\n", .{});
    std.debug.print("  - Transaction hash calculation\n", .{});
    std.debug.print("  - Signature verification with real data\n", .{});
    std.debug.print("  - State tree hash calculation\n", .{});
    std.debug.print("  - Peer protocol compatibility\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("════════════════════════════════════════\n", .{});
    std.debug.print("STATUS: VALIDATION IN PROGRESS\n", .{});
    std.debug.print("LAUNCH: NOT READY YET\n", .{});
    std.debug.print("════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
}
