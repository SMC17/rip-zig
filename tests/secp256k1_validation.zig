const std = @import("std");
const crypto = @import("../src/crypto.zig");
const secp = @import("../src/secp256k1.zig");

test "secp256k1 binding integration" {
    // Test that secp256k1 binding can be called
    // This will fail if libsecp256k1 is not installed
    std.debug.print("[TEST] secp256k1 binding integration\n", .{});

    // Initialize binding
    const binding = @import("../src/secp256k1_binding.zig");
    binding.init() catch |err| {
        std.debug.print("[WARN] Could not initialize secp256k1: {}\n", .{err});
        std.debug.print("[WARN] Install libsecp256k1: brew install secp256k1\n", .{});
        return error.SkipZigTest; // Skip if library not available
    };
    defer binding.deinit();

    std.debug.print("[PASS] secp256k1 context initialized\n", .{});
}

test "secp256k1 DER signature parsing" {
    // Real signature from XRPL testnet transaction
    // Signature: 3045022100E30FEACFAE9ED8034C4E24203BBFD6CE0D48ABCA901EDCE6EE04AA281A4DD73F02200CA7FDF03DC0B56F6E6FC5B499B4830F1ABD6A57FC4BE5C03F2CAF3CAFD1FF85

    const sig_hex = "3045022100E30FEACFAE9ED8034C4E24203BBFD6CE0D48ABCA901EDCE6EE04AA281A4DD73F02200CA7FDF03DC0B56F6E6FC5B499B4830F1ABD6A57FC4BE5C03F2CAF3CAFD1FF85";

    var signature: [71]u8 = undefined;
    _ = try std.fmt.hexToBytes(&signature, sig_hex);

    // Parse DER signature
    const parsed = try secp.parseDERSignature(&signature);

    try std.testing.expect(parsed.r.len == 32);
    try std.testing.expect(parsed.s.len == 32);

    std.debug.print("[PASS] DER signature parsing works\n", .{});
    std.debug.print("   r: {s}...\n", .{std.fmt.fmtSliceHexLower(parsed.r[0..8])});
    std.debug.print("   s: {s}...\n", .{std.fmt.fmtSliceHexLower(parsed.s[0..8])});
}

test "secp256k1 signature verification framework" {
    // Test with real transaction data from testnet
    // Public Key: 02D3FC6F04117E6420CAEA735C57CEEC934820BBCD109200933F6BBDD98F7BFBD9
    // Signature: 3045022100E30FEACFAE9ED8034C4E24203BBFD6CE0D48ABCA901EDCE6EE04AA281A4DD73F02200CA7FDF03DC0B56F6E6FC5B499B4830F1ABD6A57FC4BE5C03F2CAF3CAFD1FF85
    // Message hash would be SHA-512 Half of canonical transaction

    const pub_key_hex = "02D3FC6F04117E6420CAEA735C57CEEC934820BBCD109200933F6BBDD98F7BFBD9";
    const sig_hex = "3045022100E30FEACFAE9ED8034C4E24203BBFD6CE0D48ABCA901EDCE6EE04AA281A4DD73F02200CA7FDF03DC0B56F6E6FC5B499B4830F1ABD6A57FC4BE5C03F2CAF3CAFD1FF85";

    var pub_key: [33]u8 = undefined;
    _ = try std.fmt.hexToBytes(&pub_key, pub_key_hex);

    var signature: [71]u8 = undefined;
    _ = try std.fmt.hexToBytes(&signature, sig_hex);

    // Create a test message hash (32 bytes)
    // In real XRPL, this would be SHA-512 Half of canonical transaction
    const test_message = "test message for verification";
    var message_hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(test_message, &message_hash, .{});

    // Try to verify (will work if libsecp256k1 is properly linked)
    const result = secp.verifySignature(&pub_key, &message_hash, &signature) catch |err| {
        // If library not available, skip test
        if (err == error.ContextCreationFailed) {
            std.debug.print("[WARN] secp256k1 library not available - skipping verification test\n", .{});
            return error.SkipZigTest;
        }
        return err;
    };

    std.debug.print("[INFO] Signature verification attempted (result: {})\n", .{result});
    std.debug.print("[INFO] Note: This test uses synthetic data - real verification needs actual tx hash\n", .{});
}

test "crypto module secp256k1 integration" {
    // Test that crypto.zig can verify secp256k1 signatures
    const pub_key_hex = "02D3FC6F04117E6420CAEA735C57CEEC934820BBCD109200933F6BBDD98F7BFBD9";
    const sig_hex = "3045022100E30FEACFAE9ED8034C4E24203BBFD6CE0D48ABCA901EDCE6EE04AA281A4DD73F02200CA7FDF03DC0B56F6E6FC5B499B4830F1ABD6A57FC4BE5C03F2CAF3CAFD1FF85";

    var pub_key: [33]u8 = undefined;
    _ = try std.fmt.hexToBytes(&pub_key, pub_key_hex);

    var signature: [71]u8 = undefined;
    _ = try std.fmt.hexToBytes(&signature, sig_hex);

    const test_message = "test message";
    var message_hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(test_message, &message_hash, .{});

    const result = crypto.KeyPair.verify(&pub_key, &message_hash, &signature, .secp256k1) catch |err| {
        if (err == error.ContextCreationFailed) {
            std.debug.print("[WARN] secp256k1 library not available\n", .{});
            return error.SkipZigTest;
        }
        return err;
    };

    std.debug.print("[INFO] crypto.KeyPair.verify(secp256k1) called successfully\n", .{});
    std.debug.print("[INFO] Result: {}\n", .{result});
}

test "verify real testnet signatures" {
    std.debug.print("[INFO] Real testnet signature verification\n", .{});
    std.debug.print("[INFO] This test requires:\n", .{});
    std.debug.print("[INFO] 1. Network access to fetch testnet transactions\n", .{});
    std.debug.print("[INFO] 2. Proper transaction deserialization\n", .{});
    std.debug.print("[INFO] 3. Canonical serialization to reconstruct signing data\n", .{});
    std.debug.print("[INFO] Status: Framework ready, integration pending\n", .{});

    // TODO: Implement real testnet transaction fetching
    // TODO: Parse transaction JSON/binary format
    // TODO: Extract SigningPubKey and TxnSignature
    // TODO: Reconstruct canonical transaction (without signature fields)
    // TODO: Hash with SHA-512 Half
    // TODO: Verify signature with secp256k1
}
