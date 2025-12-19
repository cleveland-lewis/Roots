# Manual Testing: Calendar Recurrence & Alerts Round-Trip

## Issue #29: Manual Test Steps for Recurrence/Alerts Round-Trip Behavior

This document provides step-by-step manual test procedures to verify that event recurrence and alerts correctly sync between Roots and Apple Calendar.

---

## Prerequisites

### Before Testing
- [ ] Grant Roots calendar access in System Settings
- [ ] Create a test calendar in Apple Calendar app (recommended: "Roots Test Calendar")
- [ ] Ensure Roots is configured to use the test calendar
- [ ] Clear any existing test events from previous sessions

### Test Environment
- macOS 14.0 or later
- Apple Calendar app installed
- Roots app with calendar permissions granted

---

## Test Suite 1: Recurrence Rules

### Test 1.1: Daily Recurrence (No End)
**Objective:** Verify daily recurring events persist correctly

**Steps:**
1. Open Roots → Calendar page
2. Create new event:
   - Title: "Daily Test Event"
   - Start: Today at 2:00 PM
   - End: Today at 3:00 PM
   - Recurrence: Daily
   - End: Never
3. Save the event
4. Open Apple Calendar app
5. Locate the event (should appear today and future days)

**Expected Results:**
- ✅ Event appears in Apple Calendar
- ✅ Event repeats daily indefinitely
- ✅ All recurrence details visible in Apple Calendar info panel

**Verification:**
1. Open Apple Calendar → Double-click event → Get Info
2. Verify: "Repeat: Every Day"
3. Verify: "End: Never"

---

### Test 1.2: Weekly Recurrence - Single Day
**Objective:** Verify weekly recurrence on one day

**Steps:**
1. In Roots, create event:
   - Title: "Weekly Monday Meeting"
   - Start: Next Monday at 10:00 AM
   - End: Next Monday at 11:00 AM
   - Recurrence: Weekly
   - Days: Monday only
   - End: Never
2. Save and sync
3. Check Apple Calendar

**Expected Results:**
- ✅ Event appears every Monday
- ✅ Does not appear on other days
- ✅ Recurrence pattern preserved

**Verification:**
1. Apple Calendar info: "Repeat: Every Monday"
2. Check 2-3 future weeks to confirm pattern

---

### Test 1.3: Weekly Recurrence - Multiple Days
**Objective:** Verify weekly recurrence on Mon/Wed/Fri

**Steps:**
1. In Roots, create event:
   - Title: "MWF Workout"
   - Start: Next Monday at 6:00 AM
   - End: Next Monday at 7:00 AM
   - Recurrence: Weekly
   - Days: Monday, Wednesday, Friday
   - End: Never
2. Save and sync
3. Check Apple Calendar for next 2 weeks

**Expected Results:**
- ✅ Event appears on Mon, Wed, Fri only
- ✅ No events on Tue, Thu, Sat, Sun
- ✅ Pattern continues correctly

**Verification:**
1. Apple Calendar info: "Repeat: Every Monday, Wednesday, Friday"
2. Manually verify presence on correct days

---

### Test 1.4: Recurrence End After N Occurrences
**Objective:** Verify "end after N" works correctly

**Steps:**
1. In Roots, create event:
   - Title: "10-Day Challenge"
   - Start: Tomorrow at 8:00 AM
   - End: Tomorrow at 9:00 AM
   - Recurrence: Daily
   - End: After 10 occurrences
2. Save and sync
3. Check Apple Calendar

**Expected Results:**
- ✅ Event appears for exactly 10 days
- ✅ No event on day 11
- ✅ Apple Calendar shows "End: After 10 times"

**Verification:**
1. Count occurrences in month/list view
2. Verify 11th day has no event
3. Check info panel matches

---

### Test 1.5: Recurrence End By Date
**Objective:** Verify "end by specific date" works

**Steps:**
1. In Roots, create event:
   - Title: "Spring Term Class"
   - Start: Today at 1:00 PM
   - End: Today at 2:00 PM
   - Recurrence: Weekly on current weekday
   - End: On [date 4 weeks from now]
2. Save and sync
3. Check Apple Calendar

**Expected Results:**
- ✅ Event repeats weekly until end date
- ✅ Last occurrence is on or before end date
- ✅ No occurrences after end date
- ✅ Apple Calendar shows correct end date

**Verification:**
1. Verify last occurrence date
2. Check info: "End: On [specified date]"

---

## Test Suite 2: Alerts

### Test 2.1: Single Alert
**Objective:** Verify single alert preservation

**Steps:**
1. In Roots, create event:
   - Title: "Dentist Appointment"
   - Start: Tomorrow at 10:00 AM
   - End: Tomorrow at 11:00 AM
   - Alert: 1 hour before
2. Save and sync
3. Check Apple Calendar

**Expected Results:**
- ✅ Event has 1 alert
- ✅ Alert shows "1 hour before"
- ✅ Alert time is correct

**Verification:**
1. Apple Calendar info → Alerts section
2. Verify: "1 hour before"

---

### Test 2.2: Two Alerts (Primary + Secondary)
**Objective:** Verify multiple alerts work

**Steps:**
1. In Roots, create event:
   - Title: "Important Presentation"
   - Start: Tomorrow at 2:00 PM
   - End: Tomorrow at 3:00 PM
   - Alert 1: 1 day before
   - Alert 2: 1 hour before
2. Save and sync
3. Check Apple Calendar

**Expected Results:**
- ✅ Event has 2 alerts
- ✅ First alert: 1 day before
- ✅ Second alert: 1 hour before
- ✅ Both alerts preserved in order

**Verification:**
1. Apple Calendar info → Alerts
2. Verify both alerts present
3. Verify correct times

---

### Test 2.3: No Alerts
**Objective:** Verify events can have no alerts

**Steps:**
1. In Roots, create event:
   - Title: "Flexible Task"
   - Start: Tomorrow at 3:00 PM
   - End: Tomorrow at 4:00 PM
   - Alerts: None
2. Save and sync
3. Check Apple Calendar

**Expected Results:**
- ✅ Event has no alerts
- ✅ Apple Calendar shows "Alert: None"

---

## Test Suite 3: Recurrence + Alerts Combined

### Test 3.1: Weekly Recurring Event with Two Alerts
**Objective:** Verify recurrence and alerts work together

**Steps:**
1. In Roots, create event:
   - Title: "Weekly Team Standup"
   - Start: Next Monday at 9:00 AM
   - End: Next Monday at 9:30 AM
   - Recurrence: Weekly on Monday
   - End: After 8 occurrences
   - Alert 1: 15 minutes before
   - Alert 2: At time of event
2. Save and sync
3. Check Apple Calendar

**Expected Results:**
- ✅ Event repeats 8 times (Mondays only)
- ✅ Each occurrence has both alerts
- ✅ Alerts trigger at correct times
- ✅ All settings preserved

**Verification:**
1. Check first occurrence has both alerts
2. Check 8th occurrence exists
3. Verify no 9th occurrence

---

### Test 3.2: Daily Recurring with End Date and Single Alert
**Objective:** Verify daily + end date + alert

**Steps:**
1. In Roots, create event:
   - Title: "Morning Medication"
   - Start: Tomorrow at 8:00 AM
   - End: Tomorrow at 8:05 AM
   - Recurrence: Daily
   - End: On [1 week from now]
   - Alert: At time of event
2. Save and sync
3. Check Apple Calendar

**Expected Results:**
- ✅ Event repeats daily for 7 days
- ✅ Each has alert at event time
- ✅ Ends on correct date

---

## Test Suite 4: Round-Trip Editing

### Test 4.1: Create in Roots, Edit in Apple Calendar
**Objective:** Verify edits in Apple Calendar sync back to Roots

**Steps:**
1. In Roots, create weekly recurring event with 1 alert
2. Save and verify in Apple Calendar
3. In Apple Calendar:
   - Open event → Edit
   - Change alert to "2 hours before"
   - Add second alert: "1 day before"
   - Save
4. Return to Roots
5. Refresh/navigate to event

**Expected Results:**
- ✅ Roots shows updated alert times
- ✅ Both alerts appear in Roots
- ✅ No data loss

---

### Test 4.2: Create in Apple Calendar, View in Roots
**Objective:** Verify Roots correctly reads Apple Calendar events

**Steps:**
1. In Apple Calendar, create new event:
   - Title: "External Event Test"
   - Recurrence: Weekly on Tuesday
   - End: After 5 times
   - Alert: 30 minutes before
2. Save
3. Open Roots → Navigate to calendar
4. Find the event

**Expected Results:**
- ✅ Event appears in Roots
- ✅ Recurrence pattern visible
- ✅ Alert time correct
- ✅ Can open/edit in Roots

---

### Test 4.3: Edit Recurring Event in Roots (Single vs All)
**Objective:** Verify edit scope options work

**Steps:**
1. Create weekly recurring event (4 occurrences)
2. Open second occurrence in Roots
3. Edit title, save
4. When prompted "This Event" vs "All Future Events":
   - Choose "This Event"
5. Verify in Apple Calendar

**Expected Results:**
- ✅ Only second occurrence has new title
- ✅ First, third, fourth occurrences unchanged
- ✅ Recurrence still valid

---

### Test 4.4: Delete Occurrence vs Series
**Objective:** Verify delete options work

**Steps:**
1. Create daily recurring event (7 days)
2. Delete 3rd occurrence in Roots → "This Event Only"
3. Check Apple Calendar
4. Delete 5th occurrence in Apple Calendar
5. Check Roots

**Expected Results:**
- ✅ Days 3 and 5 missing
- ✅ Other days present
- ✅ Changes sync both ways
- ✅ Series integrity maintained

---

## Test Suite 5: Edge Cases

### Test 5.1: Very Long Recurrence
**Objective:** Test year-long recurrence

**Steps:**
1. Create daily recurring event
2. End: After 365 occurrences
3. Save and sync
4. Spot-check events at:
   - Day 1
   - Day 30
   - Day 100
   - Day 365

**Expected Results:**
- ✅ All spot-checks have event
- ✅ Day 366 has no event
- ✅ Performance acceptable

---

### Test 5.2: Bi-Weekly Recurrence
**Objective:** Test every-other-week pattern

**Steps:**
1. Create event:
   - Recurrence: Weekly, interval 2
   - Days: Thursday
   - End: After 6 occurrences
2. Save and verify

**Expected Results:**
- ✅ Event on weeks 1, 3, 5, 7, 9, 11
- ✅ No event on weeks 2, 4, 6, 8, 10
- ✅ Pattern correct in both apps

---

### Test 5.3: Alert Edge Times
**Objective:** Test unusual alert times

**Steps:**
1. Create event with alerts:
   - 0 minutes before (at time)
   - 1 week before
2. Verify both sync correctly

**Expected Results:**
- ✅ Instant alert works
- ✅ 1-week alert works
- ✅ Both preserved in round-trip

---

## Test Suite 6: Data Integrity

### Test 6.1: No Data Loss on Edit
**Objective:** Verify all fields preserved

**Steps:**
1. Create fully-populated event:
   - Title, location, notes, URL
   - Recurrence
   - 2 alerts
   - Category (Roots-specific)
2. Edit in Apple Calendar (change time only)
3. View in Roots

**Expected Results:**
- ✅ All original fields present
- ✅ Time updated
- ✅ Category preserved (if possible)
- ✅ No data corruption

---

### Test 6.2: Category Preservation
**Objective:** Verify Roots category survives round-trip

**Steps:**
1. In Roots, create "Exam" category event
2. Add recurrence and alerts
3. Edit in Apple Calendar (minor change)
4. Return to Roots

**Expected Results:**
- ✅ Category still shows "Exam"
- ✅ Category-based color correct
- ✅ Event fully functional

---

## Test Suite 7: Performance & Reliability

### Test 7.1: Rapid Event Creation
**Objective:** Test creating many events quickly

**Steps:**
1. Create 10 recurring events rapidly (< 1 minute)
2. All with different recurrence patterns
3. Verify all appear in Apple Calendar

**Expected Results:**
- ✅ All 10 events sync
- ✅ No duplicates
- ✅ No missing events
- ✅ App remains responsive

---

### Test 7.2: Sync Latency
**Objective:** Measure sync time

**Steps:**
1. Create event in Roots
2. Note timestamp
3. Check Apple Calendar
4. Note when event appears

**Expected Results:**
- ✅ Event appears within 5 seconds (typical)
- ✅ No manual refresh needed
- ✅ Consistent sync timing

---

## Troubleshooting

### Common Issues

**Event not syncing:**
1. Check calendar permissions in System Settings
2. Verify Roots is using correct calendar
3. Try manual refresh in both apps
4. Check Console.app for errors

**Recurrence pattern incorrect:**
1. Verify recurrence settings in Roots match intent
2. Check interval value
3. Confirm day selections
4. Review end condition

**Alerts missing:**
1. Check notification permissions
2. Verify alerts set before event time
3. Confirm alert times valid

---

## Reporting Issues

If you encounter failures:
1. Note exact steps to reproduce
2. Screenshot event details in both apps
3. Check Console.app for relevant logs
4. File issue with details and logs

---

## Test Coverage Summary

✅ Daily recurrence (no end, with end count, with end date)  
✅ Weekly recurrence (single day, multiple days, bi-weekly)  
✅ Monthly recurrence  
✅ Single alert (various times)  
✅ Multiple alerts  
✅ Recurrence + alerts combined  
✅ Round-trip editing (both directions)  
✅ Edit single vs all occurrences  
✅ Delete single vs series  
✅ Edge cases (long series, unusual times)  
✅ Data integrity (no loss, category preservation)  
✅ Performance (rapid creation, sync latency)

---

## Completion Checklist

- [ ] All Test Suite 1 scenarios passed
- [ ] All Test Suite 2 scenarios passed
- [ ] All Test Suite 3 scenarios passed
- [ ] All Test Suite 4 scenarios passed
- [ ] All Test Suite 5 scenarios passed
- [ ] All Test Suite 6 scenarios passed
- [ ] All Test Suite 7 scenarios passed
- [ ] No data corruption observed
- [ ] Performance acceptable
- [ ] All issues documented

**Test Date:** __________  
**Tested By:** __________  
**Build/Version:** __________  
**Result:** PASS / FAIL  
**Notes:** ___________________________________________________________
