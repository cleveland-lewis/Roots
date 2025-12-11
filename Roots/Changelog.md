# Changelog

## 2025-12-11
- Planner now listens to live assignment updates and re-runs scheduling so stored sessions and overflow reflect real data without placeholders.
- Grade entry persists course grades into `GradesStore`, recalculates GPA immediately, and maps percentages to letters for accurate breakdowns.
- Added a reusable letter-grade helper to keep grade calculations consistent across the app.
- Removed local build artifacts (`DerivedData/`, `build/`) and macOS junk to keep the repo clean before git init.
- Replaced `.gitignore` with a full Xcode template covering DerivedData/build, xcuserdata, SwiftPM, pods, Carthage, fastlane, and logs.
- Initialized git, staged the cleaned project, committed the baseline, and set `origin` to git@github.com:cleveland-lewis/Roots.git.
