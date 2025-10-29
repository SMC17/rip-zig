const std = @import("std");
const types = @import("types.zig");
const ledger = @import("ledger.zig");

/// XRP Ledger Consensus Protocol
/// Based on the Ripple Protocol Consensus Algorithm (RPCA)
/// 
/// Key characteristics:
/// - Byzantine Fault Tolerant (BFT)
/// - No mining or proof-of-work
/// - Consensus rounds typically complete in 4-5 seconds
/// - Requires 80% agreement from trusted validators (UNL)
pub const ConsensusEngine = struct {
    allocator: std.mem.Allocator,
    state: ConsensusState,
    round_number: u64,
    unl: std.ArrayList(ValidatorInfo), // Unique Node List
    
    pub fn init(allocator: std.mem.Allocator) !ConsensusEngine {
        return ConsensusEngine{
            .allocator = allocator,
            .state = .open,
            .round_number = 0,
            .unl = try std.ArrayList(ValidatorInfo).initCapacity(allocator, 0),
        };
    }
    
    pub fn deinit(self: *ConsensusEngine) void {
        self.unl.deinit(self.allocator);
    }
    
    /// Add a validator to the UNL (Unique Node List)
    pub fn addValidator(self: *ConsensusEngine, validator: ValidatorInfo) !void {
        try self.unl.append(self.allocator, validator);
    }
    
    /// Start a new consensus round
    pub fn startRound(self: *ConsensusEngine) !void {
        self.round_number += 1;
        self.state = .open;
        
        std.debug.print("Consensus round {d} started\n", .{self.round_number});
    }
    
    /// Process proposals from validators
    pub fn processProposal(self: *ConsensusEngine, proposal: Proposal) !void {
        _ = proposal;
        _ = self;
        // TODO: Implement proposal processing logic
    }
    
    /// Check if consensus has been reached (80% threshold)
    pub fn hasReachedConsensus(self: *const ConsensusEngine, proposal_id: [32]u8) bool {
        _ = proposal_id;
        _ = self;
        // TODO: Implement consensus checking
        return false;
    }
    
    /// Finalize the consensus round
    pub fn finalizeRound(self: *ConsensusEngine) !ConsensusResult {
        self.state = .accepted;
        
        // TODO: Build the final transaction set
        // TODO: Close the ledger
        
        return ConsensusResult{
            .round_number = self.round_number,
            .success = true,
            .transaction_count = 0,
        };
    }
};

/// States of the consensus process
pub const ConsensusState = enum {
    open,         // Collecting transactions
    establish,    // Establishing initial proposal
    accepted,     // Consensus reached
    validated,    // Ledger validated
};

/// Information about a validator node
pub const ValidatorInfo = struct {
    public_key: [33]u8,
    node_id: [32]u8,
    is_trusted: bool,
};

/// A proposal from a validator
pub const Proposal = struct {
    validator_id: [32]u8,
    ledger_seq: types.LedgerSequence,
    close_time: i64,
    position: Position,
    signature: [64]u8,
    
    /// The proposed position (set of transactions and prior ledger)
    pub const Position = struct {
        prior_ledger: types.LedgerHash,
        transactions: []const types.TxHash,
    };
};

/// Result of a consensus round
pub const ConsensusResult = struct {
    round_number: u64,
    success: bool,
    transaction_count: u32,
};

/// Consensus phases in more detail
/// 
/// Phase 1: Open (Transaction Collection)
/// - Nodes collect candidate transactions
/// - Duration: ~few seconds
/// 
/// Phase 2: Establish (Initial Consensus)
/// - Each validator proposes a transaction set
/// - Nodes exchange and compare proposals
/// - 50% threshold required to proceed
/// 
/// Phase 3: Consensus Building
/// - Multiple rounds of proposal refinement
/// - Threshold increases each round: 50% -> 60% -> 70% -> 80%
/// - Validators adjust their proposals based on peer proposals
/// 
/// Phase 4: Validation
/// - Once 80% agreement reached, ledger closes
/// - All nodes validate and apply the transaction set
/// - New ledger becomes the validated ledger
pub const ConsensusPhase = enum {
    open,
    establish,
    consensus_50,
    consensus_60,
    consensus_70,
    consensus_80,
    validation,
};

test "consensus engine initialization" {
    const allocator = std.testing.allocator;
    var engine = try ConsensusEngine.init(allocator);
    defer engine.deinit();
    
    try std.testing.expectEqual(ConsensusState.open, engine.state);
    try std.testing.expectEqual(@as(u64, 0), engine.round_number);
}

test "add validator to UNL" {
    const allocator = std.testing.allocator;
    var engine = try ConsensusEngine.init(allocator);
    defer engine.deinit();
    
    const validator = ValidatorInfo{
        .public_key = [_]u8{1} ** 33,
        .node_id = [_]u8{2} ** 32,
        .is_trusted = true,
    };
    
    try engine.addValidator(validator);
    try std.testing.expectEqual(@as(usize, 1), engine.unl.items.len);
}

