# ISSUE-406 — Core Data + CloudKit Sync Foundation

## Container
- iCloud container ID: `iCloud.com.cwlewisiii.Roots`

## Model v1
Entities:
- Course
- Assignment
- Task
- TimerSession

Common fields (all):
- `id: UUID`
- `createdAt: Date`
- `updatedAt: Date`

Relationships:
- Course 1 → many Assignments (optional)
- Course 1 → many Tasks (optional)
- Assignment → Course (optional)
- Assignment 1 → many Tasks (optional)
- Task → Course (optional)
- Task → Assignment (optional)
- Task 1 → many TimerSessions (optional)
- TimerSession → Task (optional)

## Merge policy + history tracking
- `NSMergeByPropertyObjectTrumpMergePolicy` for `viewContext` and background contexts
- `automaticallyMergesChangesFromParent = true`
- History tracking + remote change notifications enabled

## Migrations baseline
- Lightweight migration enabled
- Rule: increment model version for any schema change

## Smoke plan (manual)
1. Run on iPhone, create a Course and Assignment.
2. Verify objects appear on macOS within a short interval.
3. Update assignment title on macOS and verify on iPhone.
4. Delete on one device and confirm removal on the other.

## Notes
- AlarmKit/ActivityKit unaffected; sync uses CloudKit mirroring.
