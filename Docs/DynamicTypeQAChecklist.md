# Dynamic Type QA Checklist

## Testing Instructions

Test the app with different Dynamic Type settings:
1. Open **System Settings → Accessibility → Display**
2. Test at these sizes:
   - **Default** (system default)
   - **AX1** (Accessibility size 1 - slightly larger)
   - **AX2** (Accessibility size 2)
   - **AX3** (Accessibility size 3)
   - **AX4** (Accessibility size 4)
   - **AX5** (Accessibility size 5 - largest)

## Areas to Test

### ✅ Dashboard
- [ ] Clock and calendar widget text scales appropriately
- [ ] Quick actions buttons remain tappable (min 44×44 hit target)
- [ ] Today overview card doesn't truncate
- [ ] Events and assignments lists reflow cleanly
- [ ] Energy panel buttons expand properly

### ✅ Grades Page
- [ ] GPA display scales without breaking layout
- [ ] Course list remains readable at all sizes
- [ ] "Add Grade" and "Analytics" buttons scale
- [ ] Grade percentages and letter grades visible
- [ ] Course cards expand to accommodate text

### ✅ Timer Page
- [ ] Timer display (large monospaced numbers) scales
- [ ] Session labels remain visible
- [ ] Control buttons maintain proper hit targets
- [ ] Duration displays don't truncate

### ✅ Calendar Page
- [ ] Day numbers scale appropriately
- [ ] Event labels don't truncate
- [ ] Header text (month/year) scales
- [ ] Calendar grid remains functional

### ✅ Course Outline Editor
- [ ] Node labels scale properly
- [ ] Type badges remain readable
- [ ] Empty state icons and text scale
- [ ] Tree hierarchy remains clear

### ✅ Parsed Assignments Review
- [ ] Assignment titles wrap when needed
- [ ] Date/time labels scale
- [ ] Edit button maintains hit target
- [ ] Empty state icon and message scale

## Layout Requirements

### Text Behavior
- ✅ **Titles**: Should wrap to multiple lines if needed
- ✅ **Body text**: Should reflow naturally
- ✅ **Buttons**: Should expand to accommodate larger text
- ✅ **Cards**: Should grow in height to fit content

### Minimum Hit Targets
- ✅ All interactive elements: **44×44 points minimum**
- ✅ Tested in accessibility sizes

### No Truncation
- ✅ Critical labels never truncate
- ✅ Use `.lineLimit(nil)` or appropriate wrapping
- ✅ Cards expand rather than clip content

## Fixes Applied

### Replaced Hard-Coded Sizes
- `size: 6` → Kept for tiny decorative icons only
- `size: 10` → `.caption2`
- `size: 12-13` → `.caption` or `.caption2.weight(.semibold)`
- `size: 14` → `.subheadline` or `.body`
- `size: 17` → `.headline`
- `size: 24-28` → `.title2` or `.title`
- `size: 34` → `.largeTitle`
- `size: 48` → `.largeTitle` with `.imageScale(.large)` for icons
- `size: 60 monospaced` → `.system(.largeTitle, design: .monospaced)`

### New Semantic Font Extensions
Created `DynamicTypeExtensions.swift` with:
- `.extraSmallCaption`
- `.smallCaption`
- `.standardCaption`
- `.strongSubheadline`
- `.largeNumber`
- `.extraLargeNumber`
- `.timerDisplay`

## Testing Notes

Record any issues found during QA:

### AX1 (Slightly Larger)
- [ ] No issues found
- [ ] Issues: _____

### AX2
- [ ] No issues found
- [ ] Issues: _____

### AX3
- [ ] No issues found
- [ ] Issues: _____

### AX4
- [ ] No issues found
- [ ] Issues: _____

### AX5 (Largest)
- [ ] No issues found
- [ ] Issues: _____

## Sign-Off

- [ ] All Dynamic Type sizes tested
- [ ] No truncation of critical content
- [ ] All interactive elements maintain 44×44 minimum
- [ ] Layouts reflow cleanly
- [ ] No layout breaking or overlap issues

**Tester**: _______________
**Date**: _______________
**Status**: ⬜ Pass / ⬜ Fail

## Notes
_Add any additional observations or recommendations here_
