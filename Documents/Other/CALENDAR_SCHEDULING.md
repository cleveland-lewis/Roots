# Calendar-Aware Scheduling

The School Dashboard scheduler intelligently schedules study blocks around your existing calendar events, ensuring no conflicts and optimal time utilization.

## Overview

The scheduler fetches events from **ALL** your Apple Calendars (via CalDAV) to avoid scheduling conflicts, then creates study blocks for context-specific tasks (School, Training, Research, etc.) in the free time slots available.

**Key Behavior:**
- **Avoids ALL calendar events** from all calendars (School, Training, Research, Personal, etc.)
- **Schedules ONLY tasks** matching the specified category/context
- This ensures School tasks are scheduled around ALL your commitments, not just school events

## How It Works

### 1. Event Loading
The scheduler connects to your Apple Calendar and fetches upcoming events for the specified time period (default: 7 days).

### 2. Free Slot Detection
For each day:
- Starts with your configured work hours (e.g., 9 AM - 5 PM)
- Identifies all calendar events for that day
- Calculates free time slots between events
- Removes slots that are too small for productive work

### 3. Block Generation
Within each free slot:
- Creates study blocks of configurable duration (default: 50 minutes)
- Adds breaks between blocks (default: 10 minutes)
- Ensures blocks fit entirely within the available time

### 4. Assignment Allocation
- Sorts assignments by urgency (priority, deadline proximity, remaining effort)
- Assigns highest-priority tasks to available blocks
- Continues until all blocks are allocated or assignments completed

## API Endpoints

### GET /api/calendars
Returns a list of all available calendars.

**Response:**
```json
{
  "success": true,
  "calendars": [
    {"name": "School", "url": "..."},
    {"name": "Training", "url": "..."},
    {"name": "Research", "url": "..."}
  ]
}
```

### GET /api/schedule
Generates a schedule for the specified period.

**Query Parameters:**
- `days` (optional): Number of days to schedule (1-14, default: 7)
- `calendars` (optional): Comma-separated list of calendar names to include

**Examples:**
```bash
# Schedule for next 7 days using all events
GET /api/schedule

# Schedule for next 3 days
GET /api/schedule?days=3

# Schedule around only "School" calendar events
GET /api/schedule?calendars=School

# Schedule around multiple specific calendars
GET /api/schedule?calendars=School,Training,Research
```

**Response:**
```json
{
  "success": true,
  "days": 7,
  "calendars_used": ["School"],
  "generated_blocks": 28,
  "time_blocks": [
    {
      "id": 1,
      "title": "Biology: Chapter 1 Reading",
      "start": "2025-01-15T09:00:00",
      "end": "2025-01-15T09:50:00",
      "kind": "task",
      "assignment_id": 1,
      "locked": false
    }
  ],
  "fixed_events": [
    {
      "title": "Bio Lecture",
      "start": "2025-01-15T10:00:00",
      "end": "2025-01-15T11:30:00"
    }
  ]
}
```

## Calendar Filtering

### Use Cases

#### 1. School-Only Scheduling
Schedule study blocks around only academic events:
```bash
GET /api/schedule?calendars=School
```

#### 2. Training-Only Scheduling
Schedule workouts around only training-related events:
```bash
GET /api/schedule?calendars=Training
```

#### 3. Research-Only Scheduling
Schedule research tasks around only research calendar events:
```bash
GET /api/schedule?calendars=Research
```

#### 4. Multi-Calendar Scheduling
Schedule tasks around events from multiple specific calendars:
```bash
GET /api/schedule?calendars=School,Training
```

## Configuration

### Environment Variables

- `CALENDAR_NAME`: Default calendar to use (if not filtering by multiple calendars)
- `DEFAULT_WORK_START`: Default start time for scheduling (format: "HH:MM", e.g., "08:00")
- `DEFAULT_WORK_END`: Default end time for scheduling (format: "HH:MM", e.g., "17:00")
- `WEEKEND_WORK_START`: Weekend start time
- `WEEKEND_WORK_END`: Weekend end time

### Settings

The following settings control scheduling behavior:

- **Default block duration** (`default_block_duration`): Length of each study block in minutes (default: 50)
- **Break duration** (`break_duration`): Length of breaks between blocks in minutes (default: 10)

These can be configured in the Settings page under "General → Time & Schedule".

## Scheduling Algorithm

### Urgency Score Formula
```python
urgency_score = (priority × 10) + (20 / days_until_due) + (5 × remaining_hours)
```

Where:
- `priority`: 1-5 (5 = highest priority)
- `days_until_due`: Days between now and assignment due date
- `remaining_hours`: Hours of work remaining on the assignment

### Free Slot Generation Algorithm

1. **Define day bounds**: Use configured work start/end times
2. **Load calendar events**: Fetch events for the target day
3. **Sort events**: Order by start time
4. **Calculate gaps**:
   - Start with cursor at day start
   - For each event:
     - If event starts after cursor, create a free slot from cursor to event start
     - Move cursor to event end (or keep current cursor if event ends earlier)
   - After all events, create final slot from cursor to day end
5. **Filter slots**: Remove slots too small to fit a study block

### Block Slicing Algorithm

For each free slot:
1. Start cursor at slot start
2. While `cursor + block_duration <= slot_end`:
   - Create block from cursor to cursor + block_duration
   - Move cursor forward by block_duration + break_duration
3. Return all created blocks

### Assignment Allocation

1. Generate all available blocks for the scheduling period
2. Sort assignments by urgency score (highest first)
3. For each block:
   - Find the highest-urgency assignment with remaining work
   - Skip assignments with due dates in the past
   - Skip assignments already completed
   - Assign that assignment to the block
4. Include all fixed events as locked blocks

## Testing

The scheduler includes comprehensive tests to verify correct behavior:

```bash
# Run scheduler tests
python3 -m pytest tests/test_scheduler_calendar.py -v
```

### Test Coverage

- ✅ Free slot generation with no events
- ✅ Free slot generation with single event
- ✅ Free slot generation with multiple events
- ✅ Handling of overlapping events
- ✅ Filtering events from other days
- ✅ Block slicing with standard durations
- ✅ Block slicing with custom durations
- ✅ Full scheduling avoiding calendar events
- ✅ Urgency score calculation

## Examples

### Example 1: Typical Weekday Schedule

**Calendar Events:**
- 10:00-11:30: Biology Lecture
- 12:00-13:00: Lunch Meeting
- 14:00-16:00: Chemistry Lab

**Generated Schedule (9 AM - 5 PM):**
```
09:00-09:50  Study Block: Chemistry Problem Set 2
[10 min break]
10:00-11:30  [FIXED] Biology Lecture
11:30-11:50  Study Block: Biology Chapter 1
[10 min break]
12:00-13:00  [FIXED] Lunch Meeting
13:00-13:50  Study Block: Physics Homework
[10 min break]
14:00-16:00  [FIXED] Chemistry Lab
16:00-16:50  Study Block: Math Assignment
[end of day]
```

### Example 2: Light Day Schedule

**Calendar Events:**
- 10:00-11:00: Office Hours

**Generated Schedule (9 AM - 5 PM):**
```
09:00-09:50  Study Block 1
[10 min break]
10:00-11:00  [FIXED] Office Hours
11:00-11:50  Study Block 2
[10 min break]
12:00-12:50  Study Block 3
[10 min break]
13:00-13:50  Study Block 4
[10 min break]
14:00-14:50  Study Block 5
[10 min break]
15:00-15:50  Study Block 6
[10 min break]
16:00-16:50  Study Block 7
```

### Example 3: Calendar-Specific Scheduling

**Scenario:** You want to schedule research work around only research-related events, ignoring school classes.

**Request:**
```bash
GET /api/schedule?calendars=Research&days=7
```

**Result:** Study blocks are generated avoiding only events in the "Research" calendar, while events in "School" and "Training" calendars are ignored.

## Best Practices

1. **Use calendar filtering** to create context-specific schedules:
   - "School" calendar for academic scheduling
   - "Training" calendar for workout scheduling
   - "Research" calendar for research task scheduling

2. **Set realistic work hours** that match your actual availability

3. **Keep calendar events updated** so the scheduler has accurate information

4. **Review generated schedules** and adjust block durations based on your focus capacity

5. **Use priority levels** effectively to ensure important work gets scheduled first

6. **Break large assignments** into subtasks for better scheduling granularity

## Troubleshooting

### No blocks generated
- Check that you have assignments with status != "done"
- Verify calendar events aren't filling your entire day
- Check DEFAULT_WORK_START and DEFAULT_WORK_END settings

### Blocks overlapping with events
- This should never happen - if it does, it's a bug
- Run `pytest tests/test_scheduler_calendar.py` to verify algorithm
- Check logs for calendar fetching errors

### Missing calendar events
- Verify CalDAV credentials are correct
- Check that CALENDAR_NAME matches your actual calendar name
- Use `/api/calendars` to list available calendars

### Wrong calendar being used
- Use the `calendars` query parameter to specify exact calendars
- Check CALENDAR_NAME environment variable
- Verify calendar names match exactly (case-sensitive)

## Future Enhancements

- [ ] Support for recurring time preferences (e.g., "no meetings before 10 AM on Mondays")
- [ ] Integration with Settings page to configure work hours per day of week
- [ ] UI calendar picker for filtering calendars
- [ ] Visual calendar view showing scheduled blocks
- [ ] Automatic rescheduling when calendar events change
- [ ] Support for "focus time" blocks that prevent scheduling
- [ ] Machine learning to optimize block allocation based on historical completion rates
