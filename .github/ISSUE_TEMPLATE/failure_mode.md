---
name: Failure Mode
about: Document a known way the system can fail
title: '[FAILURE] '
labels: failure-mode, needs-hardening
assignees: ''
---

## Failure Mode Description
Clear description of how the system can fail.

## Component Affected
Which module(s) or subsystem(s) are affected?

## Trigger Conditions
What conditions cause this failure?
- Network state?
- Resource limits?
- Invalid input?
- Race condition?

## Impact Assessment
- [ ] Data loss possible
- [ ] Security vulnerability
- [ ] Service degradation
- [ ] Service unavailable
- [ ] Performance impact

**Severity**: Critical / High / Medium / Low

## Current State
- [x] Failure mode identified
- [ ] Failure mode tested
- [ ] Detection implemented
- [ ] Monitoring implemented
- [ ] Recovery implemented
- [ ] Prevention implemented

## Detection Strategy
How do we detect this failure is occurring?

## Recovery Strategy
How do we recover when this fails?

## Prevention Strategy  
How do we prevent this failure mode?

## Testing Plan
How do we test this failure mode?
- [ ] Unit test for failure path
- [ ] Integration test
- [ ] Stress test
- [ ] Chaos test

## Related Issues
List any related failure modes or issues

## Priority
Why should this be prioritized (or not)?

