const std = @import("std");
const types = @import("types.zig");
const serialization = @import("serialization.zig");
const crypto = @import("crypto.zig");
const base58 = @import("base58.zig");
const ledger = @import("ledger.zig");
const network = @import("network.zig");

/// PHASE 1 VALIDATION: Systematic testing against REAL XRPL testnet
/// 
/// Each test verifies ONE specific claim against real network data
/// FAILURES are GOOD - they show us what to fix
/// 
/// Test results go into DISCOVERED_ISSUES.md

// Real testnet data from ledger #11900686
const TestData = struct {
    // Known good Base58 addresses from XRPL
    const addresses = [_][]const u8{
        "rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh", // Genesis account
        "rN7n7otQDd6FczFgLdlqtyMVrn3X66B4T", // Test account
    };
    
    // Real ledger #11900686
    const ledger_hash_hex = "FB90529615FA52790E2B2E24C32A482DBF9F969C3FDC2726ED0A64A40962BF00";
    const account_hash_hex = "A569ACFF4EB95A65B8FD3A9A7C0E68EE17A96EA051896A3F235863ED776ACBAE";
    const tx_hash_hex = "FAA3C9DB987A612C9A4B011805F00BF69DA56E8DF127D9AACB7C13A1CD0BC505";
    
    // Real transaction hash from testnet
    const real_tx_hash = "09D0D3C0AB0E6D8EBB3117C2FF1DD72F063818F528AF54A4553C8541DD2E8B5B";
};

/// Helper: Parse hex string to bytes
fn parseHex(hex: []const u8, out: []u8) !void {
    if (hex.len != out.len * 2) return error.InvalidHexLength;
    
    var i: usize = 0;
    while (i < out.len) : (i += 1) {
        out[i] = try std.fmt.parseInt(u8, hex[i*2..i*2+2], 16);
    }
}

// ============================================================================
// TEST 1: Hex Parsing Utility
// ============================================================================

test "VALIDATION 1: hex parsing utility works" {
    const hex = "DEADBEEF";
    var bytes: [4]u8 = undefined;
    try parseHex(hex, &bytes);
    
    try std.testing.expectEqual(@as(u8, 0xDE), bytes[0]);
    try std.testing.expectEqual(@as(u8, 0xAD), bytes[1]);
    try std.testing.expectEqual(@as(u8, 0xBE), bytes[2]);
    try std.testing.expectEqual(@as(u8, 0xEF), bytes[3]);
    
    std.debug.print("✅ VALIDATION 1: Hex parsing works\n", .{});
}

// ============================================================================
// TEST 2: Can Parse Real Ledger Hashes
// ============================================================================

test "VALIDATION 2: can parse real testnet ledger hashes" {
    var ledger_hash: [32]u8 = undefined;
    try parseHex(TestData.ledger_hash_hex, &ledger_hash);
    
    // Verify it's not all zeros
    var all_zeros = true;
    for (ledger_hash) |byte| {
        if (byte != 0) {
            all_zeros = false;
            break;
        }
    }
    try std.testing.expect(!all_zeros);
    
    std.debug.print("✅ VALIDATION 2: Real ledger hash parsed correctly\n", .{});
    std.debug.print("   Hash: {any}...\n", .{ledger_hash[0..8]});
}

// ============================================================================
// TEST 3: Base58 Round-Trip
// ============================================================================

test "VALIDATION 3: base58 encoding round-trip" {
    const allocator = std.testing.allocator;
    
    // Create test account
    const test_account: types.AccountID = [_]u8{
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
        0x10, 0x11, 0x12, 0x13,
    };
    
    // Encode
    const encoded = try base58.Base58.encodeAccountID(allocator, test_account);
    defer allocator.free(encoded);
    
    // Decode
    const decoded = try base58.Base58.decodeAccountID(allocator, encoded);
    
    // Must match original
    try std.testing.expectEqualSlices(u8, &test_account, &decoded);
    
    std.debug.print("✅ VALIDATION 3: Base58 round-trip works\n", .{});
    std.debug.print("   Address: {s}\n", .{encoded});
}

// ============================================================================
// TEST 4: Serialization Field Ordering
// ============================================================================

test "VALIDATION 4: serialization field types" {
    const allocator = std.testing.allocator;
    var ser = try serialization.Serializer.init(allocator);
    defer ser.deinit();
    
    // Test each field type
    try ser.addUInt8(.account, 1);
    try ser.addUInt32(.sequence, 12345);
    try ser.addAccountID(.account, [_]u8{1} ** 20);
    
    const result = ser.finish();
    
    // Should have produced some bytes
    try std.testing.expect(result.len > 0);
    
    std.debug.print("✅ VALIDATION 4: Serialization produces output\n", .{});
    std.debug.print("   Bytes: {d}\n", .{result.len});
    std.debug.print("⚠️  TODO: Validate against REAL transaction serialization\n", .{});
}

// ============================================================================
// TEST 5: Amount Encoding Format
// ============================================================================

test "VALIDATION 5: XRP amount encoding" {
    const allocator = std.testing.allocator;
    var ser = try serialization.Serializer.init(allocator);
    defer ser.deinit();
    
    // XRP amounts in XRPL have special encoding:
    // - Bit 62 must be 0 for XRP
    // - Bit 63 indicates positive (1) or negative (0)
    // - Remaining 62 bits are the amount in drops
    
    const xrp_amount = types.Amount.fromXRP(100 * types.XRP);
    try ser.addAmount(.amount, xrp_amount);
    
    const result = ser.finish();
    try std.testing.expect(result.len > 0);
    
    std.debug.print("✅ VALIDATION 5: XRP amount serialization works\n", .{});
    std.debug.print("⚠️  TODO: Validate encoding matches XRPL spec exactly\n", .{});
}

// ============================================================================
// TEST 6: Transaction Hash Calculation
// ============================================================================

test "VALIDATION 6: transaction hash calculation" {
    // CRITICAL TEST: Can we produce correct transaction hashes?
    // 
    // Real transaction from testnet:
    // Hash: 09D0D3C0AB0E6D8EBB3117C2FF1DD72F063818F528AF54A4553C8541DD2E8B5B
    //
    // To test:
    // 1. Get transaction data
    // 2. Serialize in canonical form
    // 3. Hash with SHA-512 Half
    // 4. Compare to real hash
    //
    // EXPECTED: Will probably NOT match yet
    // Our serialization is simplified and might have bugs
    
    std.debug.print("⚠️  VALIDATION 6: Transaction hash NOT TESTED YET\n", .{});
    std.debug.print("   Need to: Parse real tx, serialize, hash, compare\n", .{});
    std.debug.print("   Real hash: {s}...\n", .{TestData.real_tx_hash[0..16]});
    std.debug.print("   Status: CRITICAL - Must fix before claiming compatibility\n", .{});
}

// ============================================================================
// TEST 7: Signature Verification Against Real Data
// ============================================================================

test "VALIDATION 7: signature verification" {
    // CRITICAL TEST: Can we verify real XRPL signatures?
    //
    // Real signed transaction has:
    // SigningPubKey: "02D3FC6F04117E6420CAEA735C57CEEC934820BBCD109200933F6BBDD98F7BFBD9"
    // TxnSignature: "3045022100E30FEACFAE9ED8034C4E24203BBFD6CE0D48ABCA901EDCE6EE04AA281A4DD73F..."
    //
    // To test:
    // 1. Parse signature and public key
    // 2. Reconstruct signing data (serialized tx without signature)
    // 3. Verify signature
    //
    // EXPECTED: Might fail due to:
    // - Wrong signing data (serialization bugs)
    // - Wrong signature format
    // - Wrong public key format
    
    std.debug.print("⚠️  VALIDATION 7: Signature verification NOT TESTED YET\n", .{});
    std.debug.print("   Need to: Extract real sig data and verify\n", .{});
    std.debug.print("   Status: CRITICAL - Security depends on this\n", .{});
}

// ============================================================================
// TEST 8: Ledger Hash Calculation
// ============================================================================

test "VALIDATION 8: ledger hash calculation" {
    // CRITICAL TEST: Can we calculate correct ledger hashes?
    //
    // Real ledger #11900686:
    // Hash: FB90529615FA52790E2B2E24C32A482DBF9F969C3FDC2726ED0A64A40962BF00
    //
    // Ledger hash is calculated from:
    // - All ledger header fields
    // - In specific canonical order
    // - With specific encoding
    // - Hashed with SHA-512 Half
    //
    // To test:
    // 1. Create ledger with real values
    // 2. Calculate hash with our algorithm
    // 3. Compare to real hash
    //
    // EXPECTED: Will probably NOT match
    // Our algorithm is simplified
    
    var real_ledger_hash: [32]u8 = undefined;
    try parseHex(TestData.ledger_hash_hex, &real_ledger_hash);
    
    std.debug.print("⚠️  VALIDATION 8: Ledger hash NOT VALIDATED YET\n", .{});
    std.debug.print("   Real hash: {any}...\n", .{real_ledger_hash[0..8]});
    std.debug.print("   Need to: Calculate with our code and compare\n", .{});
    std.debug.print("   Status: CRITICAL - Cannot validate ledgers without this\n", .{});
}

// ============================================================================
// TEST 9: State Tree Hash
// ============================================================================

test "VALIDATION 9: account state hash calculation" {
    // CRITICAL TEST: Does our merkle tree produce correct account_hash?
    //
    // Real ledger account_hash: A569ACFF4EB95A65B8FD3A9A7C0E68EE17A96EA051896A3F235863ED776ACBAE
    //
    // This is the merkle root of ALL account states in the ledger
    //
    // To test:
    // 1. Get all account states from ledger
    // 2. Build merkle tree
    // 3. Calculate root
    // 4. Compare to account_hash
    //
    // EXPECTED: Will probably NOT match
    // Merkle tree algorithm needs to match XRPL's exact implementation
    
    var real_account_hash: [32]u8 = undefined;
    try parseHex(TestData.account_hash_hex, &real_account_hash);
    
    std.debug.print("⚠️  VALIDATION 9: State hash NOT VALIDATED YET\n", .{});
    std.debug.print("   Real account_hash: {any}...\n", .{real_account_hash[0..8]});
    std.debug.print("   Need to: Build state tree and compare root\n", .{});
    std.debug.print("   Status: CRITICAL - Cannot validate state without this\n", .{});
}

// ============================================================================
// TEST 10: Network Protocol - Peer Connection
// ============================================================================

test "VALIDATION 10: can we connect to real testnet peer?" {
    // CRITICAL TEST: Can we actually talk to real XRPL nodes?
    //
    // Testnet peer: s.altnet.rippletest.net:51235
    //
    // To test:
    // 1. Attempt TCP connection
    // 2. Try to send handshake
    // 3. See if we get response
    //
    // EXPECTED: Will probably fail
    // We haven't implemented the full peer protocol
    
    std.debug.print("⚠️  VALIDATION 10: Peer connection NOT TESTED YET\n", .{});
    std.debug.print("   Testnet peer: s.altnet.rippletest.net:51235\n", .{});
    std.debug.print("   Need to: Implement peer handshake protocol\n", .{});
    std.debug.print("   Status: CRITICAL - Cannot join network without this\n", .{});
}

// ============================================================================
// TEST 11: RPC Response Format Matching
// ============================================================================

test "VALIDATION 11: server_info format matches rippled" {
    const allocator = std.testing.allocator;
    
    // Real testnet server_info has these fields:
    // - build_version, complete_ledgers, network_id, peers
    // - last_close: { converge_time_s, proposers }
    // - validated_ledger: { seq, hash, base_fee, reserve_base, reserve_inc }
    
    // Our current response is missing many of these
    
    std.debug.print("⚠️  VALIDATION 11: server_info format incomplete\n", .{});
    std.debug.print("   Missing fields:\n", .{});
    std.debug.print("   - network_id (critical!)\n", .{});
    std.debug.print("   - last_close details\n", .{});
    std.debug.print("   - reserve_base, reserve_inc\n", .{});
    std.debug.print("   - Many operational metrics\n", .{});
    std.debug.print("   Status: HIGH PRIORITY - API compatibility\n", .{});
}

// ============================================================================
// TEST 12: Fee Calculation
// ============================================================================

test "VALIDATION 12: fee calculation matches network" {
    // Testnet base fee: 10 drops
    // Our MIN_TX_FEE: 10 drops
    try std.testing.expectEqual(@as(types.Drops, 10), types.MIN_TX_FEE);
    
    // But real network has:
    // - base_fee, median_fee, open_ledger_fee (can differ)
    // - Fee scaling based on load
    // - Reference levels
    
    std.debug.print("✅ VALIDATION 12: Base fee matches testnet\n", .{});
    std.debug.print("⚠️  TODO: Implement dynamic fee calculation\n", .{});
}

// ============================================================================
// TEST 13: Transaction Type Coverage
// ============================================================================

test "VALIDATION 13: transaction type coverage" {
    // Real testnet uses these transaction types:
    // - Payment (we have ✅)
    // - AccountSet (we have ✅)
    // - TrustSet (we have ✅)
    // - OfferCreate/Cancel (we have ✅)
    // - SignerListSet (we DON'T have ❌)
    // - Payment channels (we have ✅)
    // - Escrow (we have ✅)
    // - Checks (we have ✅)
    // - NFTs (we have ✅)
    
    std.debug.print("✅ VALIDATION 13: Have 16/25 transaction types\n", .{});
    std.debug.print("🔴 MISSING CRITICAL:\n", .{});
    std.debug.print("   - SignerListSet (multi-sig required!)\n", .{});
    std.debug.print("   - AccountDelete\n", .{});
    std.debug.print("   - SetRegularKey\n", .{});
    std.debug.print("   - DepositPreauth\n", .{});
    std.debug.print("   Status: Need these before claiming feature complete\n", .{});
}

// ============================================================================
// TEST 14: Multi-Signature Support
// ============================================================================

test "VALIDATION 14: multi-signature transaction structure" {
    // Real multi-sig transaction has:
    // - SigningPubKey: "" (empty)
    // - Signers: [ { Signer: { Account, SigningPubKey, TxnSignature } } ]
    // - SignerQuorum: N
    //
    // Our Transaction struct:
    // - Has signing_pub_key: [33]u8 (can't be empty!)
    // - Has txn_signature: ?[]const u8
    // - NO Signers field
    
    std.debug.print("🔴 VALIDATION 14: Multi-sig NOT SUPPORTED\n", .{});
    std.debug.print("   Our struct needs:\n", .{});
    std.debug.print("   - signing_pub_key: ?[33]u8 (allow null)\n", .{});
    std.debug.print("   - signers: ?[]Signer (add array)\n", .{});
    std.debug.print("   Status: CRITICAL - Real testnet uses multi-sig!\n", .{});
}

// ============================================================================
// TEST 15: Close Time Format
// ============================================================================

test "VALIDATION 15: close time handling" {
    // Real ledger close_time: 815078240 (ripple epoch seconds)
    // Ripple epoch: January 1, 2000 00:00 UTC
    // Unix epoch: January 1, 1970 00:00 UTC
    // Difference: 946684800 seconds
    
    const ripple_epoch_offset: i64 = 946684800;
    const testnet_close_time: i64 = 815078240;
    const unix_time = testnet_close_time + ripple_epoch_offset;
    
    // Verify conversion makes sense
    // Should be October 29, 2025
    try std.testing.expect(unix_time > 1700000000); // After 2023
    try std.testing.expect(unix_time < 1800000000); // Before 2027
    
    std.debug.print("✅ VALIDATION 15: Close time epoch understood\n", .{});
    std.debug.print("   Ripple epoch time: {d}\n", .{testnet_close_time});
    std.debug.print("   Unix time: {d}\n", .{unix_time});
    std.debug.print("⚠️  TODO: Handle Ripple epoch in our code\n", .{});
}

// ============================================================================
// TEST 16: Total Coins Precision
// ============================================================================

test "VALIDATION 16: total coins precision" {
    // Real testnet: "99999914350172385" (string format)
    // This is: 99,999,914.350172385 XRP
    
    const real_total_str = "99999914350172385";
    const real_total = try std.fmt.parseInt(u64, real_total_str, 10);
    
    // Verify we can handle this precision
    try std.testing.expectEqual(@as(u64, 99999914350172385), real_total);
    
    // Verify it's less than max supply
    try std.testing.expect(real_total < types.MAX_XRP);
    
    std.debug.print("✅ VALIDATION 16: Can handle real total coins value\n", .{});
    std.debug.print("   Total XRP: {d}\n", .{real_total / types.XRP});
    std.debug.print("⚠️  TODO: Return as string in JSON responses\n", .{});
}

// ============================================================================
// TEST 17: Ledger Sequence Numbers
// ============================================================================

test "VALIDATION 17: ledger sequence number range" {
    // Real testnet is at ledger #11,900,686
    // Our code uses u32 for LedgerSequence
    // Max u32: 4,294,967,295
    
    // Verify we can handle current testnet height
    const testnet_height: u32 = 11900686;
    try std.testing.expect(testnet_height < std.math.maxInt(u32));
    
    // At ~4 second ledgers, u32 will last:
    // 4,294,967,295 ledgers × 4 seconds = 544 years
    
    std.debug.print("✅ VALIDATION 17: u32 ledger sequence sufficient\n", .{});
    std.debug.print("   Current testnet: {d}\n", .{testnet_height});
    std.debug.print("   Max capacity: {} ledgers (~544 years)\n", .{std.math.maxInt(u32)});
}

// ============================================================================
// TEST 18: Hash Function Correctness
// ============================================================================

test "VALIDATION 18: SHA-512 Half implementation" {
    // XRPL uses SHA-512 Half (first 256 bits of SHA-512)
    // Our implementation should match
    
    const test_data = "test";
    const our_hash = crypto.Hash.sha512Half(test_data);
    
    // Calculate expected (first 32 bytes of SHA-512)
    var full_hash: [64]u8 = undefined;
    std.crypto.hash.sha2.Sha512.hash(test_data, &full_hash, .{});
    
    // Compare our implementation
    try std.testing.expectEqualSlices(u8, full_hash[0..32], &our_hash);
    
    std.debug.print("✅ VALIDATION 18: SHA-512 Half implementation correct\n", .{});
}

// ============================================================================
// TEST 19: Account ID Derivation
// ============================================================================

test "VALIDATION 19: account ID derivation from public key" {
    // XRPL derives account IDs as:
    // AccountID = RIPEMD160(SHA256(public_key))
    //
    // Our implementation uses this formula
    // But RIPEMD-160 is stubbed with SHA-256 truncation
    
    const test_pubkey = [_]u8{0x02} ++ [_]u8{0xFF} ** 32; // 33 bytes
    const account_id = crypto.Hash.accountID(&test_pubkey);
    
    try std.testing.expectEqual(@as(usize, 20), account_id.len);
    
    std.debug.print("⚠️  VALIDATION 19: Account ID derivation INCOMPLETE\n", .{});
    std.debug.print("   Using: SHA-256 truncation (temporary)\n", .{});
    std.debug.print("   Need: Real RIPEMD-160 implementation\n", .{});
    std.debug.print("   Status: HIGH PRIORITY - Affects address generation\n", .{});
}

// ============================================================================
// TEST 20: Network ID Handling
// ============================================================================

test "VALIDATION 20: network ID support" {
    // Real XRPL uses network_id to distinguish:
    // - 0: Mainnet
    // - 1: Testnet
    // - 2+: Other networks
    //
    // This is CRITICAL for preventing replay attacks
    
    // Our config supports network_id
    // But needs to be used in transaction signing
    
    std.debug.print("⚠️  VALIDATION 20: network_id EXISTS but not integrated\n", .{});
    std.debug.print("   Mainnet: 0, Testnet: 1\n", .{});
    std.debug.print("   TODO: Include network_id in transaction signing\n", .{});
    std.debug.print("   Status: MEDIUM - Important for multi-network support\n", .{});
}

// ============================================================================
// VALIDATION SUMMARY
// ============================================================================

test "VALIDATION SUMMARY: print all results" {
    std.debug.print("\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("  PHASE 1 VALIDATION RESULTS\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n\n", .{});
    
    std.debug.print("✅ PASSING (5/20 tests):\n", .{});
    std.debug.print("   1. Hex parsing\n", .{});
    std.debug.print("   2. Real hash parsing\n", .{});
    std.debug.print("   3. Base58 round-trip\n", .{});
    std.debug.print("   12. Base fee matches\n", .{});
    std.debug.print("   18. SHA-512 Half correct\n\n", .{});
    
    std.debug.print("⚠️  IMPLEMENTED BUT NOT VALIDATED (10/20):\n", .{});
    std.debug.print("   4. Serialization (needs real tx test)\n", .{});
    std.debug.print("   5. Amount encoding (needs validation)\n", .{});
    std.debug.print("   6. Transaction hashing (CRITICAL - not tested)\n", .{});
    std.debug.print("   7. Signature verification (CRITICAL - not tested)\n", .{});
    std.debug.print("   8. Ledger hashing (CRITICAL - not tested)\n", .{});
    std.debug.print("   9. State tree hashing (CRITICAL - not tested)\n", .{});
    std.debug.print("   11. server_info format (incomplete)\n", .{});
    std.debug.print("   15. Close time epoch (needs handling)\n", .{});
    std.debug.print("   16. Total coins format (needs string)\n", .{});
    std.debug.print("   19. Account ID (RIPEMD-160 stubbed)\n\n", .{});
    
    std.debug.print("🔴 NOT IMPLEMENTED (5/20):\n", .{});
    std.debug.print("   10. Peer protocol (can't connect yet)\n", .{});
    std.debug.print("   13. Missing transaction types\n", .{});
    std.debug.print("   14. Multi-signature support\n", .{});
    std.debug.print("   17. Ledger sequence (ok but noted)\n", .{});
    std.debug.print("   20. Network ID integration\n\n", .{});
    
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("VALIDATION STATUS: 5/20 VERIFIED (25%%)\n", .{});
    std.debug.print("CRITICAL TESTS REMAINING: 4 (hashing, signatures)\n", .{});
    std.debug.print("LAUNCH READINESS: NOT YET - CONTINUE VALIDATION\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n\n", .{});
}

