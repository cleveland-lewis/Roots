#!/bin/bash

# 1. Full Device Language/Locale Responsiveness
echo "Creating Parent Issue 1: Full Device Language/Locale Responsiveness..."
PARENT1=$(gh issue create \
  --title "Epic: Ensure Full Device Language/Locale Responsiveness" \
  --body "### Goal
Ensure the entire application responds correctly to the device's language and regional settings, with no hardcoded strings, proper date/number formatting, and comprehensive locale coverage.

### Sub-tasks
- [ ] Audit all hardcoded strings
- [ ] Replace remaining DateFormatter/NumberFormatter usage  
- [ ] Expand .strings and .stringsdict resources for all locales
- [ ] Add automated tests for multiple locales
- [ ] Validate UI in at least 3 locales

### Acceptance Criteria
- All user-facing strings are localized
- Date and number formatting respects locale
- UI validates correctly across multiple languages
- Automated tests cover locale switching" \
  --label "epic,i18n,priority" \
  --assignee "cleveland-lewis" | grep -oE '[0-9]+$')

echo "Parent issue #$PARENT1 created"

# Sub-issues for Parent 1
gh issue create \
  --title "Audit all hardcoded strings in codebase" \
  --body "### Description
Perform a comprehensive audit of the entire codebase to identify all hardcoded user-facing strings that need to be moved to Localizable.strings.

### Acceptance Criteria
- All Swift files scanned for string literals
- List of hardcoded strings documented
- Strings categorized by urgency and screen

### Parent Issue
#$PARENT1" \
  --label "i18n,audit,priority" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Replace remaining DateFormatter/NumberFormatter usage with locale-aware formatting" \
  --body "### Description
Replace all hardcoded date and number formatting with proper locale-aware formatters that respect user's regional settings.

### Acceptance Criteria
- All date formats use proper DateFormatter with locale
- All number formats use NumberFormatter with locale
- Currency and percentage formatting respects locale
- Time formats respect 12/24-hour preferences

### Parent Issue
#$PARENT1" \
  --label "i18n,enhancement" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Expand .strings and .stringsdict resources for all supported locales" \
  --body "### Description
Ensure all .strings and .stringsdict files are complete and up-to-date for all supported locales.

### Acceptance Criteria
- All keys present in all locale files
- Pluralization rules implemented via .stringsdict
- Context-specific translations verified
- No missing keys warnings

### Parent Issue
#$PARENT1" \
  --label "i18n,translation" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Add automated tests for multiple locales" \
  --body "### Description
Create automated tests that verify the app functions correctly across different locales and languages.

### Acceptance Criteria
- Unit tests for locale switching
- Tests for date/number formatting
- Tests for string key existence
- UI tests for RTL languages (if applicable)
- CI runs tests with multiple locales

### Parent Issue
#$PARENT1" \
  --label "i18n,testing" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Validate UI in at least 3 locales (manual QA)" \
  --body "### Description
Manually test the application UI in at least 3 different locales to ensure proper display and functionality.

### Acceptance Criteria
- Test in English, Chinese, and one other language
- Verify all screens display correctly
- Check for text truncation issues
- Verify date/time/number formatting
- Document any issues found

### Parent Issue
#$PARENT1" \
  --label "i18n,testing,manual" \
  --assignee "cleveland-lewis"

# 2. Local Core ML LLM Integration
echo "Creating Parent Issue 2: Local Core ML LLM Integration..."
PARENT2=$(gh issue create \
  --title "Epic: Local Core ML LLM Integration (macOS + iOS/iPadOS)" \
  --body "### Goal
Integrate on-device Core ML language models for local, privacy-preserving LLM capabilities across macOS and iOS/iPadOS.

### Sub-tasks
- [ ] Device capability detection
- [ ] Local model catalog & tier definitions
- [ ] Model downloader with checksum + progress
- [ ] LocalLLMService with streaming
- [ ] Settings UI for model selection + overrides
- [ ] Practice test generation pipeline (JSON, 2-pass)
- [ ] Model hosting manifest + URLs

### Acceptance Criteria
- On-device LLM runs on capable devices
- Models download with progress indication
- Privacy-preserving implementation
- Graceful fallback for unsupported devices" \
  --label "epic,local-ml,enhancement,priority" \
  --assignee "cleveland-lewis" | grep -oE '[0-9]+$')

echo "Parent issue #$PARENT2 created"

# Sub-issues for Parent 2
gh issue create \
  --title "Implement DeviceCapabilities detection for Core ML" \
  --body "### Description
Create a DeviceCapabilities module to detect device support for Core ML models, including Neural Engine availability, RAM, and performance tier.

### Acceptance Criteria
- Detects Neural Engine availability
- Checks available RAM
- Determines device performance tier
- Returns supported model tiers
- Works on macOS, iOS, and iPadOS

### Parent Issue
#$PARENT2" \
  --label "local-ml,enhancement" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Create LocalModelCatalog with tier definitions" \
  --body "### Description
Define a catalog of available local models with tier classifications (small, medium, large) and device compatibility matrices.

### Acceptance Criteria
- Model catalog with metadata (size, requirements)
- Tier definitions (small/medium/large)
- Device compatibility mapping
- Model capability descriptions
- JSON or plist-based configuration

### Parent Issue
#$PARENT2" \
  --label "local-ml,enhancement" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Implement ModelDownloader with checksum validation and progress" \
  --body "### Description
Create a model downloader that fetches Core ML models with integrity checking, progress reporting, and error handling.

### Acceptance Criteria
- Downloads models from remote URLs
- Validates checksums (SHA256)
- Reports download progress
- Handles network errors gracefully
- Caches downloaded models
- Supports background downloads

### Parent Issue
#$PARENT2" \
  --label "local-ml,enhancement" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Implement LocalLLMService with streaming support" \
  --body "### Description
Create a LocalLLMService that interfaces with Core ML models and provides streaming text generation capabilities.

### Acceptance Criteria
- Loads Core ML models efficiently
- Supports streaming token generation
- Provides cancellation support
- Handles context length limits
- Thread-safe implementation
- Memory-efficient

### Parent Issue
#$PARENT2" \
  --label "local-ml,enhancement" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Add Settings UI for model selection and overrides" \
  --body "### Description
Create Settings UI to allow users to select which local model to use, view device capabilities, and override automatic selection.

### Acceptance Criteria
- Display available models
- Show device capability tier
- Allow manual model selection
- Display model size and requirements
- Show download status
- Delete downloaded models option

### Parent Issue
#$PARENT2" \
  --label "local-ml,ui,settings" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Implement practice test generation pipeline (JSON, 2-pass)" \
  --body "### Description
Create a 2-pass pipeline for generating practice tests using local LLM: first pass generates questions, second pass validates and formats as JSON.

### Acceptance Criteria
- First pass: generate questions from content
- Second pass: validate and structure as JSON
- Handle malformed output gracefully
- Support multiple question types
- Include difficulty rating
- Generate answer keys

### Parent Issue
#$PARENT2" \
  --label "local-ml,enhancement,practice-tests" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Set up model hosting manifest and URLs" \
  --body "### Description
Create and host a manifest file that defines available Core ML models, their URLs, checksums, and metadata for the app to fetch.

### Acceptance Criteria
- JSON manifest with model metadata
- Secure hosting location (CDN or GitHub releases)
- Versioning support
- Model URLs with checksums
- Update mechanism for manifest

### Parent Issue
#$PARENT2" \
  --label "local-ml,infrastructure" \
  --assignee "cleveland-lewis"

# 3. Scheduled Tests UI & Logic
echo "Creating Parent Issue 3: Scheduled Tests UI & Logic..."
PARENT3=$(gh issue create \
  --title "Epic: Scheduled Tests UI & Logic" \
  --body "### Goal
Implement a comprehensive scheduled tests feature allowing users to plan, view, and start practice tests on a weekly schedule.

### Sub-tasks
- [ ] Data model for ScheduledPracticeTest
- [ ] Weekly view UI for schedule
- [ ] Week navigation UI
- [ ] Start test triggers TestAttempt
- [ ] Status badges (Scheduled/Completed/Missed)
- [ ] i18n for all labels

### Acceptance Criteria
- Users can view scheduled tests by week
- Tests can be started at any time
- Status tracking works correctly
- Fully localized interface" \
  --label "epic,enhancement,ui,priority" \
  --assignee "cleveland-lewis" | grep -oE '[0-9]+$')

echo "Parent issue #$PARENT3 created"

# Sub-issues for Parent 3
gh issue create \
  --title "Create data model for ScheduledPracticeTest and TestAttempt" \
  --body "### Description
Define SwiftData/CoreData models for storing scheduled practice tests and their attempt records.

### Acceptance Criteria
- ScheduledPracticeTest entity with all required fields
- TestAttempt entity with relationship to scheduled test
- Proper indexing for queries
- Migration path if needed
- Works on macOS and iOS

### Parent Issue
#$PARENT3" \
  --label "enhancement,data-model" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Implement weekly view UI for scheduled tests" \
  --body "### Description
Create a weekly calendar view showing scheduled tests grouped by day with all relevant information.

### Acceptance Criteria
- Shows Mon-Sun for selected week
- Groups tests by day
- Displays test metadata (title, time, difficulty)
- Shows status badges
- Handles empty states
- Responsive layout

### Parent Issue
#$PARENT3" \
  --label "enhancement,ui" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Add week navigation controls (Previous/Next/This Week)" \
  --body "### Description
Implement navigation controls to browse between weeks and quickly return to current week.

### Acceptance Criteria
- Previous week button
- Next week button
- This Week reset button
- Week range display (Mon date - Sun date)
- Keyboard shortcuts (macOS)

### Parent Issue
#$PARENT3" \
  --label "enhancement,ui" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Implement Start button that creates TestAttempt" \
  --body "### Description
Add Start button functionality that creates a TestAttempt record and launches the test-taking UI.

### Acceptance Criteria
- Start button creates TestAttempt
- Links attempt to scheduled test
- Records startedAt timestamp
- Launches test UI
- Works at any time (not just scheduled time)
- Allows multiple attempts

### Parent Issue
#$PARENT3" \
  --label "enhancement,ui" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Implement status badges (Scheduled/Completed/Missed)" \
  --body "### Description
Create visual status badges that accurately reflect test status based on scheduled time and completion.

### Acceptance Criteria
- Scheduled: future or no attempt
- Completed: attempt with completedAt
- Missed: past scheduled time with no completion
- Color-coded badges
- Proper localization

### Parent Issue
#$PARENT3" \
  --label "enhancement,ui" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Add i18n for all Scheduled Tests labels" \
  --body "### Description
Localize all strings in the Scheduled Tests feature across all supported languages.

### Acceptance Criteria
- All labels in Localizable.strings
- Week navigation strings
- Status badge labels
- Empty state messages
- Button labels
- Pluralization rules for test counts

### Parent Issue
#$PARENT3" \
  --label "i18n,enhancement" \
  --assignee "cleveland-lewis"

# 4. Assignments Page Context Menu Functionality
echo "Creating Parent Issue 4: Assignments Page Context Menu..."
PARENT4=$(gh issue create \
  --title "Epic: Assignments Page Context Menu Functionality" \
  --body "### Goal
Implement comprehensive context menu actions for the Assignments page, including navigation, quick add features, and calendar integration.

### Sub-tasks
- [ ] Implement 'Go to Planner'
- [ ] Implement 'Add Assignment' popover
- [ ] Implement 'Add Grade' popover
- [ ] Refresh Calendar triggers
- [ ] Settings UI for scheduler lookahead
- [ ] EventKit calendar sync
- [ ] Scheduler lookahead logic
- [ ] Calendar event deduplication
- [ ] Error handling UI

### Acceptance Criteria
- Context menu works on all assignment items
- Quick actions function correctly
- Calendar sync is reliable
- Settings allow customization" \
  --label "epic,enhancement,ui,priority" \
  --assignee "cleveland-lewis" | grep -oE '[0-9]+$')

echo "Parent issue #$PARENT4 created"

# Sub-issues for Parent 4
gh issue create \
  --title "Implement 'Go to Planner' context menu action" \
  --body "### Description
Add context menu option to navigate from an assignment to its date in the Planner view.

### Acceptance Criteria
- Context menu shows 'Go to Planner'
- Switches to Planner tab
- Scrolls/focuses on assignment date
- Works on macOS and iOS
- Proper localization

### Parent Issue
#$PARENT4" \
  --label "enhancement,ui" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Implement 'Add Assignment' popover in context menu" \
  --body "### Description
Add quick action to create a new assignment via popover from context menu.

### Acceptance Criteria
- Popover with assignment form
- All required fields present
- Validation and error handling
- Saves to database
- Refreshes UI
- Localized

### Parent Issue
#$PARENT4" \
  --label "enhancement,ui" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Implement 'Add Grade' popover in context menu" \
  --body "### Description
Add quick action to record a grade for an assignment via popover.

### Acceptance Criteria
- Popover with grade entry form
- Score and optional notes fields
- Updates assignment record
- Visual feedback on save
- Localized

### Parent Issue
#$PARENT4" \
  --label "enhancement,ui" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Add Refresh Calendar action to context menu" \
  --body "### Description
Implement manual calendar refresh trigger from context menu to sync with EventKit.

### Acceptance Criteria
- Context menu shows Refresh option
- Triggers calendar sync
- Shows progress indicator
- Error handling for sync failures
- Updates UI on completion

### Parent Issue
#$PARENT4" \
  --label "enhancement,ui,calendar" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Add Settings UI for scheduler lookahead period" \
  --body "### Description
Create Settings option to control how far ahead the scheduler looks for assignments (1w/2w/1m/2m).

### Acceptance Criteria
- Settings toggle/picker for lookahead
- Options: 1 week, 2 weeks, 1 month, 2 months
- Persists preference
- Updates scheduler immediately
- Localized labels

### Parent Issue
#$PARENT4" \
  --label "enhancement,ui,settings" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Implement EventKit calendar sync for assignments" \
  --body "### Description
Create bidirectional sync between app assignments and system calendar via EventKit.

### Acceptance Criteria
- Request calendar permissions
- Sync assignments to calendar
- Handle calendar deletions
- Update existing events
- Respect user calendar choice
- Error handling

### Parent Issue
#$PARENT4" \
  --label "enhancement,calendar" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Implement scheduler lookahead logic" \
  --body "### Description
Create logic to query and display assignments within the configured lookahead window.

### Acceptance Criteria
- Queries based on user preference
- Efficient date range queries
- Updates when preference changes
- Handles timezone properly
- Performance optimized

### Parent Issue
#$PARENT4" \
  --label "enhancement,scheduler" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Implement calendar event deduplication logic" \
  --body "### Description
Ensure assignments don't create duplicate calendar events when syncing.

### Acceptance Criteria
- Tracks EventKit identifiers
- Checks for existing events
- Updates rather than duplicates
- Handles edge cases
- Proper cleanup on deletion

### Parent Issue
#$PARENT4" \
  --label "enhancement,calendar" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Add error handling UI for calendar sync failures" \
  --body "### Description
Create user-friendly error messages and recovery options for calendar sync issues.

### Acceptance Criteria
- Permission denied handling
- Network error handling
- Conflict resolution UI
- Retry mechanisms
- Clear error messages
- Localized error strings

### Parent Issue
#$PARENT4" \
  --label "enhancement,ui,error-handling" \
  --assignee "cleveland-lewis"

# 5. Stopwatch UI Enhancement
echo "Creating Parent Issue 5: Stopwatch UI Enhancement..."
PARENT5=$(gh issue create \
  --title "Epic: Stopwatch UI Enhancement with Numerals & Sub-dials" \
  --body "### Goal
Enhance the stopwatch UI with traditional watch-style numerals, sub-dials for minutes and hours, and improved visual fidelity.

### Sub-tasks
- [ ] Add outer dial numerals on main stopwatch
- [ ] Create minutes sub-dial
- [ ] Create hours sub-dial
- [ ] Improve tick mark contrast
- [ ] Match hand proportions to reference design
- [ ] Add i18n strings for labels

### Acceptance Criteria
- Professional watch-like appearance
- Clear, readable sub-dials
- Smooth animations
- Accessible on all devices" \
  --label "epic,enhancement,ui" \
  --assignee "cleveland-lewis" | grep -oE '[0-9]+$')

echo "Parent issue #$PARENT5 created"

# Sub-issues for Parent 5
gh issue create \
  --title "Add outer dial numerals to main stopwatch face" \
  --body "### Description
Add traditional clock numerals (12, 3, 6, 9 or full 1-12) around the outer edge of the stopwatch face.

### Acceptance Criteria
- Numerals positioned correctly
- Clear, readable font
- Scales with stopwatch size
- Respects accessibility settings
- Localized number formats

### Parent Issue
#$PARENT5" \
  --label "enhancement,ui" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Create minutes sub-dial for stopwatch" \
  --body "### Description
Add a sub-dial that displays elapsed minutes (0-30 or 0-60) with its own hand.

### Acceptance Criteria
- Sub-dial positioned appropriately
- Clear minute markings
- Dedicated minute hand
- Smooth animation
- Proper scale

### Parent Issue
#$PARENT5" \
  --label "enhancement,ui" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Create hours sub-dial for stopwatch" \
  --body "### Description
Add a sub-dial that displays elapsed hours (0-12 or 0-24) with its own hand.

### Acceptance Criteria
- Sub-dial positioned appropriately
- Clear hour markings
- Dedicated hour hand
- Smooth animation
- Proper scale

### Parent Issue
#$PARENT5" \
  --label "enhancement,ui" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Improve tick mark contrast on stopwatch" \
  --body "### Description
Enhance the visual contrast of tick marks for better readability across light and dark modes.

### Acceptance Criteria
- High contrast in light mode
- High contrast in dark mode
- Major/minor tick distinction
- Proper spacing
- Anti-aliased rendering

### Parent Issue
#$PARENT5" \
  --label "enhancement,ui,accessibility" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Match hand proportions to reference watch design" \
  --body "### Description
Adjust stopwatch hand proportions (length, width, shape) to match traditional chronograph watch designs.

### Acceptance Criteria
- Accurate hand lengths
- Appropriate widths
- Counterweight on second hand
- Proper layering (hour under minute under second)
- Smooth rotation

### Parent Issue
#$PARENT5" \
  --label "enhancement,ui" \
  --assignee "cleveland-lewis"

gh issue create \
  --title "Add i18n strings for stopwatch labels" \
  --body "### Description
Localize all text elements in the stopwatch UI including labels, tooltips, and controls.

### Acceptance Criteria
- All labels localized
- Sub-dial labels (Minutes, Hours)
- Button text localized
- Tooltips localized
- Number formatting respects locale

### Parent Issue
#$PARENT5" \
  --label "enhancement,i18n" \
  --assignee "cleveland-lewis"

# 6. Localization Expansion
echo "Creating Parent Issue 6: Localization Expansion..."
PARENT6=$(gh issue create \
  --title "Epic: Localization Expansion - 13 New Languages" \
  --body "### Goal
Expand application language support to 13 additional languages for broader international reach.

### Languages
- [ ] Portuguese (Brazilian)
- [ ] Indonesian
- [ ] Korean
- [ ] Vietnamese
- [ ] Bengali
- [ ] Turkish
- [ ] Swahili
- [ ] Polish
- [ ] Persian/Farsi
- [ ] Dutch
- [ ] Thai
- [ ] Hebrew
- [ ] Ukrainian

### Acceptance Criteria
- All 13 languages have complete .strings files
- Pluralization rules implemented
- RTL support for Hebrew, Persian, Arabic
- Manual QA in each language" \
  --label "epic,i18n,enhancement" \
  --assignee "cleveland-lewis" | grep -oE '[0-9]+$')

echo "Parent issue #$PARENT6 created"

# Sub-issues for Parent 6
LANGUAGES=(
  "Portuguese (Brazilian):pt-BR"
  "Indonesian:id"
  "Korean:ko"
  "Vietnamese:vi"
  "Bengali:bn"
  "Turkish:tr"
  "Swahili:sw"
  "Polish:pl"
  "Persian/Farsi:fa"
  "Dutch:nl"
  "Thai:th"
  "Hebrew:he"
  "Ukrainian:uk"
)

for LANG_PAIR in "${LANGUAGES[@]}"; do
  LANG_NAME="${LANG_PAIR%%:*}"
  LANG_CODE="${LANG_PAIR##*:}"
  
  gh issue create \
    --title "Add $LANG_NAME localization ($LANG_CODE)" \
    --body "### Description
Add complete $LANG_NAME localization to the application.

### Tasks
- [ ] Create $LANG_CODE.lproj directory
- [ ] Translate Localizable.strings
- [ ] Create Localizable.stringsdict for plurals
- [ ] Translate InfoPlist.strings if needed
- [ ] Test in simulator/device with $LANG_NAME locale
- [ ] Verify date/number formatting
- [ ] Check for text truncation issues

### Acceptance Criteria
- All strings translated accurately
- Pluralization rules work correctly
- UI displays properly in $LANG_NAME
- No truncation or layout issues
- Date/time formats respect locale

### Parent Issue
#$PARENT6" \
    --label "i18n,translation" \
    --assignee "cleveland-lewis"
done

echo "All issues created successfully!"
