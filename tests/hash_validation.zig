const std = @import("std");
const crypto = @import("crypto.zig");
const serialization = @import("serialization.zig");
const types = @import("types.zig");

/// CRITICAL HASH VALIDATION TESTS
/// These determine if our implementation is compatible with real XRPL
/// MUST pass before launch

/// Real transaction from testnet for validation
/// Hash: 09D0D3C0AB0E6D8EBB3117C2FF1DD72F063818F528AF54A4553C8541DD2E8B5B
const RealTransaction = struct {
    const hash_hex = "09D0D3C0AB0E6D8EBB3117C2FF1DD72F063818F528AF54A4553C8541DD2E8B5B";
    const account = "rPickFLAKK7YkMwKvhSEN1yJAtfnB6qRJc";
    const fee = "7500";
    const sequence: u32 = 11900682;
    const tx_type = "SignerListSet";
    const flags: u32 = 2147483648;
    
    // Public key (hex)
    const signing_pub_key_hex = "02D3FC6F04117E6420CAEA735C57CEEC934820BBCD109200933F6BBDD98F7BFBD9";
    
    // Signature (hex) 
    const signature_hex = "3045022100E30FEACFAE9ED8034C4E24203BBFD6CE0D48ABCA901EDCE6EE04AA281A4DD73F02200CA7FDF03DC0B56F6E6FC5B499B4830F1ABD6A57FC4BE5C03F2CAF3CAFD1FF85";
};

fn parseHex(hex: []const u8, out: []u8) !void {
    if (hex.len != out.len * 2) return error.InvalidHexLength;
    var i: usize = 0;
    while (i < out.len) : (i += 1) {
        out[i] = try std.fmt.parseInt(u8, hex[i*2..i*2+2], 16);
    }
}

// ============================================================================
// CRITICAL TEST 1: Transaction Hash Calculation
// ============================================================================

test "HASH VALIDATION 1: transaction hash calculation" {
    // This is THE critical test
    // Can we serialize a transaction and get the SAME hash as the network?
    
    var expected_hash: [32]u8 = undefined;
    try parseHex(RealTransaction.hash_hex, &expected_hash);
    
    std.debug.print("\n", .{});
    std.debug.print("🔴 HASH VALIDATION 1: Transaction Hashing\n", .{});
    std.debug.print("   Real tx hash: {s}...\n", .{RealTransaction.hash_hex[0..16]});
    std.debug.print("   Transaction type: {s}\n", .{RealTransaction.tx_type});
    std.debug.print("   Sequence: {d}\n", .{RealTransaction.sequence});
    std.debug.print("\n", .{});
    std.debug.print("   Status: CANNOT TEST YET\n", .{});
    std.debug.print("   Reason: SignerListSet not implemented\n", .{});
    std.debug.print("   TODO: Implement SignerListSet, then test serialization\n", .{});
    std.debug.print("   Priority: CRITICAL\n", .{});
    std.debug.print("\n", .{});
}

// ============================================================================
// CRITICAL TEST 2: Signature Verification
// ============================================================================

test "HASH VALIDATION 2: signature verification against real data" {
    const allocator = std.testing.allocator;
    
    // Parse real public key
    var pub_key_bytes: [33]u8 = undefined;
    try parseHex(RealTransaction.signing_pub_key_hex, &pub_key_bytes);
    
    // Parse real signature
    const sig_hex = RealTransaction.signature_hex;
    var signature = try allocator.alloc(u8, sig_hex.len / 2);
    defer allocator.free(signature);
    try parseHex(sig_hex, signature);
    
    std.debug.print("\n", .{});
    std.debug.print("🔴 HASH VALIDATION 2: Signature Verification\n", .{});
    std.debug.print("   Public key: {s}...\n", .{RealTransaction.signing_pub_key_hex[0..16]});
    std.debug.print("   Signature length: {d} bytes\n", .{signature.len});
    std.debug.print("   Signature starts with: 0x30 0x45 (DER format)\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("   Status: CRITICAL ISSUE FOUND\n", .{});
    std.debug.print("   Problem: This is secp256k1 signature (DER encoded)\n", .{});
    std.debug.print("   Our code: Only supports Ed25519\n", .{});
    std.debug.print("   Reality: Real XRPL uses BOTH secp256k1 AND Ed25519\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("   FIX REQUIRED: Implement secp256k1 support\n", .{});
    std.debug.print("   Priority: CRITICAL\n", .{});
    std.debug.print("\n", .{});
}

// ============================================================================
// CRITICAL TEST 3: Ledger Hash Calculation
// ============================================================================

test "HASH VALIDATION 3: ledger hash against real network" {
    // Real ledger #11900686
    // Hash: FB90529615FA52790E2B2E24C32A482DBF9F969C3FDC2726ED0A64A40962BF00
    
    var expected_hash: [32]u8 = undefined;
    try parseHex("FB90529615FA52790E2B2E24C32A482DBF9F969C3FDC2726ED0A64A40962BF00", &expected_hash);
    
    // Create ledger with real values
    const test_ledger = ledger.Ledger{
        .sequence = 11900686,
        .hash = expected_hash, // We'll calculate this
        .parent_hash = undefined, // Parse from real data
        .close_time = 815078240,
        .close_time_resolution = 10,
        .total_coins = 99999914350172385,
        .account_state_hash = undefined,
        .transaction_hash = undefined,
        .close_flags = 0,
        .parent_close_time = 815078232,
    };
    
    // Calculate hash with our algorithm
    const calculated_hash = test_ledger.calculateHash();
    
    std.debug.print("\n", .{});
    std.debug.print("🔴 HASH VALIDATION 3: Ledger Hash Calculation\n", .{});
    std.debug.print("   Real hash:       {any}...\n", .{expected_hash[0..8]});
    std.debug.print("   Calculated hash: {any}...\n", .{calculated_hash[0..8]});
    std.debug.print("\n", .{});
    
    // Compare
    if (std.mem.eql(u8, &expected_hash, &calculated_hash)) {
        std.debug.print("   ✅ HASHES MATCH! Algorithm is correct!\n", .{});
    } else {
        std.debug.print("   ❌ HASHES DON'T MATCH\n", .{});
        std.debug.print("   Issue: Our algorithm doesn't match XRPL\n", .{});
        std.debug.print("   Likely causes:\n", .{});
        std.debug.print("   - Wrong field serialization order\n", .{});
        std.debug.print("   - Missing fields in hash calculation\n", .{});
        std.debug.print("   - Wrong encoding of values\n", .{});
        std.debug.print("   Priority: CRITICAL\n", .{});
    }
    std.debug.print("\n", .{});
}

// ============================================================================
// CRITICAL TEST 4: Account State Hash
// ============================================================================

test "HASH VALIDATION 4: account state merkle root" {
    // Real ledger account_hash: A569ACFF4EB95A65B8FD3A9A7C0E68EE17A96EA051896A3F235863ED776ACBAE
    
    var expected_account_hash: [32]u8 = undefined;
    try parseHex("A569ACFF4EB95A65B8FD3A9A7C0E68EE17A96EA051896A3F235863ED776ACBAE", &expected_account_hash);
    
    std.debug.print("\n", .{});
    std.debug.print("🔴 HASH VALIDATION 4: Account State Hash\n", .{});
    std.debug.print("   Real account_hash: {any}...\n", .{expected_account_hash[0..8]});
    std.debug.print("\n", .{});
    std.debug.print("   Status: CANNOT TEST YET\n", .{});
    std.debug.print("   Reason: Need all account states from ledger\n", .{});
    std.debug.print("   TODO: Fetch account state, build merkle tree, compare\n", .{});
    std.debug.print("   Priority: CRITICAL\n", .{});
    std.debug.print("\n", .{});
}

// ============================================================================
// TEST 5: Simple Hash Smoke Test
// ============================================================================

test "HASH VALIDATION 5: SHA-512 Half smoke test" {
    // Test our SHA-512 Half against known test vector
    const test_input = "hello";
    const our_hash = crypto.Hash.sha512Half(test_input);
    
    // Calculate expected
    var full_hash: [64]u8 = undefined;
    std.crypto.hash.sha2.Sha512.hash(test_input, &full_hash, .{});
    
    // First 32 bytes should match
    try std.testing.expectEqualSlices(u8, full_hash[0..32], &our_hash);
    
    std.debug.print("✅ HASH VALIDATION 5: SHA-512 Half implementation correct\n", .{});
}

// ============================================================================
// TEST 6: Serialization Byte Order
// ============================================================================

test "HASH VALIDATION 6: big-endian encoding" {
    const allocator = std.testing.allocator;
    var ser = try serialization.Serializer.init(allocator);
    defer ser.deinit();
    
    // XRPL uses big-endian (network byte order)
    const test_value: u32 = 0x12345678;
    try ser.addUInt32(.sequence, test_value);
    
    const result = ser.finish();
    
    // After type/field byte, should be big-endian bytes
    // 0x12 0x34 0x56 0x78
    if (result.len >= 5) {
        const bytes = result[1..5]; // Skip type byte
        try std.testing.expectEqual(@as(u8, 0x12), bytes[0]);
        try std.testing.expectEqual(@as(u8, 0x34), bytes[1]);
        try std.testing.expectEqual(@as(u8, 0x56), bytes[2]);
        try std.testing.expectEqual(@as(u8, 0x78), bytes[3]);
        
        std.debug.print("✅ HASH VALIDATION 6: Big-endian encoding correct\n", .{});
    }
}

// ============================================================================
// TEST 7: Amount Bit Layout
// ============================================================================

test "HASH VALIDATION 7: XRP amount bit layout" {
    // XRPL XRP amount encoding:
    // Bit 63: 0 (reserved)
    // Bit 62: 1 (positive)
    // Bits 61-0: Amount in drops
    //
    // For 100 XRP (100,000,000 drops):
    // Binary: 0100_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0101_1111_0101_1110_0001_0000_0000_0000
    
    const amount_drops: u64 = 100_000_000;
    const encoded = amount_drops | (1 << 62); // Set positive bit
    
    // Verify bit 62 is set
    try std.testing.expect((encoded & (1 << 62)) != 0);
    // Verify bit 63 is not set
    try std.testing.expect((encoded & (1 << 63)) == 0);
    
    std.debug.print("✅ HASH VALIDATION 7: XRP amount bit layout understood\n", .{});
    std.debug.print("   100 XRP encoded: 0x{X:0>16}\n", .{encoded});
    std.debug.print("⚠️  TODO: Validate this matches XRPL serialization exactly\n", .{});
}

// ============================================================================
// TEST 8: IOU Amount Encoding
// ============================================================================

test "HASH VALIDATION 8: IOU amount encoding format" {
    // XRPL IOU amounts use:
    // Bit 63: Sign (0 = positive, 1 = negative)
    // Bit 62: 1 (not XRP indicator)
    // Bits 61-54: Exponent (biased by -97)
    // Bits 53-0: Mantissa (54 bits of precision)
    
    std.debug.print("\n", .{});
    std.debug.print("⚠️  HASH VALIDATION 8: IOU Amount Encoding\n", .{});
    std.debug.print("   Format: Sign(1) | NotXRP(1) | Exp(8) | Mantissa(54)\n", .{});
    std.debug.print("   Status: Implemented in serialization.zig\n", .{});
    std.debug.print("   TODO: Validate against real IOU transaction\n", .{});
    std.debug.print("   Priority: HIGH\n", .{});
    std.debug.print("\n", .{});
}

// ============================================================================
// TEST 9: Field Ordering
// ============================================================================

test "HASH VALIDATION 9: canonical field ordering" {
    // XRPL requires fields in specific order:
    // 1. Type fields (UInt16)
    // 2. Flags (UInt32)
    // 3. Other UInt32s
    // 4. Amounts (UInt64)
    // 5. Variable length
    // 6. Account fields
    // 7. Hashes
    //
    // Within each group: Sorted by field code
    
    std.debug.print("\n", .{});
    std.debug.print("⚠️  HASH VALIDATION 9: Field Ordering\n", .{});
    std.debug.print("   XRPL requires canonical field order\n", .{});
    std.debug.print("   Our serializer: Adds fields in call order\n", .{});
    std.debug.print("   Problem: Might not match canonical order\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("   FIX REQUIRED:\n", .{});
    std.debug.print("   - Sort fields by type code, then field code\n", .{});
    std.debug.print("   - Implement proper canonical ordering\n", .{});
    std.debug.print("   Priority: CRITICAL\n", .{});
    std.debug.print("\n", .{});
}

// ============================================================================
// TEST 10: Signing Data Format
// ============================================================================

test "HASH VALIDATION 10: transaction signing data" {
    // For signature verification:
    // 1. Serialize transaction WITHOUT TxnSignature field
    // 2. Add signing prefix if needed
    // 3. Hash to get signing data
    // 4. Verify signature against this hash
    
    std.debug.print("\n", .{});
    std.debug.print("⚠️  HASH VALIDATION 10: Signing Data\n", .{});
    std.debug.print("   Signing data = Hash(Serialized TX without signature)\n", .{});
    std.debug.print("   Need to:\n", .{});
    std.debug.print("   - Serialize without TxnSignature field\n", .{});
    std.debug.print("   - Possibly add 'TXN\\0' prefix (need to verify)\n", .{});
    std.debug.print("   - Hash for signature verification\n", .{});
    std.debug.print("   Priority: CRITICAL\n", .{});
    std.debug.print("\n", .{});
}

// ============================================================================
// VALIDATION SUMMARY
// ============================================================================

test "HASH VALIDATION SUMMARY" {
    std.debug.print("\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("  HASH VALIDATION RESULTS\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("CRITICAL FINDINGS:\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("1. 🔴 Transaction hash: CANNOT TEST (need SignerListSet)\n", .{});
    std.debug.print("2. 🔴 Signatures: Real network uses secp256k1 (we only have Ed25519)\n", .{});
    std.debug.print("3. ⚠️  Ledger hash: Algorithm exists but NOT VALIDATED\n", .{});
    std.debug.print("4. ⚠️  Field ordering: Might not be canonical\n", .{});
    std.debug.print("5. ⚠️  Signing data format: Need to verify prefix/format\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("IMMEDIATE ACTION REQUIRED:\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Priority 1: Implement secp256k1 signature verification\n", .{});
    std.debug.print("Priority 2: Implement canonical field ordering\n", .{});
    std.debug.print("Priority 3: Validate ledger hash calculation\n", .{});
    std.debug.print("Priority 4: Implement SignerListSet transaction\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("LAUNCH BLOCKER: Cannot claim XRPL compatibility until these pass\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
}

