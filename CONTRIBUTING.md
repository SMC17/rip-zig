# Contributing to rippled-zig

First off, thank you for considering contributing to rippled-zig! This project aims to become the most advanced, optimized, and secure XRP Ledger implementation, and we need YOUR help to make it happen.

## 🌟 Why Contribute?

- **Learn cutting-edge tech**: Master Zig, blockchain, and distributed systems
- **Make real impact**: Help build critical financial infrastructure
- **Join early**: Ground-floor opportunity in an ambitious project
- **Open recognition**: Your contributions will be celebrated
- **Shape the future**: Influence design decisions and architecture

## 🎯 Current State & Needs

We're **honest about where we are**:
- ✅ **Core foundation is solid** (types, crypto, ledger management)
- 🚧 **Networking needs implementation** (our #1 priority)
- 🚧 **RPC server needs building** (great for web devs)
- 🚧 **Consensus needs completion** (for distributed systems experts)
- 🔴 **Not production ready** (but getting there!)

See [ROADMAP.md](ROADMAP.md) for detailed status and future plans.

## 🚀 Quick Start

### 1. Set Up Development Environment

```bash
# Clone the repository
git clone https://github.com/SMC17/rip-zig.git
cd rip-zig

# Ensure you have Zig 0.15.1+ installed
zig version

# Build the project
zig build

# Run tests (should all pass!)
zig build test

# Run the daemon
zig build run
```

### 2. Find Something to Work On

**For Beginners**: Look for issues tagged with:
- `good-first-issue` - Perfect for newcomers
- `documentation` - Help improve our docs
- `testing` - Add test cases

**For Intermediate**: Issues tagged with:
- `help-wanted` - We need your skills!
- `feature` - New features to implement
- `enhancement` - Improvements to existing code

**For Experts**: Issues tagged with:
- `advanced` - Complex features
- `core` - Core system components
- `security` - Security-critical features

Browse open issues: https://github.com/SMC17/rip-zig/issues

### 3. Claim an Issue

Comment on the issue saying you're working on it. This prevents duplicate work.

```
I'd like to work on this! ETA: 1 week
```

## 📝 Development Workflow

### 1. Fork & Branch

```bash
# Fork on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/rip-zig.git
cd rip-zig

# Add upstream remote
git remote add upstream https://github.com/SMC17/rip-zig.git

# Create a feature branch
git checkout -b feature/your-feature-name
```

### 2. Make Your Changes

```bash
# Edit files
# Add tests for new functionality
# Ensure all tests pass
zig build test

# Build to check for compilation errors
zig build
```

### 3. Commit

Write clear, descriptive commit messages:

```bash
git add .
git commit -m "feat: add TCP listener for P2P networking

- Implements basic TCP server on configurable port
- Adds connection handling and error recovery
- Includes unit tests for listener functionality
- Closes #1"
```

**Commit Message Format**:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `test:` - Adding or updating tests
- `refactor:` - Code refactoring
- `perf:` - Performance improvements
- `chore:` - Build/tooling changes

### 4. Push & Create PR

```bash
# Push to your fork
git push origin feature/your-feature-name

# Create Pull Request on GitHub
# Fill out the PR template completely
```

## ✅ Pull Request Guidelines

### Before Submitting

- [ ] All tests pass (`zig build test`)
- [ ] Code builds without warnings (`zig build`)
- [ ] New features have tests
- [ ] Documentation is updated
- [ ] Commit messages are clear
- [ ] Branch is up to date with main

### PR Template

Your PR should include:

1. **Description**: What does this PR do?
2. **Issue Reference**: Closes #XX
3. **Type of Change**: Feature/Bug Fix/Documentation/etc.
4. **Testing**: How was this tested?
5. **Screenshots**: If UI/output changes
6. **Checklist**: Confirm all items above

### Example PR

```markdown
## Description
Implements basic TCP listener for P2P networking

## Closes
Closes #1

## Type of Change
- [x] New feature
- [ ] Bug fix
- [ ] Documentation update

## Testing
- Added unit tests for TCP listener
- Manually tested connection handling
- All existing tests still pass

## Checklist
- [x] Tests pass
- [x] Code builds
- [x] Documentation updated
- [x] Commit messages clear
```

## 🎨 Code Style

### Zig Style Guide

Follow standard Zig conventions:

```zig
// Good: Clear names, proper formatting
pub const LedgerManager = struct {
    allocator: std.mem.Allocator,
    current_ledger: Ledger,
    
    pub fn init(allocator: std.mem.Allocator) !LedgerManager {
        return LedgerManager{
            .allocator = allocator,
            .current_ledger = Ledger.genesis(),
        };
    }
};

// Bad: Unclear names, poor formatting
pub const LM=struct{a:std.mem.Allocator,cl:Ledger,pub fn i(a:std.mem.Allocator)!LM{return LM{.a=a,.cl=Ledger.genesis()};}};
```

### Key Conventions

1. **Naming**:
   - Types: `PascalCase` (e.g., `LedgerManager`)
   - Functions: `camelCase` (e.g., `getCurrentLedger`)
   - Constants: `UPPER_SNAKE_CASE` (e.g., `MAX_XRP`)
   - Variables: `snake_case` (e.g., `account_id`)

2. **Formatting**:
   - 4 spaces for indentation (no tabs)
   - Line length: aim for 100 characters
   - Use `zig fmt` to auto-format

3. **Comments**:
   - Document public APIs
   - Explain complex algorithms
   - Use TODO/FIXME for temporary code

4. **Error Handling**:
   - Always handle errors explicitly
   - Use meaningful error types
   - Document possible errors in comments

### Testing

```zig
// Every public function should have tests
test "ledger manager initialization" {
    const allocator = std.testing.allocator;
    var manager = try LedgerManager.init(allocator);
    defer manager.deinit();
    
    try std.testing.expectEqual(@as(u32, 1), manager.current_ledger.sequence);
}
```

## 🏗️ Architecture Guidelines

### Module Organization

```
src/
├── main.zig          # Entry point only
├── types.zig         # Core types (no dependencies)
├── crypto.zig        # Cryptography (depends on types)
├── ledger.zig        # Ledger (depends on types, crypto)
├── consensus.zig     # Consensus (depends on ledger)
├── transaction.zig   # Transactions (depends on ledger)
├── network.zig       # Networking (depends on consensus)
├── rpc.zig          # RPC API (depends on ledger)
└── storage.zig      # Storage (depends on ledger)
```

### Dependency Rules

- **No circular dependencies**
- **Types module has no dependencies**
- **Main only coordinates, doesn't implement**
- **Use dependency injection**

### Memory Management

```zig
// Good: Clear ownership, proper cleanup
pub fn processTransaction(allocator: std.mem.Allocator, tx: Transaction) !Result {
    var processor = try Processor.init(allocator);
    defer processor.deinit();
    
    return processor.process(tx);
}

// Bad: Unclear ownership, potential leaks
pub fn processTransaction(tx: Transaction) !Result {
    var processor = Processor.init(std.heap.page_allocator);
    return processor.process(tx); // Forgot to deinit!
}
```

## 🧪 Testing Guidelines

### Test Coverage

- **Every public function** needs tests
- **Edge cases** must be tested
- **Error paths** must be tested
- **Integration tests** for complex interactions

### Test Organization

```zig
// At the end of each source file
test "feature name: specific behavior" {
    // Arrange
    const allocator = std.testing.allocator;
    var sut = try SystemUnderTest.init(allocator);
    defer sut.deinit();
    
    // Act
    const result = try sut.doSomething();
    
    // Assert
    try std.testing.expectEqual(expected, result);
}
```

### Running Tests

```bash
# All tests
zig build test

# Specific module
zig test src/ledger.zig

# With verbose output
zig build test --summary all
```

## 📚 Documentation Guidelines

### Code Documentation

```zig
/// Manages the ledger chain and state.
/// 
/// The LedgerManager maintains the current validated ledger
/// and provides access to historical ledgers.
pub const LedgerManager = struct {
    /// Closes the current ledger and creates a new one.
    /// 
    /// Applies all transactions to the ledger state and
    /// calculates the new ledger hash.
    /// 
    /// Returns the newly created ledger.
    pub fn closeLedger(self: *LedgerManager, txs: []const Transaction) !Ledger {
        // Implementation
    }
};
```

### README Updates

If your change affects usage, update relevant documentation:
- README.md - Main documentation
- GETTING_STARTED.md - Tutorials
- Examples - Add/update examples

## 🐛 Bug Reports

### Before Reporting

1. **Search existing issues** - Maybe it's already reported
2. **Try latest version** - Maybe it's already fixed
3. **Simplify** - Create minimal reproduction

### Bug Report Template

```markdown
## Description
Clear description of the bug

## Steps to Reproduce
1. Build with `zig build`
2. Run with `zig build run`
3. Observe error

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- OS: macOS 14.0
- Zig version: 0.15.1
- rippled-zig version: v0.1.0-alpha

## Additional Context
- Stack traces
- Logs
- Screenshots
```

## 💡 Feature Requests

We love new ideas! But please:

1. **Check roadmap** - Maybe it's already planned
2. **Search issues** - Maybe someone else suggested it
3. **Explain the "why"** - What problem does it solve?
4. **Consider scope** - Is it aligned with project goals?

### Feature Request Template

```markdown
## Problem
What problem does this solve?

## Proposed Solution
How should this work?

## Alternatives
What other solutions did you consider?

## Additional Context
- Use cases
- Examples from other projects
- Implementation ideas
```

## 🔒 Security Issues

**DO NOT** open public issues for security vulnerabilities!

Instead:
1. Email security@rip-zig.org (coming soon)
2. Or create a private security advisory on GitHub
3. Include detailed information
4. We'll respond within 48 hours

## 🎯 Priority Areas (November 2025)

We especially need help with:

### 1. 🔴 Critical: P2P Networking
**Why**: Can't have a node without networking!
**Skills**: Network programming, async I/O, protocols
**Issues**: #1-8

### 2. 🟡 Important: RPC Server
**Why**: Needed for node interaction
**Skills**: Web development, HTTP, WebSockets
**Issues**: #9-17

### 3. 🟡 Important: Complete Consensus
**Why**: Core functionality
**Skills**: Distributed systems, algorithms
**Issues**: #18-25

### 4. 🟢 Nice to Have: Documentation
**Why**: Help others contribute
**Skills**: Technical writing
**Tags**: `documentation`

## 🏆 Recognition

We celebrate all contributors!

### Hall of Fame
- Monthly shoutouts for top contributors
- Listed in CONTRIBUTORS.md
- Mentioned in release notes
- GitHub badges and achievements

### Contribution Levels
- 🌱 **Seedling**: First contribution
- 🌿 **Contributor**: 5+ contributions
- 🌳 **Core Contributor**: 20+ contributions
- 🏆 **Maintainer**: Trusted with merge access

## 💬 Community

### Communication Channels

- **GitHub Issues**: Feature requests, bugs
- **GitHub Discussions**: General questions, ideas
- **Discord** (coming soon): Real-time chat
- **Twitter** (coming soon): Announcements

### Code of Conduct

We are committed to providing a welcoming and inspiring community for all.

**Expected Behavior**:
- Be respectful and inclusive
- Accept constructive criticism
- Focus on what's best for the community
- Show empathy

**Unacceptable**:
- Harassment or discriminatory language
- Trolling or insulting comments
- Public or private harassment
- Other unprofessional conduct

**Enforcement**: Violations may result in temporary or permanent ban.

## 📞 Questions?

- Check [README.md](README.md)
- Check [GETTING_STARTED.md](GETTING_STARTED.md)
- Browse existing issues
- Ask in GitHub Discussions
- Join our Discord (coming soon)

## 🎉 Thank You!

Every contribution matters - from fixing typos to implementing core features. Thank you for being part of this journey to build the future of XRP Ledger infrastructure!

Together, we'll create the most advanced, optimized, performant, and secure XRPL implementation ever built.

---

**Happy Coding! 🚀**

*Built with ❤️ by the rippled-zig community*

