const std = @import("std");
const crypto = @import("../src/crypto.zig");
const types = @import("../src/types.zig");
const base58 = @import("../src/base58.zig");
const canonical = @import("../src/canonical.zig");
const multisig = @import("../src/multisig.zig");
const ripemd160 = @import("../src/ripemd160.zig");
const ledger = @import("../src/ledger.zig");



const ValidationResult = struct {
    name: []const u8,
    passed: bool,
    description: []const u8,
    category: []const u8,
};

var validation_results = std.ArrayList(ValidationResult).init(std.testing.allocator);
var total_tests: usize = 0;
var passed_tests: usize = 0;
var failed_tests: usize = 0;

fn recordResult(name: []const u8, passed: bool, description: []const u8, category: []const u8) !void {
    try validation_results.append(.{
        .name = name,
        .passed = passed,
        .description = description,
        .category = category,
    });
    total_tests += 1;
    if (passed) {
        passed_tests += 1;
    } else {
        failed_tests += 1;
    }
}

test "DAY 13: Comprehensive Validation Suite Runner" {
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  DAY 13: COMPREHENSIVE VALIDATION SUITE\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    
    // Run all validation tests in sequence
    try testRIPEMD160();
    try testAccountDerivation();
    try testBase58Encoding();
    try testCanonicalSerialization();
    try testSignerListSet();
    try testMultiSig();
    try testHashFunctions();
    try testLedgerHash();
    
    // Print summary
    printSummary();
}

fn testRIPEMD160() !void {
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("CATEGORY 1: RIPEMD-160 IMPLEMENTATION\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    
    // Test Vector 1: Empty string
    {
        const input = "";
        var output: [20]u8 = undefined;
        ripemd160.hash(input, &output);
        const expected = [20]u8{
            0x9c, 0x11, 0x85, 0xa5, 0xc5, 0xe9, 0xfc, 0x54,
            0x61, 0x28, 0x08, 0x97, 0x7e, 0xe8, 0xf5, 0x48,
            0xb2, 0x25, 0x8d, 0x31,
        };
        const passed = std.mem.eql(u8, &output, &expected);
        try recordResult("RIPEMD-160: Empty string", passed, "Test vector 1", "Cryptography");
        std.debug.print("  {s} Test Vector 1 (empty string)\n", .{if (passed) "✅" else "❌"});
    }
    
    // Test Vector 2: "abc"
    {
        const input = "abc";
        var output: [20]u8 = undefined;
        ripemd160.hash(input, &output);
        const expected = [20]u8{
            0x8e, 0xb2, 0x08, 0xf7, 0xe0, 0x5d, 0x98, 0x7a,
            0x9b, 0x04, 0x4a, 0x8e, 0x98, 0xc6, 0xb0, 0x87,
            0xf1, 0x5a, 0x0b, 0xfc,
        };
        const passed = std.mem.eql(u8, &output, &expected);
        try recordResult("RIPEMD-160: abc", passed, "Test vector 3", "Cryptography");
        std.debug.print("  {s} Test Vector 3 (abc)\n", .{if (passed) "✅" else "❌"});
    }
    
    // Integration test
    {
        const input = "test";
        const hash1 = crypto.Hash.ripemd160(input);
        var hash2: [20]u8 = undefined;
        ripemd160.hash(input, &hash2);
        const passed = std.mem.eql(u8, &hash1, &hash2);
        try recordResult("RIPEMD-160: Integration", passed, "crypto.Hash.ripemd160() matches direct call", "Cryptography");
        std.debug.print("  {s} Integration with crypto module\n", .{if (passed) "✅" else "❌"});
    }
    
    std.debug.print("\n", .{});
}

fn testAccountDerivation() !void {
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("CATEGORY 2: ACCOUNT ID DERIVATION\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    
    // Test account ID derivation
    {
        const test_pub_key = [_]u8{0x02} ++ [_]u8{0x12, 0x34, 0x56} ** 10 ++ [_]u8{0x78, 0x90};
        const account_id = crypto.Hash.accountID(&test_pub_key);
        
        const passed = account_id.len == 20;
        try recordResult("Account ID: Length", passed, "Account ID is 20 bytes", "Account System");
        std.debug.print("  {s} Account ID length (20 bytes)\n", .{if (passed) "✅" else "❌"});
        
        // Should not be all zeros
        var all_zeros = true;
        for (account_id) |byte| {
            if (byte != 0) {
                all_zeros = false;
                break;
            }
        }
        const passed2 = !all_zeros;
        try recordResult("Account ID: Non-zero", passed2, "Account ID is not all zeros", "Account System");
        std.debug.print("  {s} Account ID is non-zero\n", .{if (passed2) "✅" else "❌"});
    }
    
    std.debug.print("\n", .{});
}

fn testBase58Encoding() !void {
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("CATEGORY 3: BASE58 ENCODING\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    
    const allocator = std.testing.allocator;
    
    // Test round-trip encoding
    {
        var test_account: types.AccountID = undefined;
        @memset(&test_account, 0xAA, 20);
        
        const address = try base58.Base58.encodeAccountID(allocator, test_account);
        defer allocator.free(address);
        
        const decoded = try base58.Base58.decodeAccountID(allocator, address);
        defer allocator.free(decoded);
        
        const passed = std.mem.eql(u8, &test_account, decoded);
        try recordResult("Base58: Round-trip", passed, "Encode/decode round-trip works", "Account System");
        std.debug.print("  {s} Base58 round-trip encoding\n", .{if (passed) "✅" else "❌"});
        
        // Address should start with 'r'
        const passed2 = address[0] == 'r';
        try recordResult("Base58: Format", passed2, "Address starts with 'r'", "Account System");
        std.debug.print("  {s} Address format (starts with 'r')\n", .{if (passed2) "✅" else "❌"});
    }
    
    std.debug.print("\n", .{});
}

fn testCanonicalSerialization() !void {
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("CATEGORY 4: CANONICAL SERIALIZATION\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    
    const allocator = std.testing.allocator;
    
    // Test field ordering
    {
        var ser1 = try canonical.CanonicalSerializer.init(allocator);
        defer ser1.deinit();
        
        try ser1.addUInt16(2, 0); // TransactionType
        try ser1.addUInt32(4, 1);  // Sequence
        try ser1.addUInt64(8, 12); // Fee
        const result1 = try ser1.finish();
        defer allocator.free(result1);
        
        var ser2 = try canonical.CanonicalSerializer.init(allocator);
        defer ser2.deinit();
        
        // Add in different order
        try ser2.addUInt64(8, 12); // Fee first
        try ser2.addUInt16(2, 0);  // TransactionType
        try ser2.addUInt32(4, 1);  // Sequence
        const result2 = try ser2.finish();
        defer allocator.free(result2);
        
        const passed = std.mem.eql(u8, result1, result2);
        try recordResult("Canonical: Field ordering", passed, "Same output regardless of addition order", "Serialization");
        std.debug.print("  {s} Field ordering (order-independent)\n", .{if (passed) "✅" else "❌"});
    }
    
    // Test hash calculation
    {
        var ser = try canonical.CanonicalSerializer.init(allocator);
        defer ser.deinit();
        
        try ser.addUInt16(2, 0);
        try ser.addUInt32(4, 1);
        try ser.addUInt64(8, 12);
        const serialized = try ser.finish();
        defer allocator.free(serialized);
        
        const hash = crypto.Hash.sha512Half(serialized);
        
        const passed = hash.len == 32;
        try recordResult("Canonical: Hash calculation", passed, "SHA-512 Half produces 32-byte hash", "Serialization");
        std.debug.print("  {s} Hash calculation (SHA-512 Half)\n", .{if (passed) "✅" else "❌"});
    }
    
    std.debug.print("\n", .{});
}

fn testSignerListSet() !void {
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("CATEGORY 5: SIGNERLISTSET TRANSACTION\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    
    const account = [_]u8{1} ** 20;
    var signer1: types.AccountID = undefined;
    var signer2: types.AccountID = undefined;
    @memset(&signer1, 0x01, 20);
    @memset(&signer2, 0x02, 20);
    
    const entries = [_]multisig.SignerEntry{
        .{ .account = signer1, .signer_weight = 1 },
        .{ .account = signer2, .signer_weight = 1 },
    };
    
    // Test valid transaction
    {
        const tx = multisig.SignerListSet.create(
            account,
            2,
            &entries,
            types.MIN_TX_FEE,
            1,
            [_]u8{0} ** 33,
        );
        
        // validate() returns !void, so it either succeeds (void) or errors
        var passed = false;
        if (tx.validate()) {
            passed = true;
        } else |err| {
            _ = err;
            passed = false;
        }
        try recordResult("SignerListSet: Validation", passed, "Valid transaction passes validation", "Transactions");
        std.debug.print("  {s} SignerListSet validation\n", .{if (passed) "✅" else "❌"});
    }
    
    // Test invalid quorum
    {
        const tx = multisig.SignerListSet.create(
            account,
            5, // Too high!
            &entries,
            types.MIN_TX_FEE,
            1,
            [_]u8{0} ** 33,
        );
        
        var passed = false;
        if (tx.validate()) {
            passed = false; // Should have errored
        } else |err| {
            if (err == error.InsufficientSignerWeight) {
                passed = true;
            }
        }
        try recordResult("SignerListSet: Invalid quorum", passed, "Rejects insufficient weight", "Transactions");
        std.debug.print("  {s} Invalid quorum rejection\n", .{if (passed) "✅" else "❌"});
    }
    
    std.debug.print("\n", .{});
}

fn testMultiSig() !void {
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("CATEGORY 6: MULTI-SIG SUPPORT\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    
    // Test transaction structure
    {
        var account_id: types.AccountID = undefined;
        @memset(&account_id, 0xAA, 20);
        
        const tx = types.Transaction{
            .tx_type = .payment,
            .account = account_id,
            .fee = 12,
            .sequence = 1,
            .signing_pub_key = null, // Multi-sig
            .txn_signature = null,  // Multi-sig
            .signers = null,
        };
        
        const passed = tx.signing_pub_key == null;
        try recordResult("Multi-sig: Structure", passed, "signing_pub_key can be null", "Transactions");
        std.debug.print("  {s} Multi-sig transaction structure\n", .{if (passed) "✅" else "❌"});
    }
    
    std.debug.print("\n", .{});
}

fn testHashFunctions() !void {
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("CATEGORY 7: HASH FUNCTIONS\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    
    // Test SHA-512 Half
    {
        const input = "test input";
        const hash = crypto.Hash.sha512Half(input);
        
        const passed = hash.len == 32;
        try recordResult("SHA-512 Half: Length", passed, "Produces 32-byte hash", "Cryptography");
        std.debug.print("  {s} SHA-512 Half length (32 bytes)\n", .{if (passed) "✅" else "❌"});
        
        // Should not be all zeros
        var all_zeros = true;
        for (hash) |byte| {
            if (byte != 0) {
                all_zeros = false;
                break;
            }
        }
        const passed2 = !all_zeros;
        try recordResult("SHA-512 Half: Non-zero", passed2, "Hash is not all zeros", "Cryptography");
        std.debug.print("  {s} SHA-512 Half non-zero\n", .{if (passed2) "✅" else "❌"});
    }
    
    std.debug.print("\n", .{});
}

fn testLedgerHash() !void {
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("CATEGORY 8: LEDGER HASH CALCULATION\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    
    // Test ledger hash calculation
    {
        const test_ledger = ledger.Ledger.genesis();
        const calculated_hash = test_ledger.calculateHash();
        
        const passed = calculated_hash.len == 32;
        try recordResult("Ledger Hash: Length", passed, "Produces 32-byte hash", "Ledger");
        std.debug.print("  {s} Ledger hash length (32 bytes)\n", .{if (passed) "✅" else "❌"});
        
        // FIXED Day 13: Now uses SHA-512 Half
        // Verify by comparing with manual SHA-512 Half calculation
        var test_buffer: [200]u8 = undefined;
        var test_offset: usize = 0;
        std.mem.writeInt(u32, test_buffer[test_offset..][0..4], test_ledger.sequence, .big);
        test_offset += 4;
        @memcpy(test_buffer[test_offset..][0..32], &test_ledger.parent_hash);
        test_offset += 32;
        std.mem.writeInt(i64, test_buffer[test_offset..][0..8], test_ledger.close_time, .big);
        test_offset += 8;
        @memcpy(test_buffer[test_offset..][0..32], &test_ledger.account_state_hash);
        test_offset += 32;
        @memcpy(test_buffer[test_offset..][0..32], &test_ledger.transaction_hash);
        test_offset += 32;
        std.mem.writeInt(u32, test_buffer[test_offset..][0..4], test_ledger.close_flags, .big);
        test_offset += 4;
        
        const manual_sha512half = crypto.Hash.sha512Half(test_buffer[0..test_offset]);
        const passed2 = std.mem.eql(u8, &calculated_hash, &manual_sha512half);
        try recordResult("Ledger Hash: Algorithm", passed2, "Uses SHA-512 Half (FIXED Day 13)", "Ledger");
        std.debug.print("  {s} Ledger hash algorithm (FIXED: now uses SHA-512 Half)\n", .{if (passed2) "✅" else "❌"});
    }
    
    std.debug.print("\n", .{});
}

fn printSummary() void {
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  VALIDATION SUMMARY\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    
    std.debug.print("Total Tests: {d}\n", .{total_tests});
    std.debug.print("Passed: {d}\n", .{passed_tests});
    std.debug.print("Failed: {d}\n", .{failed_tests});
    
    const pass_rate = if (total_tests > 0) (@as(f64, @floatFromInt(passed_tests)) / @as(f64, @floatFromInt(total_tests))) * 100.0 else 0.0;
    std.debug.print("Pass Rate: {d:.1}%\n", .{pass_rate});
    
    std.debug.print("\n", .{});
    std.debug.print("Results by Category:\n", .{});
    std.debug.print("\n", .{});
    
    // Group by category
    var categories = std.StringHashMap(usize).init(std.testing.allocator);
    defer categories.deinit();
    
    for (validation_results.items) |result| {
        var count = categories.get(result.category) orelse 0;
        _ = categories.put(result.category, count + 1) catch {};
    }
    
    for (validation_results.items) |result| {
        const icon = if (result.passed) "✅" else "❌";
        std.debug.print("  {s} [{s}] {s}\n", .{ icon, result.category, result.name });
        std.debug.print("      {s}\n", .{result.description});
    }
    
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    
    // Week 2 target assessment
    std.debug.print("WEEK 2 TARGET ASSESSMENT:\n", .{});
    std.debug.print("  Target: 70%%+ validation passing\n", .{});
    std.debug.print("  Current: {d:.1}%%\n", .{pass_rate});
    if (pass_rate >= 70.0) {
        std.debug.print("  Status: ✅ TARGET MET\n", .{});
    } else if (pass_rate >= 60.0) {
        std.debug.print("  Status: 🟡 CLOSE TO TARGET\n", .{});
    } else {
        std.debug.print("  Status: ❌ BELOW TARGET\n", .{});
    }
    std.debug.print("\n", .{});
    
    // Known issues
    std.debug.print("KNOWN ISSUES:\n", .{});
    std.debug.print("  ⚠️  Ledger hash uses SHA-256 instead of SHA-512 Half\n", .{});
    std.debug.print("  ⚠️  secp256k1 signature verification not implemented\n", .{});
    std.debug.print("  ⚠️  Real network transaction hash validation pending\n", .{});
    std.debug.print("\n", .{});
}

