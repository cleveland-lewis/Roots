# Roots Testing Guide

## Manual Testing Checklist

This document provides comprehensive manual test procedures for verifying critical functionality in Roots, particularly around event recurrence and alerts integration with Apple Calendar.

## Recurrence + Alerts Round-Trip Testing

### Prerequisites
- Roots app installed and running
- Apple Calendar app accessible
- Calendar permissions granted to Roots
- School calendar configured in Roots settings

---

## Test Suite 1: Basic Recurrence Round-Trip

### Test 1.1: Daily Recurrence
**Create in Roots:**
1. Open AddEventPopup (+ button)
2. Title: "Daily Standup"
3. Set start time: 9:00 AM tomorrow
4. Set "Repeat": Daily
5. Set "Every": 1 day
6. Add Primary Alert: 15 minutes before
7. Save

**Verify in Apple Calendar:**
1. Open Apple Calendar app
2. Locate "Daily Standup" event
3. Open event details
4. ✅ Verify recurrence: "Every day"
5. ✅ Verify alert: 15 minutes before
6. ✅ Verify calendar: School calendar

**Edit in Apple Calendar:**
1. Change alert to 30 minutes before
2. Save

**Verify in Roots:**
1. Return to Roots calendar view
2. Find "Daily Standup" event
3. Open event details
4. ✅ Verify alert updated: 30 minutes before
5. ✅ Verify recurrence intact: Daily

---

### Test 1.2: Weekly Recurrence - Single Day
**Create in Roots:**
1. New event: "Weekly Team Meeting"
2. Start: Next Monday 2:00 PM
3. Duration: 1 hour
4. Repeat: Weekly
5. Every: 1 week
6. Primary alert: 1 hour before
7. Secondary alert: 15 minutes before
8. Save

**Verify in Apple Calendar:**
1. ✅ Verify recurrence: "Every Monday"
2. ✅ Verify both alerts present
3. ✅ Check future occurrences visible

**Edit in Apple Calendar:**
1. Change time to 3:00 PM
2. Apply to "This and all future events"
3. Save

**Verify in Roots:**
1. ✅ Verify time updated: 3:00 PM
2. ✅ Verify both alerts preserved
3. ✅ Verify recurrence intact

---

### Test 1.3: Weekly Recurrence - Multiple Days
**Create in Roots:**
1. New event: "Workout Session"
2. Start: Next Monday 6:00 AM
3. Duration: 1 hour
4. Repeat: Weekly
5. Every: 1 week
6. Select weekdays: Monday, Wednesday, Friday (✓✓✓)
7. Primary alert: At time of event
8. Save

**Verify in Apple Calendar:**
1. ✅ Verify recurrence: "Every Monday, Wednesday, Friday"
2. ✅ Verify alert: At time of event
3. ✅ Check three events appear in first week

**Edit in Apple Calendar:**
1. Add another alert: 10 minutes before
2. Apply to all future events
3. Save

**Verify in Roots:**
1. Open event details
2. ✅ Verify primary alert: At time of event
3. ✅ Verify secondary alert: 10 minutes before
4. ✅ Verify weekday selection intact

---

## Test Suite 2: Recurrence End Conditions

### Test 2.1: End After N Occurrences
**Create in Roots:**
1. New event: "Project Sprint Review"
2. Start: Next Monday 10:00 AM
3. Repeat: Weekly
4. Every: 2 weeks
5. End: After 5 occurrences
6. Primary alert: 1 day before
7. Save

**Verify in Apple Calendar:**
1. ✅ Verify recurrence: "Every 2 weeks"
2. ✅ Count future occurrences: exactly 5
3. ✅ Verify last occurrence date is 8 weeks from start
4. ✅ Verify alert on all occurrences

**Edit in Apple Calendar:**
1. Change to 10 occurrences
2. Save

**Verify in Roots:**
1. Open event details
2. ✅ Verify recurrence end count updated: 10 occurrences

---

### Test 2.2: End By Specific Date
**Create in Roots:**
1. New event: "Summer Reading Club"
2. Start: Next week, 3:00 PM
3. Repeat: Weekly
4. Every: 1 week
5. End: By date (set to 3 months from start)
6. Primary alert: 2 hours before
7. Save

**Verify in Apple Calendar:**
1. ✅ Verify recurrence end date matches
2. ✅ Count occurrences (should be ~13 for 3 months)
3. ✅ Verify no occurrences after end date
4. ✅ Verify alert on all occurrences

**Edit in Apple Calendar:**
1. Extend end date by 2 weeks
2. Save

**Verify in Roots:**
1. ✅ Verify additional 2 weekly occurrences appear
2. ✅ Verify alerts preserved on new occurrences

---

## Test Suite 3: Alert Configurations

### Test 3.1: No Alerts
**Create in Roots:**
1. New event: "Personal Time"
2. Start: Tomorrow 7:00 PM
3. Repeat: None
4. Alerts: None (leave both empty)
5. Save

**Verify in Apple Calendar:**
1. ✅ Verify no alerts set
2. Edit event in Calendar
3. ✅ Verify alert field shows "None"

**Edit in Apple Calendar:**
1. Add alert: 15 minutes before
2. Save

**Verify in Roots:**
1. ✅ Verify alert appears: 15 minutes before

---

### Test 3.2: Single Alert
**Create in Roots:**
1. New event: "Doctor Appointment"
2. Start: Next week, 2:00 PM
3. Primary alert: 1 day before
4. Secondary alert: None
5. Save

**Verify in Apple Calendar:**
1. ✅ Verify exactly one alert: 1 day before
2. Edit event
3. ✅ Verify no second alert

**Edit in Apple Calendar:**
1. Change alert to 2 days before
2. Save

**Verify in Roots:**
1. ✅ Verify alert updated: 2 days before
2. ✅ Verify still only one alert

---

### Test 3.3: Two Alerts (Primary + Secondary)
**Create in Roots:**
1. New event: "Flight Departure"
2. Start: Next month, 6:00 AM
3. Primary alert: 1 day before
4. Secondary alert: 2 hours before
5. Save

**Verify in Apple Calendar:**
1. ✅ Verify two alerts present
2. ✅ Verify order: 1 day, then 2 hours
3. Edit event

**Edit in Apple Calendar:**
1. Remove 2-hour alert
2. Add new alert: 30 minutes before
3. Save

**Verify in Roots:**
1. ✅ Verify primary alert: 1 day before
2. ✅ Verify secondary alert: 30 minutes before

---

## Test Suite 4: Complex Scenarios

### Test 4.1: Monthly Recurrence with Alerts
**Create in Roots:**
1. New event: "Monthly Budget Review"
2. Start: First Monday of next month, 9:00 AM
3. Repeat: Monthly
4. Every: 1 month
5. End: After 12 occurrences
6. Primary alert: 1 week before
7. Secondary alert: 1 day before
8. Save

**Verify in Apple Calendar:**
1. ✅ Verify recurrence: "Every month"
2. ✅ Verify 12 total occurrences
3. ✅ Verify both alerts on all occurrences
4. Edit first occurrence only
5. Change time to 10:00 AM
6. Save

**Verify in Roots:**
1. ✅ Verify first occurrence time: 10:00 AM
2. ✅ Verify future occurrences still 9:00 AM
3. ✅ Verify alerts preserved on all

---

### Test 4.2: Edit Recurrence Pattern Mid-Series
**Create in Roots:**
1. New event: "Training Session"
2. Start: Next Monday, 1:00 PM
3. Repeat: Weekly
4. Every: 1 week
5. End: After 10 occurrences
6. Alert: 30 minutes before
7. Save

**Verify in Apple Calendar:**
1. ✅ Verify 10 occurrences created
2. Edit 5th occurrence
3. Change to "All future events"
4. Change repeat to every 2 weeks
5. Save

**Verify in Roots:**
1. ✅ Verify first 4 occurrences: weekly
2. ✅ Verify occurrences 5+: bi-weekly
3. ✅ Verify alerts preserved throughout

---

### Test 4.3: Delete Single Occurrence
**Create in Roots:**
1. New event: "Daily Check-in"
2. Start: Tomorrow, 9:00 AM
3. Repeat: Daily
4. End: After 7 occurrences
5. Alert: 10 minutes before
6. Save

**Verify in Apple Calendar:**
1. ✅ Verify 7 daily occurrences
2. Delete the 3rd occurrence only
3. Confirm delete

**Verify in Roots:**
1. ✅ Verify 6 occurrences remain
2. ✅ Verify gap on day 3
3. ✅ Verify remaining occurrences unchanged

---

## Test Suite 5: Edge Cases

### Test 5.1: All-Day Recurring Event with Alerts
**Create in Roots:**
1. New event: "Vacation Days"
2. Toggle: All-day ON
3. Start: Next week
4. Duration: 1 day
5. Repeat: Daily
6. End: After 5 occurrences
7. Primary alert: 1 day before at 9:00 AM
8. Save

**Verify in Apple Calendar:**
1. ✅ Verify shows as all-day events
2. ✅ Verify 5 consecutive days
3. ✅ Verify alerts at 9:00 AM day before each

**Edit in Apple Calendar:**
1. Change duration to 2 days per occurrence
2. Save

**Verify in Roots:**
1. ✅ Verify each occurrence spans 2 days
2. ✅ Verify alerts still at 9:00 AM

---

### Test 5.2: Event with Location, Notes, and URL
**Create in Roots:**
1. New event: "Conference Workshop"
2. Start: Next month, 2:00 PM
3. Location: "Convention Center Room 301"
4. Notes: "Bring laptop and charger"
5. URL: "https://conference.example.com"
6. Repeat: None
7. Primary alert: 1 hour before
8. Save

**Verify in Apple Calendar:**
1. ✅ Verify location displayed
2. ✅ Verify notes visible
3. ✅ Verify URL clickable
4. ✅ Verify alert present
5. Edit event
6. Add recurrence: Weekly for 4 weeks
7. Save

**Verify in Roots:**
1. ✅ Verify 4 weekly occurrences
2. ✅ Verify all have location, notes, URL
3. ✅ Verify all have alert

---

### Test 5.3: Convert Non-Recurring to Recurring
**Create in Roots:**
1. New event: "Team Sync"
2. Start: Tomorrow, 10:00 AM
3. Repeat: None
4. Alert: 15 minutes before
5. Save

**Edit in Apple Calendar:**
1. Open event
2. Add recurrence: Weekly, every Monday
3. End: After 8 occurrences
4. Save

**Verify in Roots:**
1. ✅ Verify event now shows recurrence
2. ✅ Verify 8 weekly occurrences
3. ✅ Verify alert on all occurrences
4. Edit in Roots
5. Change alert to 30 minutes before
6. Save

**Verify in Apple Calendar:**
1. ✅ Verify alert updated on all occurrences

---

## Test Suite 6: Category Integration

### Test 6.1: Recurring Event with Category
**Create in Roots:**
1. New event: "Homework Review"
2. Category: Study
3. Start: Next Monday, 4:00 PM
4. Repeat: Weekly
5. End: After 15 occurrences
6. Alert: 1 hour before
7. Save

**Verify in Apple Calendar:**
1. ✅ Verify 15 occurrences created
2. ✅ Verify category stored in notes (hidden marker)
3. Edit event
4. Change time to 5:00 PM (all future)
5. Save

**Verify in Roots:**
1. ✅ Verify time updated: 5:00 PM
2. ✅ Verify category still: Study
3. ✅ Verify category visible in UI

---

## Failure Mode Testing

### Failure Test 1: Rapid Editing
**Procedure:**
1. Create recurring event in Roots
2. Immediately open in Apple Calendar
3. Edit without waiting for sync
4. Save in both apps nearly simultaneously

**Expected:**
- ✅ Last write wins (no crash)
- ✅ EventKit resolves conflicts gracefully
- ✅ Roots refreshes to show final state

---

### Failure Test 2: Invalid Recurrence Pattern
**Procedure:**
1. Create event in Apple Calendar
2. Set recurrence: Every weekday (Mon-Fri)
3. View in Roots

**Expected:**
- ✅ Roots displays recurrence correctly
- ✅ No data loss when editing other fields

---

### Failure Test 3: Excessive Alerts
**Procedure:**
1. Create event in Apple Calendar
2. Add 5 different alerts
3. View in Roots

**Expected:**
- ✅ Roots shows primary and secondary alerts
- ✅ Additional alerts preserved in EventKit
- ✅ No crash or data corruption

---

## Regression Checklist

Before each release, verify:

- [ ] Daily recurrence works
- [ ] Weekly recurrence with multiple days works
- [ ] Monthly recurrence works
- [ ] Recurrence end conditions work (count and date)
- [ ] Primary alert preserved
- [ ] Secondary alert preserved
- [ ] No alerts preserved
- [ ] Edit in Roots → verify in Calendar
- [ ] Edit in Calendar → verify in Roots
- [ ] Delete single occurrence works
- [ ] Delete all occurrences works
- [ ] Category survives round-trip
- [ ] Location, notes, URL survive round-trip
- [ ] All-day events work correctly

---

## Test Environment Notes

### System Requirements
- macOS 13.0+ (for EventKit compatibility)
- Xcode 15.0+ (for testing)
- Apple Calendar app

### Known Limitations
- Some recurrence patterns (e.g., "2nd Tuesday of month") may not be fully supported in UI but are preserved in EventKit
- Alerts beyond 2 may be stored but only first 2 editable in Roots
- Custom recurrence rules from other apps are preserved but may not be editable

### Troubleshooting
- If events don't appear: Check calendar permissions
- If edits don't sync: Force refresh in Roots (pull-to-refresh)
- If recurrence breaks: Check EventKit console logs
- If alerts missing: Verify notification permissions

---

## Automated Testing Coverage

See `RootsTests/CalendarRecurrenceTests.swift` for automated unit tests covering:
- Recurrence rule conversion
- Alert mapping fidelity
- Category encoding/decoding
- Edge case handling

Manual testing complements automated tests by verifying actual Apple Calendar integration.
