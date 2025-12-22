# Production Readiness Epic Issues - Created

## Summary
Created a complete three-phase roadmap for production readiness as GitHub issues with proper dependencies and acceptance criteria.

## Created Issues

### Meta Issue
**#420 - Meta: Production Readiness Roadmap (Epic 1→2→3)**  
https://github.com/cleveland-lewis/Roots/issues/420
- Tracks overall progress across all three epics
- Shows dependency graph
- Lists next actions

### Epic Issues

**#417 - Epic 1: Local-First Persistence Foundation**  
https://github.com/cleveland-lewis/Roots/issues/417
- Foundation epic (no blockers)
- Establishes offline-first persistence layer
- Must complete before Epic 2 or 3

**#418 - Epic 2: CloudKit iCloud Sync (Apple-Native Sync Layer)**  
https://github.com/cleveland-lewis/Roots/issues/418
- Blocked by: Epic 1 (#417)
- Requires: Apple Developer Program enrollment ($99)
- Adds cross-device sync without changing UI

**#419 - Epic 3: App Store Production & Subscriptions**  
https://github.com/cleveland-lewis/Roots/issues/419
- Blocked by: Epic 1 (#417) required, Epic 2 (#418) recommended
- Requires: Apple Developer Program + TestFlight testing
- Handles distribution and monetization

## Dependency Chain

```
┌─────────────────────────────────┐
│ Epic 1: Local Persistence       │
│ Status: ⚪ Not started          │
│ Blocks: Epic 2, Epic 3          │
└────────────┬────────────────────┘
             │
             ↓
┌─────────────────────────────────┐
│ Epic 2: CloudKit Sync           │
│ Status: 🔴 Blocked by Epic 1    │
│ Requires: Developer Program     │
│ Blocks: Epic 3 (recommended)    │
└────────────┬────────────────────┘
             │
             ↓
┌─────────────────────────────────┐
│ Epic 3: App Store Production    │
│ Status: 🔴 Blocked by Epic 1    │
│ Requires: Epic 2 (recommended)  │
│ Requires: Developer Program     │
└─────────────────────────────────┘
```

## Issue Structure

Each epic issue includes:
- **Goal**: Clear objective statement
- **Scope**: What's included/excluded
- **Key Deliverables**: Checkbox list of major components
- **Acceptance Criteria**: Testable completion requirements
- **Technical Notes**: Implementation guidance
- **Dependencies**: Explicit blockers and prerequisites
- **Estimated Scope**: Relative sizing

## Labels Applied
- `epic` - Applied to all four issues for easy filtering

## Next Steps

1. **Start Epic 1 (#417)**
   - Review current persistence implementation
   - Audit for CloudKit assumptions
   - Ensure single persistence container initialization
   - Verify offline-first behavior

2. **Apple Developer Program** (if targeting Epic 2 or 3)
   - Enroll in Apple Developer Program ($99/year)
   - Required for CloudKit and App Store distribution

3. **Track Progress**
   - Use issue #420 as master tracking issue
   - Update checkbox items as work completes
   - Close epics when all acceptance criteria met

## Key Principles Encoded in Issues

1. **Offline-First**: Epic 1 ensures full local functionality before sync
2. **Apple-Native**: All epics use only Apple frameworks
3. **Clean Architecture**: Persistence and sync are implementation details
4. **Progressive Enhancement**: Each epic builds on previous without breaking it

## Testing Strategy (Per Epic)

**Epic 1**:
- Test all CRUD operations locally
- Verify app works without network
- Test with Personal Team certificate

**Epic 2**:
- Test sync across multiple devices
- Verify offline behavior still works
- Test conflict resolution

**Epic 3**:
- TestFlight beta testing
- Subscription flow testing (sandbox)
- App Store review preparation

## Timeline Estimates

- **Epic 1**: 2-4 weeks (foundation work, testing required)
- **Epic 2**: 1-2 weeks (mostly configuration, testing sync)
- **Epic 3**: 2-3 weeks (App Store prep, TestFlight, review)

**Total**: ~5-9 weeks for complete production readiness

## Success Metrics

**Epic 1 Complete**:
- App runs on all platforms without paid certificates
- All data persists locally and survives app restarts
- Zero CloudKit dependencies in code

**Epic 2 Complete**:
- Data syncs seamlessly across signed-in devices
- Offline-first behavior unchanged
- No user-facing sync UI needed

**Epic 3 Complete**:
- App live on App Store
- Subscriptions processing correctly
- Positive reviews from TestFlight testers

## Notes

- Epic 2 is optional but strongly recommended before public launch
- All epics maintain clean separation of concerns
- No epic requires rewriting UI or domain models
- Each epic is independently testable and deployable
