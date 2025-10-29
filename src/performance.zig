const std = @import("std");

/// Performance optimizations and memory pooling
pub const ArenaPool = struct {
    arenas: std.ArrayList(*std.heap.ArenaAllocator),
    backing_allocator: std.mem.Allocator,
    max_arenas: usize,
    
    pub fn init(backing_allocator: std.mem.Allocator, max_arenas: usize) !ArenaPool {
        return ArenaPool{
            .arenas = try std.ArrayList(*std.heap.ArenaAllocator).initCapacity(backing_allocator, max_arenas),
            .backing_allocator = backing_allocator,
            .max_arenas = max_arenas,
        };
    }
    
    pub fn deinit(self: *ArenaPool) void {
        for (self.arenas.items) |arena| {
            arena.deinit();
            self.backing_allocator.destroy(arena);
        }
        self.arenas.deinit(self.backing_allocator);
    }
    
    /// Get an arena allocator from pool or create new one
    pub fn acquire(self: *ArenaPool) !*std.heap.ArenaAllocator {
        if (self.arenas.items.len > 0) {
            return self.arenas.pop();
        }
        
        const arena = try self.backing_allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(self.backing_allocator);
        return arena;
    }
    
    /// Return an arena to the pool
    pub fn release(self: *ArenaPool, arena: *std.heap.ArenaAllocator) !void {
        // Reset the arena
        _ = arena.reset(.retain_capacity);
        
        if (self.arenas.items.len < self.max_arenas) {
            try self.arenas.append(self.backing_allocator, arena);
        } else {
            arena.deinit();
            self.backing_allocator.destroy(arena);
        }
    }
};

/// Lock-free queue for high-performance message passing
pub fn LockFreeQueue(comptime T: type) type {
    return struct {
        const Self = @This();
        const Node = struct {
            data: T,
            next: std.atomic.Value(?*Node),
        };
        
        head: std.atomic.Value(?*Node),
        tail: std.atomic.Value(?*Node),
        allocator: std.mem.Allocator,
        
        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .head = std.atomic.Value(?*Node).init(null),
                .tail = std.atomic.Value(?*Node).init(null),
                .allocator = allocator,
            };
        }
        
        pub fn deinit(self: *Self) void {
            // Drain and free all nodes
            while (self.dequeue()) |item| {
                _ = item;
            }
        }
        
        /// Enqueue an item (lock-free)
        pub fn enqueue(self: *Self, data: T) !void {
            const node = try self.allocator.create(Node);
            node.* = Node{
                .data = data,
                .next = std.atomic.Value(?*Node).init(null),
            };
            
            while (true) {
                const tail = self.tail.load(.acquire);
                if (tail == null) {
                    // Empty queue
                    if (self.tail.cmpxchgWeak(null, node, .release, .acquire) == null) {
                        _ = self.head.store(node, .release);
                        return;
                    }
                } else {
                    const next = tail.?.next.load(.acquire);
                    if (next == null) {
                        if (tail.?.next.cmpxchgWeak(null, node, .release, .acquire) == null) {
                            _ = self.tail.cmpxchgWeak(tail, node, .release, .acquire);
                            return;
                        }
                    } else {
                        _ = self.tail.cmpxchgWeak(tail, next, .release, .acquire);
                    }
                }
            }
        }
        
        /// Dequeue an item (lock-free)
        pub fn dequeue(self: *Self) ?T {
            while (true) {
                const head = self.head.load(.acquire);
                if (head == null) return null;
                
                const tail = self.tail.load(.acquire);
                const next = head.?.next.load(.acquire);
                
                if (head == self.head.load(.acquire)) {
                    if (head == tail) {
                        if (next == null) {
                            return null;
                        }
                        _ = self.tail.cmpxchgWeak(tail, next, .release, .acquire);
                    } else {
                        if (next) |next_node| {
                            const data = next_node.data;
                            if (self.head.cmpxchgWeak(head, next, .release, .acquire) == head) {
                                self.allocator.destroy(head.?);
                                return data;
                            }
                        }
                    }
                }
            }
        }
    };
}

/// Object pool for reducing allocations
pub fn ObjectPool(comptime T: type) type {
    return struct {
        const Self = @This();
        
        free_list: std.ArrayList(*T),
        allocator: std.mem.Allocator,
        max_size: usize,
        
        pub fn init(allocator: std.mem.Allocator, max_size: usize) !Self {
            return Self{
                .free_list = try std.ArrayList(*T).initCapacity(allocator, max_size),
                .allocator = allocator,
                .max_size = max_size,
            };
        }
        
        pub fn deinit(self: *Self) void {
            for (self.free_list.items) |obj| {
                self.allocator.destroy(obj);
            }
            self.free_list.deinit(self.allocator);
        }
        
        /// Acquire an object from pool
        pub fn acquire(self: *Self) !*T {
            if (self.free_list.items.len > 0) {
                return self.free_list.pop();
            }
            
            return try self.allocator.create(T);
        }
        
        /// Return object to pool
        pub fn release(self: *Self, obj: *T) !void {
            if (self.free_list.items.len < self.max_size) {
                try self.free_list.append(self.allocator, obj);
            } else {
                self.allocator.destroy(obj);
            }
        }
    };
}

test "arena pool" {
    const allocator = std.testing.allocator;
    var pool = try ArenaPool.init(allocator, 2);
    defer pool.deinit();
    
    const arena1 = try pool.acquire();
    const arena2 = try pool.acquire();
    
    try pool.release(arena1);
    try pool.release(arena2);
    
    try std.testing.expectEqual(@as(usize, 2), pool.arenas.items.len);
}

test "lock-free queue" {
    const allocator = std.testing.allocator;
    var queue = LockFreeQueue(u32).init(allocator);
    defer queue.deinit();
    
    try queue.enqueue(1);
    try queue.enqueue(2);
    try queue.enqueue(3);
    
    try std.testing.expectEqual(@as(u32, 1), queue.dequeue().?);
    try std.testing.expectEqual(@as(u32, 2), queue.dequeue().?);
    try std.testing.expectEqual(@as(u32, 3), queue.dequeue().?);
    try std.testing.expectEqual(@as(?u32, null), queue.dequeue());
}

test "object pool" {
    const allocator = std.testing.allocator;
    
    const TestObj = struct { value: u32 };
    var pool = try ObjectPool(TestObj).init(allocator, 5);
    defer pool.deinit();
    
    const obj1 = try pool.acquire();
    const obj2 = try pool.acquire();
    
    obj1.value = 42;
    obj2.value = 100;
    
    try pool.release(obj1);
    try pool.release(obj2);
    
    try std.testing.expectEqual(@as(usize, 2), pool.free_list.items.len);
}

