# Week 4: Critical TODO Implementation

**Found**: 26 TODO items in codebase  
**Approach**: Fix critical ones for launch  
**Goal**: Production-ready alpha  

---

## 🔴 **CRITICAL TODOs** (Must Fix Before Launch)

### **Priority 1: Ledger State Calculation** (src/ledger.zig)

**Current**:
```zig
.account_state_hash = [_]u8{0} ** 32, // TODO: Calculate from state tree
.transaction_hash = [_]u8{0} ** 32,   // TODO: Calculate from transactions
```

**Impact**: Ledger hashes are WRONG - critical blocker  
**Fix**: Use merkle tree to calculate real state hash  
**Lines**: ~50  
**Priority**: 🔴 CRITICAL  

---

### **Priority 2: Transaction Serialization** (src/transaction.zig)

**Current**:
```zig
// TODO: Implement proper serialization (canonical field ordering, binary format)
```

**Impact**: Transaction hashes won't match network  
**Fix**: Use CanonicalSerializer instead of simplified version  
**Lines**: ~30  
**Priority**: 🔴 CRITICAL  

---

### **Priority 3: secp256k1 Verification** (src/secp256k1.zig)

**Current**:
```zig
// TODO: Either implement full secp256k1 or bind to libsecp256k1
return error.NotYetImplemented;
```

**Impact**: Can't verify most real XRPL signatures  
**Fix**: Bind to libsecp256k1 OR clearly document "Ed25519 only"  
**Lines**: ~200 (if implementing) OR documentation  
**Priority**: 🔴 CRITICAL (OR accept limitation)  

---

### **Priority 4: Start Services** (src/main.zig)

**Current**:
```zig
// TODO: Start network listener
// TODO: Connect to peer network
// TODO: Start consensus rounds
// TODO: Start RPC server
```

**Impact**: Node doesn't actually run anything  
**Fix**: Actually start the servers and consensus  
**Lines**: ~100  
**Priority**: 🟡 HIGH  

---

## 🟡 **HIGH PRIORITY TODOs**

### **5. Consensus Proposal Verification**
**File**: src/consensus.zig  
**TODO**: Implement actual signature verification  
**Impact**: Consensus not fully validated  
**Lines**: ~50  

### **6. Config File Parsing**
**File**: src/config.zig  
**TODO**: Implement TOML/JSON parsing  
**Impact**: Can't load config from file  
**Lines**: ~100  

### **7. Pathfinding Algorithm**
**File**: src/pathfinding.zig  
**TODO**: Implement Dijkstra's algorithm  
**Impact**: No cross-currency payments  
**Lines**: ~300  

### **8. Storage Serialization**
**File**: src/storage.zig  
**TODO**: Serialize/deserialize ledger properly  
**Impact**: Can't persist real ledgers  
**Lines**: ~100  

---

## 🟢 **MEDIUM PRIORITY TODOs**

### **9. NFT ID Generation**
**File**: src/nft.zig  
**TODO**: Use proper NFT ID algorithm  
**Lines**: ~20  

### **10. Validator Manifest Verification**
**File**: src/validators.zig  
**TODO**: Implement manifest verification  
**Lines**: ~50  

### **11. UNL Loading**
**File**: src/validators.zig  
**TODO**: Load from vl.ripple.com or file  
**Lines**: ~100  

### **12. Payment Channel Signature Verification**
**File**: src/payment_channels.zig  
**TODO**: Verify channel signatures  
**Lines**: ~30  

### **13. Escrow Condition Verification**
**File**: src/escrow.zig  
**TODO**: Verify crypto conditions  
**Lines**: ~50  

### **14. RPC Transaction Deserialization**
**File**: src/rpc_methods.zig  
**TODO**: Deserialize and validate transaction  
**Lines**: ~50  

### **15. Merkle Proof Generation**
**File**: src/merkle.zig  
**TODO**: Implement full proof generation  
**Lines**: ~50  

### **16. LRU Cache Eviction**
**File**: src/storage.zig  
**TODO**: Implement LRU eviction  
**Lines**: ~30  

---

## 📋 **WEEK 4 EXECUTION PLAN**

### **Day 22-23**: Critical Ledger Fixes
- [ ] Fix ledger state hash calculation (use merkle tree)
- [ ] Fix transaction hash in ledger
- [ ] Validate ledger hashes match real network

### **Day 24**: Transaction Serialization
- [ ] Update PaymentTransaction to use CanonicalSerializer
- [ ] Test transaction hashing
- [ ] Validate against real network

### **Day 25**: Start Services
- [ ] Actually start RPC server in main.zig
- [ ] Start network listener
- [ ] Run consensus rounds
- [ ] Make node actually functional

### **Day 26**: secp256k1 Decision
- [ ] **Option A**: Quick C binding implementation
- [ ] **Option B**: Document "Ed25519 only for alpha"
- [ ] Choose and execute

### **Day 27**: Polish & Optimize
- [ ] Fix remaining high-priority TODOs
- [ ] Performance optimization
- [ ] Code cleanup

### **Day 28**: Final Review
- [ ] Run all tests
- [ ] Validate everything
- [ ] Documentation polish
- [ ] Launch prep

---

## 🎯 **IMMEDIATE ACTIONS**

**Starting NOW** - Fix the 4 CRITICAL TODOs:

1. Ledger state hash calculation
2. Transaction serialization  
3. secp256k1 OR document limitation
4. Actually start services in main

**Then**: Polish remaining TODOs

**Then**: Final validation and launch prep

---

**Let me start implementing the critical TODOs now.**

