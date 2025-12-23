# Notifications Settings - Quick Reference

## User-Facing Features

### Settings Location
**iOS/iPadOS**: Settings → Notifications

### Available Options

#### 1. Enable Notifications (Master Switch)
- **Default**: OFF
- **Effect**: Controls all notification categories
- **When OFF**: All sub-settings disabled, all scheduled notifications canceled
- **When ON**: Requests iOS permission (if not granted)

#### 2. Assignment Reminders
- **Default**: ON (when master enabled)
- **Lead Time Options**:
  - 15 minutes before due
  - 30 minutes before due
  - 1 hour before due (default)
  - 2 hours before due
  - 6 hours before due
  - 12 hours before due
  - 1 day before due
  - 2 days before due
- **Behavior**: Sends notification before each incomplete assignment's due date

#### 3. Daily Overview
- **Default**: OFF
- **Time Picker**: Choose preferred morning time (default 8:00 AM)
- **Content**: 
  - Today's task count
  - Optional: Yesterday's study time
  - Optional: Today's events
  - Optional: Motivational message

#### 4. Motivational Messages
- **Default**: OFF
- **Frequency**: 3 per day
- **Times**: 10:00 AM, 2:00 PM, 6:00 PM
- **Messages**: Encouraging short phrases

### Permission States

#### Not Determined (First Launch)
- Master toggle visible
- Tapping ON triggers iOS permission dialog

#### Granted
- All controls enabled and functional
- Notifications deliver according to schedule

#### Denied
- Warning card displayed
- "Open Settings" button links to iOS Settings app
- User must manually enable in iOS Settings

## Developer Reference

### Code Organization

```
SharedCore/
  Services/
    FeatureServices/
      NotificationManager.swift        # Core notification logic
  State/
    AppSettingsModel.swift              # Settings persistence

iOS/
  Scenes/
    Settings/
      Categories/
        NotificationsSettingsView.swift # UI implementation

en.lproj/
  Localizable.strings                   # All UI strings
```

### Key Methods

#### NotificationManager
```swift
// Master operations
.requestAuthorization()                 // Request iOS permission
.cancelAllScheduledNotifications()      // Cancel all Roots notifications

// Assignment reminders
.scheduleAssignmentDue(_ task)          // Schedule single reminder
.scheduleAllAssignmentReminders()       // Schedule all incomplete tasks
.cancelAllAssignmentReminders()         // Cancel all assignment reminders
.cancelAssignmentNotification(_ id)     // Cancel specific reminder

// Daily overview
.scheduleDailyOverview()                // Schedule daily repeating notification
.cancelDailyOverview()                  // Cancel daily notification

// Motivational messages
.scheduleMotivationalMessages()         // Schedule 3 daily motivations
.cancelMotivationalMessages()           // Cancel all motivations

// Debug (DEBUG builds only)
.printPendingNotifications()            // Log pending to console
.sendTestNotification()                 // Test in 5 seconds
```

#### Settings Access
```swift
let settings = AppSettingsModel.shared

// Read
settings.notificationsEnabled           // Bool
settings.assignmentRemindersEnabled     // Bool
settings.dailyOverviewEnabled           // Bool
settings.affirmationsEnabled            // Bool
settings.assignmentLeadTime             // TimeInterval (seconds)
settings.dailyOverviewTime              // Date

// Write (automatically persists)
settings.assignmentLeadTime = 7200      // 2 hours
settings.dailyOverviewTime = newDate    // Update time
```

### Notification Identifiers

```swift
// Pattern: "{category}-{optional-suffix}"
"assignment-{UUID}"       // Assignment reminder
"daily-overview"          // Daily overview
"motivation-0"            // 10am motivation
"motivation-1"            // 2pm motivation
"motivation-2"            // 6pm motivation
"test-notification"       // DEBUG test
```

### Trigger Types

| Category | Trigger Type | Repeats | Timing |
|----------|-------------|---------|--------|
| Assignment | Calendar | No | Due date - lead time |
| Daily Overview | Calendar | Yes | Daily at chosen time |
| Motivation | Calendar | Yes | Daily at fixed times |

### Integration Points

#### Assignments Store
```swift
// Automatically calls notification methods:
AssignmentsStore.shared.addTask()       → scheduleAssignmentDue()
AssignmentsStore.shared.updateTask()    → reschedule notification
AssignmentsStore.shared.removeTask()    → cancelAssignmentNotification()
```

#### Settings Changes
```swift
// UI bindings trigger immediate actions:
Toggle assignment reminders ON   → scheduleAllAssignmentReminders()
Toggle assignment reminders OFF  → cancelAllAssignmentReminders()
Change lead time                 → cancel + reschedule all
Change daily time                → reschedule daily overview
```

### Localization Keys

#### Settings UI
```
settings.notifications.enable
settings.notifications.assignments
settings.notifications.daily_overview
settings.notifications.affirmations
settings.notifications.lead_time
settings.notifications.overview_time
settings.notifications.lead_time.15_min
settings.notifications.lead_time.30_min
settings.notifications.lead_time.1_hour
... (etc)
```

#### Notification Content
```
notification.assignment.title
notification.assignment.body
notification.daily_overview.title
notification.daily_overview.default
notification.motivation.title
notification.motivation.message_1
... (etc)
```

### Testing Commands (DEBUG)

```swift
// In iOS Settings → Notifications (DEBUG section):
1. Tap "Print Pending Notifications"
   → Check Xcode console for output

2. Tap "Send Test Notification (5s)"
   → Notification appears in 5 seconds
   → Verifies permissions + delivery
```

### Common Debugging

#### Notifications Not Appearing?
1. Check master toggle is ON
2. Check iOS Settings > Roots > Notifications is ON
3. Check Do Not Disturb / Focus mode
4. Check `printPendingNotifications()` console output
5. Verify trigger date is in future (not past)

#### Permission Denied?
- User must go to iOS Settings > Roots > Notifications
- Enable "Allow Notifications"
- Return to app and toggle master ON

#### Duplicate Notifications?
- Should not happen (all schedules cancel first)
- If occurs, check identifier uniqueness
- Verify `cancelAll` called before `scheduleAll`

## Quick Start for New Developers

1. **Review Core Logic**: `NotificationManager.swift`
2. **Review UI**: `NotificationsSettingsView.swift`
3. **Test Master Toggle**: OFF should cancel all
4. **Test Assignment Reminder**: Create test task due in 1 hour
5. **Test Daily Overview**: Set time to now + 2 minutes
6. **Use DEBUG Tools**: Print pending, send test
7. **Check Console**: Verify scheduling logs

## User Documentation

### How to Enable Notifications

1. Open Roots app
2. Tap Settings (gear icon)
3. Tap Notifications
4. Toggle "Enable Notifications" ON
5. If prompted, tap "Allow" in iOS dialog
6. Enable desired categories (Assignments, Daily Overview, Motivational)
7. Adjust lead times and times as preferred

### If Notifications Stop Working

1. Check Settings > Notifications > Master toggle is ON
2. Check iOS Settings > Roots > Notifications is ON
3. Check iOS Focus/Do Not Disturb settings
4. Restart Roots app
5. If still issues, toggle OFF then ON to re-request permission

### Customizing Notifications

- **Assignment Lead Time**: Choose how far in advance to be reminded (15 min to 2 days)
- **Daily Overview Time**: Pick your preferred morning time for the summary
- **Motivational Messages**: Toggle ON for 3 daily encouraging messages

---

**Last Updated**: December 23, 2025  
**Version**: 1.0  
**Platform**: iOS 16.0+, iPadOS 16.0+
