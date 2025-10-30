# Week 2: secp256k1 Integration - Implementation Guide

## Status: IN PROGRESS

**Goal**: Complete secp256k1 ECDSA signature verification integration
**Target**: Test with 100+ real signatures from XRPL testnet

---

## What's Been Done

1. **build.zig Updated**: Added `exe.linkSystemLibrary("secp256k1")` for linking libsecp256k1
2. **secp256k1_binding.zig**: Fixed C binding to match libsecp256k1 API with proper struct definitions
3. **secp256k1.zig**: Updated to use binding instead of stub
4. **crypto.zig**: Integrated secp256k1 verification into main crypto module
5. **Test Suite**: Created `tests/secp256k1_validation.zig` for comprehensive testing

---

## Installation

### macOS
```bash
brew install secp256k1
```

### Ubuntu/Debian
```bash
apt-get install libsecp256k1-dev
```

### Build from Source
```bash
git clone https://github.com/bitcoin-core/secp256k1.git
cd secp256k1
./autogen.sh
./configure
make
sudo make install
```

---

## Testing

### Run Tests
```bash
zig build test
```

### Test secp256k1 Integration
Tests will skip if libsecp256k1 is not installed, but will run if it's available.

---

## Next Steps

1. **Install libsecp256k1** on your system
2. **Run tests** to verify integration works
3. **Fetch real testnet transactions** with secp256k1 signatures
4. **Verify 100+ signatures** to ensure compatibility

### Fetch Real Testnet Signatures

To test with real XRPL signatures, you can:

1. Use XRPL Testnet API to fetch recent transactions:
```bash
curl "https://s.altnet.rippletest.net:51234" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"method":"account_tx","params":[{"account":"rPT1Sjq2YGrBMTttX4GZHjKu9yfEozoscZ","ledger_index_min":-1,"ledger_index_max":-1}]}'
```

2. Extract `SigningPubKey` and `TxnSignature` fields
3. Reconstruct canonical transaction (without signature fields)
4. Hash with SHA-512 Half
5. Verify signature using secp256k1

---

## Implementation Details

### C Binding Structure

The binding uses `extern struct` to match libsecp256k1's ABI:
- `secp256k1_pubkey`: 64-byte aligned struct for public keys
- `secp256k1_ecdsa_signature`: 64-byte aligned struct for signatures

### Signature Verification Flow

1. Initialize secp256k1 context (singleton)
2. Parse public key from compressed/uncompressed format
3. Parse DER-encoded signature
4. Verify signature against message hash
5. Return verification result

### Integration Points

- **crypto.zig**: Main verification entry point
- **multisig.zig**: Multi-signature support
- **transaction.zig**: Transaction validation

---

## Known Issues

1. **Library Dependency**: Requires libsecp256k1 to be installed
2. **Test Data**: Need real testnet transactions for comprehensive testing
3. **Transaction Hash**: Need to verify canonical serialization matches XRPL spec

---

## Verification Checklist

- [x] Build system links secp256k1
- [x] C binding matches libsecp256k1 API
- [x] Integration with crypto module
- [ ] Library installed and tests passing
- [ ] Real testnet signatures verified
- [ ] 100+ signature test suite passing
- [ ] Performance benchmarks

---

## References

- [libsecp256k1 Repository](https://github.com/bitcoin-core/secp256k1)
- [XRPL Transaction Format](https://xrpl.org/transaction-formats.html)
- [secp256k1 API Documentation](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1.h)

