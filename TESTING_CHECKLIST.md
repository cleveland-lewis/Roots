# Testing Checklist - Quick Actions, Planner, Filters

## ✅ Implementation Complete - Ready for Testing

All three features are **fully implemented** in the codebase. Use this checklist to verify functionality.

---

## Quick Actions Testing (15 mins)

### From Dashboard
- [ ] Plus menu → Add Course → Opens course form
- [ ] Plus menu → Add Assignment → Opens task form
- [ ] Save course → Toast appears
- [ ] Cancel form → Dismisses cleanly

### From Planner  
- [ ] Plus menu → Add Assignment → Pre-fills today's date
- [ ] Plus menu → Add Task → Same as assignment
- [ ] Save assignment → Toast + dismiss

### From Assignments
- [ ] Plus menu → Add Assignment → Opens form
- [ ] Pre-fills current filtered course (if any)

### From Courses
- [ ] Plus menu → Add Course → Opens form
- [ ] Pre-fills current semester

### Edge Cases
- [ ] Open form, don't fill required fields → Save disabled
- [ ] Open 2 forms rapidly → Only one shows (no double-sheet)
- [ ] Background app while form open → Resume → Form still open

**Pass Criteria:** All quick actions open correct form with smart defaults. No crashes.

---

## Planner Controls Testing (20 mins)

### Edit Mode
- [ ] Tap "Edit" button → Mode toggles
- [ ] Edit mode shows "Done" button
- [ ] View mode: blocks not draggable

### Drag to Reschedule
- [ ] Edit mode → Drag block up → Snaps to 15-min grid
- [ ] Drag block down → Snaps correctly
- [ ] Release drag → Block updates position
- [ ] Drag animation smooth, follows finger

### Conflict Detection
- [ ] Drag block to overlap another → Rejects + toast
- [ ] Drag block before workday start → Rejects + toast  
- [ ] Drag block after workday end → Rejects + toast
- [ ] Valid move → Accepts + updates

### Manual Block Editing
- [ ] Tap block (view mode) → Editor opens
- [ ] Change title → Save → Updates
- [ ] Change start time → Save → Updates
- [ ] Change duration → Save → Updates
- [ ] Toggle lock → Save → Lock persists
- [ ] Set invalid time (overlap) → Save → Toast "Time conflict"
- [ ] Cancel editor → No changes applied

### Persistence
- [ ] Edit block manually → Force quit → Relaunch → Edit preserved
- [ ] Generate plan → User edits preserved (not overwritten)
- [ ] Edit marked with pencil icon indicator

### Edge Cases
- [ ] Drag very fast → Still snaps correctly
- [ ] Edit during schedule generation → No corruption
- [ ] Empty planner → No crashes

**Pass Criteria:** Drag works smoothly, conflicts detected correctly, edits persist.

---

## Filter Testing (15 mins)

### Semester Filter
- [ ] Assignments → "All Semesters" menu → Select one → List updates
- [ ] Planner → Semester filter → Blocks filtered
- [ ] Courses → Semester filter → Courses filtered

### Course Filter
- [ ] Select semester first → Course menu shows only that semester's courses
- [ ] Select course → Assignments filtered to that course
- [ ] Select course → Planner shows only that course's blocks

### Filter Dependency
- [ ] Select Semester A → Select Course X → Change to Semester B
- [ ] **Expected:** Course clears (X not in B)
- [ ] Select invalid combination → App handles gracefully

### Filter UI
- [ ] Chip shows current selection ("Fall 2025" or "All Semesters")
- [ ] Menu lists all options correctly
- [ ] Selection updates immediately (no lag)

### Persistence
- [ ] Set filters → Background app → Foreground → Filters preserved
- [ ] Set filters → Force quit → Relaunch → Filters restored
- [ ] Clear filters → "All Semesters" / "All Courses" shown

### Cross-View Consistency
- [ ] Set semester in Planner → Switch to Assignments → Same semester active
- [ ] Set course in Courses → Switch to Planner → Same course active

### Edge Cases
- [ ] No semesters → Filter disabled or shows empty
- [ ] No courses in semester → Course filter shows empty
- [ ] Delete currently filtered course → Filter auto-clears

**Pass Criteria:** Filters work across all views, dependencies correct, persistence works.

---

## Integration Testing (10 mins)

### Combined Features
- [ ] Filter to course → Quick-add assignment → Auto-selects filtered course
- [ ] Add course via quick action → Immediately filterable
- [ ] Filter tasks → Generate plan → Only filtered tasks scheduled
- [ ] Drag block → Switch tabs → Return → Edit persisted

### Performance
- [ ] 50+ assignments → Filtering still instant
- [ ] 20+ scheduled blocks → Drag still smooth
- [ ] Rapid filter changes → No lag or crash

### Accessibility
- [ ] VoiceOver: Quick actions readable
- [ ] VoiceOver: Drag blocks (use tap + swipe gestures)
- [ ] VoiceOver: Filters announce changes
- [ ] Dynamic Type: Text scales correctly

---

## Regression Testing (5 mins)

Ensure existing features still work:
- [ ] Timer tab functions normally
- [ ] Calendar view loads
- [ ] Settings persist
- [ ] App launches without errors

---

## Summary

**Time Required:** ~65 minutes for complete verification  
**Critical Tests:** Quick actions from all tabs, drag-and-drop, filter persistence  
**Optional:** Accessibility testing can be deferred if time-limited

**Sign-off:**
- [ ] All critical tests passed
- [ ] No crashes or data loss observed
- [ ] Ready for production

**Tester:** ___________________  
**Date:** ___________________  
**Build:** Debug / Release (circle one)
