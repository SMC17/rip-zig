const std = @import("std");
const config = @import("config.zig");

/// Simple but functional logging system
pub const Logger = struct {
    allocator: std.mem.Allocator,
    level: config.LogLevel,
    file: ?std.fs.File,
    mutex: std.Thread.Mutex,
    
    pub fn init(allocator: std.mem.Allocator, level: config.LogLevel, file_path: ?[]const u8) !Logger {
        const log_file = if (file_path) |path| blk: {
            break :blk try std.fs.cwd().createFile(path, .{ .truncate = false });
        } else null;
        
        return Logger{
            .allocator = allocator,
            .level = level,
            .file = log_file,
            .mutex = .{},
        };
    }
    
    pub fn deinit(self: *Logger) void {
        if (self.file) |file| {
            file.close();
        }
    }
    
    /// Log a message at debug level
    pub fn debug(self: *Logger, comptime format: []const u8, args: anytype) void {
        self.log(.debug, format, args);
    }
    
    /// Log a message at info level
    pub fn info(self: *Logger, comptime format: []const u8, args: anytype) void {
        self.log(.info, format, args);
    }
    
    /// Log a message at warn level
    pub fn warn(self: *Logger, comptime format: []const u8, args: anytype) void {
        self.log(.warn, format, args);
    }
    
    /// Log a message at error level
    pub fn err(self: *Logger, comptime format: []const u8, args: anytype) void {
        self.log(.@"error", format, args);
    }
    
    /// Log a message at fatal level
    pub fn fatal(self: *Logger, comptime format: []const u8, args: anytype) void {
        self.log(.fatal, format, args);
    }
    
    /// Internal logging function
    fn log(self: *Logger, level: config.LogLevel, comptime format: []const u8, args: anytype) void {
        // Check if we should log at this level
        if (@intFromEnum(level) < @intFromEnum(self.level)) {
            return;
        }
        
        self.mutex.lock();
        defer self.mutex.unlock();
        
        // Format timestamp
        const timestamp = std.time.timestamp();
        const level_str = @tagName(level);
        
        // Write to stderr
        std.debug.print("[{d}] [{s}] ", .{ timestamp, level_str });
        std.debug.print(format, args);
        std.debug.print("\n", .{});
        
        // Write to file if configured
        if (self.file) |file| {
            var buf: [1024]u8 = undefined;
            const log_line = std.fmt.bufPrint(&buf, "[{d}] [{s}] ", .{ timestamp, level_str }) catch return;
            file.writeAll(log_line) catch return;
            
            const message = std.fmt.bufPrint(buf[log_line.len..], format, args) catch return;
            file.writeAll(message) catch return;
            file.writeAll("\n") catch return;
        }
    }
};

/// Global logger instance (can be initialized once)
pub var global_logger: ?Logger = null;

/// Initialize global logger
pub fn initGlobal(allocator: std.mem.Allocator, level: config.LogLevel, file_path: ?[]const u8) !void {
    global_logger = try Logger.init(allocator, level, file_path);
}

/// Deinitialize global logger
pub fn deinitGlobal() void {
    if (global_logger) |*logger| {
        logger.deinit();
        global_logger = null;
    }
}

/// Convenience functions for global logger
pub fn debug(comptime format: []const u8, args: anytype) void {
    if (global_logger) |*logger| logger.debug(format, args);
}

pub fn info(comptime format: []const u8, args: anytype) void {
    if (global_logger) |*logger| logger.info(format, args);
}

pub fn warn(comptime format: []const u8, args: anytype) void {
    if (global_logger) |*logger| logger.warn(format, args);
}

pub fn err(comptime format: []const u8, args: anytype) void {
    if (global_logger) |*logger| logger.err(format, args);
}

pub fn fatal(comptime format: []const u8, args: anytype) void {
    if (global_logger) |*logger| logger.fatal(format, args);
}

test "logger initialization" {
    const allocator = std.testing.allocator;
    var logger = try Logger.init(allocator, .info, null);
    defer logger.deinit();
    
    // Test logging (won't output in test mode)
    logger.info("Test info message", .{});
    logger.debug("This should not appear", .{}); // Below threshold
}

test "log levels" {
    try std.testing.expect(@intFromEnum(config.LogLevel.debug) < @intFromEnum(config.LogLevel.info));
    try std.testing.expect(@intFromEnum(config.LogLevel.info) < @intFromEnum(config.LogLevel.warn));
    try std.testing.expect(@intFromEnum(config.LogLevel.warn) < @intFromEnum(config.LogLevel.@"error"));
}

