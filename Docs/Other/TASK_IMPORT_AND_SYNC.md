## Task Import & Apple Reminders Sync

Comprehensive guide for importing tasks from files and syncing with Apple Reminders.

## Overview

The School Dashboard supports importing tasks from structured files (text, JSON, YAML) and automatically syncing them to Apple Reminders for notifications and cross-device access.

**Key Features:**
- Parse tasks from multiple file formats (`.txt`, `.md`, `.json`, `.yaml`)
- Intelligent task type detection (exam, quiz, homework, study session, project)
- Automatic course/term assignment
- One-way sync to Apple Reminders (high-priority tasks only)
- Batch import with error handling

## File Formats

### 1. Text/Markdown Format (Recommended)

The most flexible and human-readable format:

```markdown
# School Tasks

## Biology
- Exam 1 - due: 2025-01-25 priority: high effort: 180min
- Study session for Exam 1 - due: 2025-01-24 effort: 120min
- Homework Chapter 3 - due: 2025-01-20 effort: 60min
- Quiz on Genetics - due: 2025-01-22 effort: 30min

## Chemistry
- [Chemistry] Lab Report - due: 2025-01-23 priority: medium effort: 90min
- Problem Set 5 - due: 2025-01-21 effort: 75min
- Midterm Exam - due: 2025-02-01 priority: urgent effort: 240min

## Physics
- Project Proposal - due: 2025-01-28 effort: 120min notes: Submit via Canvas
- Homework Week 3 - due: 2025-01-19 effort: 45min

## Math
- Quiz 2 - due: 2025-01-20 effort: 30min no-reminder
- Assignment 4 - due: 2025-01-22 priority: low effort: 60min

# Research Tasks

- Literature Review - due: 2025-01-30 category: Research priority: high effort: 240min
- Data Analysis - due: 2025-02-05 category: Research effort: 180min

# Training

- Marathon Training Plan - due: 2025-01-31 category: Training effort: 60min
```

#### Text Format Syntax

**Required Fields:**
- `due: YYYY-MM-DD` - Due date (can include time: `YYYY-MM-DD HH:MM`)

**Optional Fields:**
- `priority: urgent|high|medium|low|optional` or `priority: 1-5`
- `effort: Nmin` - Estimated effort in minutes
- `category: School|Training|Research` - Task category
- `course: CourseName` - Explicit course name
- `notes: Description` - Additional notes
- `no-reminder` - Skip Reminders sync for this task

**Course Assignment:**
- Section headers (`## CourseName`) set default course for following tasks
- `[CourseName]` prefix in task title
- Explicit `course: Name` field

**Task Type Detection:**
Automatically detected from title keywords:
- `exam`, `test` → exam
- `quiz` → quiz
- `homework`, `hw` → assignment
- `study`, `review` → study_session
- `project`, `paper`, `essay` → project

### 2. JSON Format

Structured format for programmatic generation:

```json
{
  "tasks": [
    {
      "title": "Biology Exam 1",
      "type": "exam",
      "course": "Biology",
      "due_date": "2025-01-25T23:59:00",
      "priority": 5,
      "effort_minutes": 180,
      "category": "School",
      "notes": "Chapters 1-5",
      "reminder_enabled": true
    },
    {
      "title": "Chemistry Lab Report",
      "type": "assignment",
      "course": "Chemistry",
      "due_date": "2025-01-23",
      "priority": 3,
      "effort_minutes": 90
    }
  ]
}
```

**Field Reference:**
- `title` (required): Task title
- `type`: `exam`, `quiz`, `assignment`, `study_session`, `project`
- `course` (required): Course name
- `due_date` (required): ISO 8601 date/datetime
- `priority`: 1-5 (5 = highest, default: 3)
- `effort_minutes`: Estimated effort (default: 60)
- `category`: `School`, `Training`, `Research` (default: `School`)
- `notes`: Additional information
- `reminder_enabled`: `true`/`false` (default: `true`)

### 3. YAML Format

Clean, structured format:

```yaml
tasks:
  - title: Biology Exam 1
    type: exam
    course: Biology
    due_date: 2025-01-25
    priority: 5
    effort_minutes: 180
    category: School
    notes: Chapters 1-5

  - title: Chemistry Homework
    type: assignment
    course: Chemistry
    due_date: 2025-01-20
    priority: 3
    effort_minutes: 60
```

## API Endpoints

### POST /api/tasks/import

Import tasks from a file.

**Request:**
```json
{
  "file_path": "/Users/username/tasks.txt",
  "sync_to_reminders": true
}
```

**Response:**
```json
{
  "success": true,
  "results": {
    "parsed": 15,
    "imported": 15,
    "synced": 8,
    "errors": []
  }
}
```

**cURL Example:**
```bash
curl -X POST http://127.0.0.1:5001/api/tasks/import \
  -H "Content-Type: application/json" \
  -H "X-API-Token: YOUR_TOKEN" \
  -d '{
    "file_path": "/Users/clevelandlewis/Documents/spring_2025_tasks.txt",
    "sync_to_reminders": true
  }'
```

### POST /api/tasks/sync-to-reminders

Sync existing assignments to Apple Reminders.

**Request:**
```json
{
  "assignment_ids": [1, 2, 3],
  "force": false
}
```

Omit `assignment_ids` to sync all eligible assignments.

**Response:**
```json
{
  "success": true,
  "results": {
    "synced": 5,
    "skipped": 10,
    "failed": 0,
    "errors": []
  }
}
```

**cURL Example:**
```bash
# Sync all eligible tasks
curl -X POST http://127.0.0.1:5001/api/tasks/sync-to-reminders \
  -H "Content-Type: application/json" \
  -H "X-API-Token: YOUR_TOKEN" \
  -d '{}'

# Sync specific tasks
curl -X POST http://127.0.0.1:5001/api/tasks/sync-to-reminders \
  -H "Content-Type: application/json" \
  -H "X-API-Token: YOUR_TOKEN" \
  -d '{"assignment_ids": [1, 2, 3]}'
```

### POST /api/tasks/sample-file

Create a sample tasks file for reference.

**Request:**
```json
{
  "output_path": "/Users/username/sample_tasks.txt"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Sample file created at: /Users/username/sample_tasks.txt"
}
```

## Apple Reminders Sync

### Sync Strategy

**One-Way Push:**
- Tasks are pushed FROM School Dashboard TO Apple Reminders
- High-priority tasks (priority >= 4) automatically sync
- Exams and quizzes always sync regardless of priority
- Updates in Reminders do NOT sync back (to prevent conflicts)

### Sync Criteria

A task is synced to Reminders if:
1. Reminders sync is enabled in Settings
2. Task is not completed (`status != 'done'`)
3. **AND** one of:
   - Task priority >= 4 (high/urgent)
   - Task type is `exam` or `quiz`

### Reminder Format

Synced reminders include:
- **Title:** `[CourseName] Task Title`
- **Due Date:** Assignment due date
- **Priority:** Mapped from 1-5 scale to Apple's 0-9 scale
- **Notes:**
  ```
  Type: exam
  Priority: 5/5
  Estimated effort: 120 minutes

  Subtasks (3):
    ◯ Review Chapter 1
    ◯ Practice problems
    ✓ Make study guide
  ```

### Settings

Configure Reminders sync in Settings page:

- **Enable Reminders sync** - Master toggle
- **Reminders list name** - Target list (default: "School OS")

## Workflow Examples

### Example 1: Semester Planning

**1. Create tasks file** (`spring_2025.txt`):
```markdown
## Biology 311
- Exam 1 - due: 2025-02-15 priority: high effort: 180min
- Exam 2 - due: 2025-03-15 priority: high effort: 180min
- Final Exam - due: 2025-05-05 priority: urgent effort: 240min

## Chemistry 201
- Midterm - due: 2025-03-01 priority: high effort: 200min
- Final - due: 2025-05-08 priority: urgent effort: 240min
```

**2. Import tasks:**
```bash
curl -X POST http://127.0.0.1:5001/api/tasks/import \
  -H "Content-Type: application/json" \
  -H "X-API-Token: YOUR_TOKEN" \
  -d '{
    "file_path": "/Users/clevelandlewis/Documents/spring_2025.txt",
    "sync_to_reminders": true
  }'
```

**3. Result:**
- 5 tasks imported to School Dashboard
- 5 reminders created in Apple Reminders (all are high-priority exams)
- Tasks appear in assignment grid, calendar, and scheduler

### Example 2: Weekly Homework Batch

**1. Create tasks file** (`week_3_homework.txt`):
```markdown
## Math 410
- Problem Set 3 - due: 2025-01-22 effort: 90min

## Physics 302
- Lab Report 2 - due: 2025-01-23 priority: medium effort: 120min

## Computer Science
- Programming Assignment 2 - due: 2025-01-24 priority: high effort: 180min
```

**2. Import without syncing to Reminders:**
```bash
curl -X POST http://127.0.0.1:5001/api/tasks/import \
  -H "Content-Type: application/json" \
  -H "X-API-Token: YOUR_TOKEN" \
  -d '{
    "file_path": "/Users/clevelandlewis/Documents/week_3_homework.txt",
    "sync_to_reminders": false
  }'
```

**3. Later, manually sync high-priority items:**
```bash
curl -X POST http://127.0.0.1:5001/api/tasks/sync-to-reminders \
  -H "Content-Type: application/json" \
  -H "X-API-Token: YOUR_TOKEN" \
  -d '{"assignment_ids": [15]}'
```

### Example 3: Mixed Categories

**1. Create comprehensive tasks file:**
```markdown
# School

## Biology
- Exam prep - due: 2025-01-25 priority: high effort: 120min

# Research

- Submit IRB application - due: 2025-01-30 category: Research priority: urgent effort: 180min
- Data collection pilot - due: 2025-02-05 category: Research effort: 240min

# Training

- Half marathon - due: 2025-03-15 category: Training priority: high effort: 90min notes: Register by Jan 20
```

**2. Import all categories:**
```bash
curl -X POST http://127.0.0.1:5001/api/tasks/import \
  -H "Content-Type: application/json" \
  -H "X-API-Token: YOUR_TOKEN" \
  -d '{
    "file_path": "/Users/clevelandlewis/Documents/all_tasks.txt",
    "sync_to_reminders": true
  }'
```

**3. Schedule by category:**
```bash
# Schedule only School tasks
GET /api/schedule?context=School&days=7

# Schedule only Research tasks
GET /api/schedule?context=Research&days=14

# Schedule only Training tasks
GET /api/schedule?context=Training&days=7
```

## Best Practices

### File Organization

**Recommended structure:**
```
~/Documents/SchoolTasks/
  ├── spring_2025_exams.txt       # Major exams and tests
  ├── weekly_homework.txt          # Updated weekly
  ├── research_milestones.txt      # Research deadlines
  └── training_goals.txt           # Training schedule
```

### Task Naming

**Good:**
- `Exam 1` (clear, concise)
- `Homework Ch 3-5` (specific)
- `Study session for Midterm` (descriptive)

**Avoid:**
- `Do biology stuff` (too vague)
- `TH` (unclear acronym)
- Just `homework` (not specific enough)

### Priority Assignment

**5 (Urgent):**
- Final exams
- Major project deadlines
- Critical milestones

**4 (High):**
- Midterms
- Important presentations
- Graded assignments

**3 (Medium):**
- Regular homework
- Weekly quizzes
- Standard assignments

**2 (Low):**
- Optional practice
- Extra credit
- Non-graded work

**1 (Optional):**
- Supplemental reading
- Bonus materials

### Effort Estimation

**Guidelines:**
- **Exams:** 120-240 min (2-4 hours)
- **Major projects:** 180-360 min (3-6 hours)
- **Homework:** 45-90 min
- **Quizzes:** 20-40 min
- **Reading:** 30-60 min per chapter
- **Study sessions:** 60-120 min

### Sync Strategy

**Always sync:**
- Exams and final assessments
- High-priority deadlines
- Time-sensitive submissions

**Consider NOT syncing:**
- Low-priority homework
- Optional assignments
- Tasks you manage elsewhere

## Troubleshooting

### Import fails with "File not found"

**Problem:** File path is incorrect or file doesn't exist.

**Solution:**
```bash
# Use absolute path
/Users/clevelandlewis/Documents/tasks.txt

# NOT relative path
~/Documents/tasks.txt  # This won't work
```

### Tasks imported but not synced to Reminders

**Possible causes:**
1. Reminders sync disabled in Settings
2. Task priority < 4 and type is not exam/quiz
3. CalDAV credentials not configured

**Check:**
```bash
# Verify settings
GET /api/settings

# Manually trigger sync
POST /api/tasks/sync-to-reminders
```

### Duplicate tasks created

**Problem:** Imported the same file multiple times.

**Solution:**
- Delete duplicates manually in Assignments page
- Future: Use `external_id` field to track imported tasks

### Course not found

**Problem:** Course name in file doesn't match existing course.

**Solution:**
- Parser auto-creates placeholder courses
- Update course details in Courses page after import
- Or create courses before importing tasks

### Invalid date format

**Problem:** Date not recognized.

**Solutions:**
- Use `YYYY-MM-DD` format (e.g., `2025-01-20`)
- Include time if needed: `YYYY-MM-DD HH:MM` (e.g., `2025-01-20 14:30`)
- Avoid formats like `Jan 20` or `1/20/2025`

## Integration with Scheduler

Imported tasks automatically integrate with the scheduler:

**1. Tasks appear in assignment grid**
```bash
GET /assignments
```

**2. Tasks included in scheduling**
```bash
GET /api/schedule?context=School&days=7
```

**3. Tasks filtered by category**
```bash
# Schedule only School tasks
GET /api/schedule?context=School

# Schedule only Research tasks
GET /api/schedule?context=Research
```

**4. Calendar respects ALL events**
- Scheduler loads events from ALL calendars
- Only schedules tasks matching the context
- Avoids conflicts across all commitments

## Future Enhancements

- [ ] Two-way sync with Apple Reminders
- [ ] Detect and skip duplicate imports
- [ ] CSV import support
- [ ] Canvas/Blackboard LMS integration
- [ ] Recurring task patterns
- [ ] Bulk edit imported tasks
- [ ] Import validation preview before committing
- [ ] Auto-generate study sessions for exams
- [ ] Smart effort estimation based on historical data

## Summary

The task import and sync system provides:

✅ **Flexible file formats** - Text, JSON, YAML
✅ **Intelligent parsing** - Auto-detect task types, courses, priorities
✅ **Apple Reminders integration** - One-way sync for high-priority tasks
✅ **Batch operations** - Import entire semesters at once
✅ **Category support** - School, Training, Research
✅ **Scheduler integration** - Imported tasks immediately available for scheduling

This enables you to plan your semester once and have everything automatically organized, scheduled, and synced across your devices!
