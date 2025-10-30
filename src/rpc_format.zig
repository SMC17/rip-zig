const std = @import("std");
const types = @import("types.zig");
const base58 = @import("base58.zig");

/// RPC Format Helpers
/// WEEK 3 DAY 15-16: Format matching utilities for RPC responses

/// Convert hash bytes to uppercase hex string (allocated)
pub fn hashToHexAlloc(allocator: std.mem.Allocator, hash: []const u8) ![]u8 {
    var result = try allocator.alloc(u8, hash.len * 2);
    for (hash, 0..) |byte, i| {
        _ = try std.fmt.bufPrint(result[i*2..i*2+2], "{X:0>2}", .{byte});
    }
    return result;
}

/// Format hash to hex in buffer (non-allocating)
pub fn hashToHexBuf(buf: []u8, hash: []const u8) ![]u8 {
    if (buf.len < hash.len * 2) return error.BufferTooSmall;
    for (hash, 0..) |byte, i| {
        _ = try std.fmt.bufPrint(buf[i*2..i*2+2], "{X:0>2}", .{byte});
    }
    return buf[0..hash.len*2];
}

pub fn accountIDToBase58(allocator: std.mem.Allocator, account_id: types.AccountID) ![]u8 {
    return try base58.Base58.encodeAccountID(allocator, account_id);
}

pub fn formatTimeHuman(close_time: i64) [28]u8 {
    // Format: "2025-Oct-30 18:55:40.000000000 UTC"
    var result: [28]u8 = undefined;
    // Simple formatting for now - can enhance later
    _ = std.fmt.bufPrint(&result, "Time: {d}", .{close_time}) catch {};
    return result;
}

pub fn formatTimeISO(close_time: i64) []const u8 {
    // Format: "2025-10-30T18:55:40Z"
    _ = close_time;
    // Placeholder - would need proper date/time formatting
    return "2025-10-30T18:55:40Z";
}

