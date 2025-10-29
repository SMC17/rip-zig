# Week 2 Execution Plan: Fix Critical Blockers

**Start**: Day 8 (Tomorrow)  
**Goal**: Clear 4/5 critical blockers  
**Approach**: Systematic fixing with validation  

---

## 🎯 **DAILY BREAKDOWN**

### **Day 8: secp256k1 Research + Start**

**Morning** (4 hours):
- [x] Research secp256k1 libraries for Zig
- [ ] Evaluate options:
  1. libsecp256k1 C binding (Bitcoin Core's library)
  2. zig-bitcoin/secp256k1 if available
  3. Pure Zig implementation

**Decision Criteria**:
- Fastest to implement: C binding
- Best long-term: Pure Zig
- Recommendation: Start with C binding, migrate to pure Zig later

**Afternoon** (4 hours):
- [ ] Set up libsecp256k1 binding OR start pure implementation
- [ ] Implement basic signature verification function
- [ ] Create test with real testnet signature

**Evening**:
- [ ] Document progress
- [ ] Commit work
- [ ] Plan Day 9

**Deliverable**: secp256k1 verification partially working

---

### **Day 9: Complete secp256k1**

**Morning**:
- [ ] Finish secp256k1 implementation
- [ ] Test against real testnet signature from test_data
- [ ] Verify it actually works

**Afternoon**:
- [ ] Add comprehensive tests
- [ ] Handle both compressed and uncompressed keys
- [ ] Support DER signature parsing

**Evening**:
- [ ] Validate against 5+ real transactions
- [ ] Document any issues
- [ ] Mark blocker as RESOLVED

**Deliverable**: ✅ secp256k1 working and validated

---

### **Day 10: Canonical Field Ordering**

**Morning**:
- [ ] Study XRPL field ordering specification
- [ ] Implement field buffer + sorting in Serializer
- [ ] Fields must be sorted by: (type_code, field_code)

**Afternoon**:
- [ ] Test with simple transaction
- [ ] Calculate hash
- [ ] Compare to real transaction hash from testnet

**Evening**:
- [ ] Fix any ordering issues
- [ ] Validate with multiple real transactions
- [ ] Mark blocker as RESOLVED

**Deliverable**: ✅ Canonical ordering working, hashes match

---

### **Day 11: SignerListSet + Multi-sig**

**Morning**:
- [ ] Implement SignerListSet transaction type
- [ ] Add SignerEntry structure
- [ ] Validation logic

**Afternoon**:
- [ ] Add Signers array to Transaction struct
- [ ] Make signing_pub_key optional
- [ ] Implement multi-sig validation

**Evening**:
- [ ] Test against real multi-sig transaction from testnet
- [ ] Verify can parse and validate
- [ ] Mark blockers #3 and #4 as RESOLVED

**Deliverable**: ✅ SignerListSet working, multi-sig supported

---

### **Day 12: RIPEMD-160 Implementation**

**Morning**:
- [ ] Research RIPEMD-160 options
- [ ] Choose: Pure Zig implementation (~500 lines)
- [ ] Start implementing algorithm

**Afternoon**:
- [ ] Complete RIPEMD-160 implementation
- [ ] Test against known test vectors
- [ ] Validate correctness

**Evening**:
- [ ] Replace SHA-256 stub in crypto.zig
- [ ] Test account ID derivation
- [ ] Mark blocker as RESOLVED

**Deliverable**: ✅ RIPEMD-160 working correctly

---

### **Day 13: Comprehensive Re-Validation**

**Morning**:
- [ ] Run ALL 30+ validation tests
- [ ] Document what passes and what fails
- [ ] Count passing percentage

**Afternoon**:
- [ ] Fix any remaining hash issues
- [ ] Test ledger hash calculation
- [ ] Test state tree hashing

**Evening**:
- [ ] Re-run validation suite
- [ ] Update CRITICAL_BLOCKERS.md
- [ ] Document progress

**Deliverable**: 60%+ validation tests passing

---

### **Day 14: Week 2 Review + Week 3 Prep**

**Morning**:
- [ ] Run complete test suite
- [ ] Review all fixed blockers
- [ ] Measure progress

**Afternoon**:
- [ ] Update all documentation
- [ ] Remove unverified claims
- [ ] Plan Week 3 tasks

**Evening**:
- [ ] Week 2 retrospective
- [ ] Commit all work
- [ ] Prepare Week 3 priorities

**Deliverable**: Week 2 complete, ready for Week 3

---

## 📊 **SUCCESS METRICS**

### **By End of Week 2**:

**Code**:
- [ ] 8,000+ lines total
- [ ] secp256k1 module added (~500 lines)
- [ ] RIPEMD-160 implemented (~500 lines)
- [ ] Serializer improved (~200 lines added)
- [ ] SignerListSet added (~150 lines)

**Blockers**:
- [ ] Blocker #1 (secp256k1): ✅ RESOLVED
- [ ] Blocker #2 (canonical ordering): ✅ RESOLVED
- [ ] Blocker #3 (SignerListSet): ✅ RESOLVED
- [ ] Blocker #4 (multi-sig): ✅ RESOLVED
- [ ] Blocker #5 (RIPEMD-160): ✅ RESOLVED

**Validation**:
- [ ] 60%+ tests passing (was 25%)
- [ ] Critical hashes validated
- [ ] Signatures verified
- [ ] Compatibility proven

---

## 🔥 **DAILY ROUTINE** (Mon-Sun)

### **Every Day**:

**06:00** - Wake up, review overnight (if any)  
**07:00** - First coding session (fresh mind)  
**09:00** - Commit progress  
**10:00** - Core development (focus block)  
**14:00** - Testing and validation  
**16:00** - Commit again  
**17:00** - Documentation updates  
**19:00** - Review day's progress  
**21:00** - Plan tomorrow  
**22:00** - Final commit  

### **Minimum Daily Output**:
- 300+ lines of code OR
- 1 blocker fixed OR
- 5+ bugs fixed
- 5+ validation tests created/fixed
- Documentation updated

---

## ⚠️ **RISKS & MITIGATIONS**

### **Risk 1**: secp256k1 takes longer than 2 days
**Mitigation**: Use C binding first, pure Zig later

### **Risk 2**: Canonical ordering is complex
**Mitigation**: Study rippled source code, copy algorithm exactly

### **Risk 3**: Still find issues after fixes
**Mitigation**: Iterative validation, fix until passes

### **Risk 4**: Week 2 goals too aggressive
**Mitigation**: Focus on blockers, defer nice-to-haves

---

## ✅ **VALIDATION CHECKPOINTS**

### **Mid-Week Check** (Day 10):
- Should have secp256k1 working
- Should have canonical ordering done
- Should see first hashes matching

**If behind**: Cut scope, focus on secp256k1

### **End-of-Week Check** (Day 14):
- Should have 4/5 blockers cleared
- Should have 60%+ tests passing
- Should have clear Week 3 plan

**If behind**: Extend Week 2, don't compromise on quality

---

## 🎯 **THE GOAL**

**By End of Week 2**:
- ✅ Can verify real XRPL signatures (secp256k1)
- ✅ Transaction hashes match network
- ✅ Account addresses are correct
- ✅ Multi-sig transactions work
- ✅ 60%+ of validation tests passing

**Then Week 3**: Polish remaining 40%

**Then Week 4**: Final hardening

**Then Week 5**: Launch with confidence

---

**Start**: Tomorrow (Day 8)  
**Focus**: secp256k1 implementation  
**Standard**: Fix properly, not quickly  
**Outcome**: Real XRPL compatibility  

**Let's execute.** 🔥

