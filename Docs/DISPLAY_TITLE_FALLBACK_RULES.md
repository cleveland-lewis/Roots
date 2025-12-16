# Display Title Fallback Rules

Comprehensive specification of display title generation with fallback strategies for all persisted entities in Roots.

**Version:** 1.0  
**Last Updated:** 2025-12-16  
**Related Issues:** #314 (Storage.B), #313 (Storage.A)  
**Implementation:** `StorageListable+Implementations.swift`

---

## Overview

Every entity in the Storage Center must display a non-empty, human-readable title. This document specifies the fallback hierarchy when the primary title is empty or unavailable.

**Principles:**
1. **Primary First**: Use native title/name if non-empty
2. **Contextual Fallback**: Use related fields (code, filename, etc.)
3. **Type + Timestamp**: Last resort with entity type and date
4. **Never Empty**: Always return a displayable string

---

## Fallback Rules by Entity Type

### 1. Course
**Primary:** `title`  
**Fallback Order:**
1. `code` (e.g., "CS 101")
2. "Untitled Course"

**Examples:**
- ✅ "Introduction to Computer Science" (has title)
- ⚠️ "CS 101" (title empty, has code)
- ❌ "Untitled Course" (both empty)

---

### 2. Semester
**Primary:** Computed from `semesterTerm` + `academicYear`  
**Fallback:** N/A (always computable)

**Examples:**
- ✅ "Fall 2024-2025"
- ✅ "Spring 2025"
- ✅ "Summer 2024-2025"

**Note:** Never falls back as both fields are required

---

### 3. Assignment/Task
**Primary:** `title` or `name`  
**Fallback Order:**
1. `"Assignment due " + dueDate.formatted()`
2. `"Assignment (" + createdDate.formatted() + ")"`
3. "Untitled Assignment"

**Examples:**
- ✅ "Problem Set 3" (has title)
- ⚠️ "Assignment due Oct 15" (no title, has due date)
- ⚠️ "Assignment (Sep 1)" (no title or due date, has created)
- ❌ "Untitled Assignment" (all empty)

---

### 4. Grade
**Primary:** N/A (contextual to course)  
**Computed:** `"Grade for " + courseName`  
**Fallback:** `"Grade for Unknown Course"`

**Examples:**
- ✅ "Grade for CS 101"
- ❌ "Grade for Unknown Course" (course lookup failed)

---

### 5. Planner Block
**Primary:** `title` or `description`  
**Fallback Order:**
1. `activity.name` if available
2. `"Block " + startTime.formatted()`
3. "Untitled Block"

**Examples:**
- ✅ "Study Session" (has title)
- ⚠️ "Deep Work" (no title, has activity)
- ⚠️ "Block 2:00 PM" (no title or activity)
- ❌ "Untitled Block" (all empty)

---

### 6. Assignment Plan
**Primary:** N/A (derived from assignment)  
**Computed:** `"Plan: " + assignment.title`  
**Fallback:** `"Plan: " + assignment.id.prefix(8)`

**Examples:**
- ✅ "Plan: Problem Set 3"
- ❌ "Plan: 4a7b3c21" (assignment has no title)

---

### 7. Focus Session
**Primary:** N/A (activity-based)  
**Computed:** `"Focus: " + duration.formatted() + " - " + activity`  
**Fallback:** `"Focus: " + duration.formatted()`

**Examples:**
- ✅ "Focus: 45m - Reading"
- ⚠️ "Focus: 45m" (no activity specified)

---

### 8. Practice Test
**Primary:** `title` or `name`  
**Fallback Order:**
1. `courseName + " Practice Test"`
2. `"Practice Test (" + createdDate.formatted() + ")"`
3. "Untitled Practice Test"

**Examples:**
- ✅ "Midterm Practice" (has title)
- ⚠️ "CS 101 Practice Test" (no title, has course)
- ⚠️ "Practice Test (Oct 1)" (no title or course)
- ❌ "Untitled Practice Test" (all empty)

---

### 9. Test Blueprint
**Primary:** `title`  
**Fallback Order:**
1. `courseName + " Blueprint"`
2. "Untitled Blueprint"

**Examples:**
- ✅ "Final Exam Blueprint" (has title)
- ⚠️ "MA 231 Blueprint" (no title, has course)
- ❌ "Untitled Blueprint" (all empty)

---

### 10. Course Outline Node
**Primary:** `title`  
**Fallback:** Type-specific based on `nodeType`
- Module → "Untitled Module"
- Week → "Untitled Week"
- Topic → "Untitled Topic"
- Chapter → "Untitled Chapter"
- Unit → "Untitled Unit"
- Section → "Untitled Section"
- Unknown → "Untitled Node"

**Examples:**
- ✅ "Introduction to Programming" (has title)
- ❌ "Untitled Module" (no title, nodeType = module)
- ❌ "Untitled Week" (no title, nodeType = week)

---

### 11. Course File
**Primary:** `name`  
**Fallback Order:**
1. Extract filename from `url.lastPathComponent`
2. `fileType + " (" + uploadDate.formatted() + ")"`
3. `"File (" + uploadDate.formatted() + ")"`
4. "Unknown File"

**Examples:**
- ✅ "Syllabus.pdf" (has name)
- ⚠️ "lecture_notes.pdf" (no name, extracted from URL)
- ⚠️ "PDF (Sep 15)" (no name or filename, has type and date)
- ⚠️ "File (Sep 15)" (only date available)
- ❌ "Unknown File" (nothing available)

---

### 12. Attachment
**Primary:** `name`  
**Fallback Order:**
1. Extract filename from `urlString.lastPathComponent`
2. `type + " Attachment"`
3. "Untitled Attachment"

**Examples:**
- ✅ "homework.docx" (has name)
- ⚠️ "assignment3.pdf" (no name, extracted from URL)
- ⚠️ "PDF Attachment" (no name or filename, has type)
- ❌ "Untitled Attachment" (all empty)

---

### 13. Syllabus
**Primary:** N/A (contextual to course)  
**Computed:** `"Syllabus for " + courseName`  
**Fallback:** `"Syllabus (" + parseDate.formatted() + ")"`

**Examples:**
- ✅ "Syllabus for CS 101"
- ⚠️ "Syllabus (Aug 25)" (course lookup failed, has parse date)

---

### 14. Parsed Assignment
**Primary:** Extracted `title` from syllabus  
**Fallback Order:**
1. `"Assignment from " + sourceSyllabusName`
2. `"Parsed Assignment (" + dueDate.formatted() + ")"`
3. "Untitled Parsed Assignment"

**Examples:**
- ✅ "Problem Set 1" (extracted title)
- ⚠️ "Assignment from CS101_Syllabus.pdf" (no title, has source)
- ⚠️ "Parsed Assignment (Sep 10)" (no title or source, has due date)
- ❌ "Untitled Parsed Assignment" (all empty)

---

### 15. Calendar Event
**Primary:** `title`  
**Fallback:** `category + " (" + startDate.formatted() + ")"`

**Examples:**
- ✅ "Calculus Lecture" (has title)
- ❌ "Class (Sep 20, 9:00 AM)" (no title, computed from category and date)

---

### 16. Timer Session
**Primary:** N/A (activity-based)  
**Computed:** `"Timer: " + duration.formatted() + " - " + taskName`  
**Fallback:** `"Timer: " + duration.formatted() + " (" + sessionDate.formatted() + ")"`

**Examples:**
- ✅ "Timer: 25m - Study CS" (has task)
- ⚠️ "Timer: 25m (Oct 5)" (no task, has date)

---

## Implementation Pattern

```swift
extension SomeEntity: StorageListable {
    public var displayTitle: String {
        // 1. Check primary field(s)
        if !primaryField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return primaryField
        }
        
        // 2. Try contextual fallback
        if let fallback = contextualFallback, !fallback.isEmpty {
            return fallback
        }
        
        // 3. Last resort with type + timestamp
        if let date = relevantDate {
            return "EntityType (\(date.formatted(date: .abbreviated, time: .omitted)))"
        }
        
        // 4. Absolute fallback
        return "Untitled EntityType"
    }
}
```

---

## Empty String Detection

**All implementations use:**
```swift
str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
```

This catches:
- Empty strings: `""`
- Whitespace-only: `"   "`
- Newlines: `"\n\n"`
- Tabs: `"\t\t"`

---

## Date Formatting Standards

**For Fallback Titles:**
```swift
// Abbreviated date only
date.formatted(date: .abbreviated, time: .omitted)
// Output: "Sep 15, 2024"

// Abbreviated date + time
date.formatted(date: .abbreviated, time: .shortened)
// Output: "Sep 15, 2024, 2:30 PM"

// Numeric date only (for file fallbacks)
date.formatted(date: .numeric, time: .omitted)
// Output: "9/15/2024"
```

---

## Testing Requirements

Every entity implementation must be tested with:

### Test Cases
1. ✅ **Happy Path**: Primary field has valid content
2. ⚠️ **First Fallback**: Primary empty, first fallback available
3. ⚠️ **Second Fallback**: First fallback also empty
4. ❌ **Last Resort**: All fields empty/nil

### Example Test
```swift
func testCourseDisplayTitle() {
    // Happy path
    let course1 = Course(title: "CS 101", ...)
    XCTAssertEqual(course1.displayTitle, "CS 101")
    
    // Fallback to code
    let course2 = Course(title: "", code: "MA 231", ...)
    XCTAssertEqual(course2.displayTitle, "MA 231")
    
    // Last resort
    let course3 = Course(title: "", code: nil, ...)
    XCTAssertEqual(course3.displayTitle, "Untitled Course")
}
```

---

## Storage Center Display

**List Row Format:**
```
[Icon] Display Title
       Context · Status
       Primary Date
```

**Example:**
```
📚 Problem Set 3
   CS 101 · In Progress
   Due Oct 15, 2024
```

**Empty Fallback Example:**
```
📄 File (Sep 15)
   PDF · 2.3 MB
   Uploaded Sep 15, 2024
```

---

## Search Implications

Display titles are included in searchable text. Fallback titles with dates/IDs are less discoverable, so:

**Best Practice:**
1. Always prompt users for titles during creation
2. Make title field required where sensible
3. Use validation to prevent empty titles
4. Show warning when using fallback titles

---

## Maintenance

**When adding new entity types:**
1. Add to `StorageEntityType` enum
2. Implement `StorageListable` extension
3. Define primary field(s)
4. Specify fallback hierarchy (2-3 levels)
5. Add to this document
6. Write unit tests
7. Update Storage Center UI

**Fallback Review Triggers:**
- User feedback about confusing titles
- High percentage of fallback usage in analytics
- New fields added to entity models
- UX studies on title discoverability

---

## Summary Table

| Entity | Primary | First Fallback | Last Fallback |
|--------|---------|----------------|---------------|
| Course | title | code | "Untitled Course" |
| Semester | computed | N/A | N/A |
| Assignment | title | due date | "Untitled Assignment" |
| Grade | computed | N/A | "Unknown Course" |
| Planner Block | title | activity | "Untitled Block" |
| Assignment Plan | computed | assignment ID | N/A |
| Focus Session | computed | duration only | N/A |
| Practice Test | title | course + type | "Untitled Practice Test" |
| Test Blueprint | title | course + type | "Untitled Blueprint" |
| Course Outline | title | type-specific | "Untitled Node" |
| Course File | name | URL filename | date + type |
| Attachment | name | URL filename | "Untitled Attachment" |
| Syllabus | computed | parse date | N/A |
| Parsed Assignment | extracted | source + date | "Untitled Parsed Assignment" |
| Calendar Event | title | category + date | N/A |
| Timer Session | computed | date only | N/A |

**Legend:**
- ✅ Primary: Native field
- ⚠️ Fallback: Computed or contextual
- ❌ Last: Type + generic text

---

**Document Owner:** Data Architecture  
**Review Cycle:** Quarterly or when adding entity types  
**Related Docs:** STORAGE_DATA_INVENTORY.md, StorageEntityType.swift
