Title: Build failure when compiling CalendarPageView.swift

Description:
The project fails to build due to Swift compiler type-checking and structural errors in CalendarPageView.swift. The xcodebuild output reports multiple errors, including "attribute 'private' can only be used in a non-local scope" and various "expected declaration"/"extraneous '}'" errors after attempted refactors.

Log:
See xcodebuild_after_calendar_fix3_build.log and xcodebuild_after_calendar_fix4_build.log in the repo root for full output. The latest test run is saved to xcodebuild_test_run.log.

Suggested labels: bug, build-failure, ci

Steps to reproduce:
1. Open the Roots Xcode project.
2. Run a Clean & Build for the Roots target or run xcodebuild -target Roots clean build.
3. Observe the compiler errors shown in the attached logs.

Proposed fix summary:
- Ensure gridContent is defined at the struct scope (not inside the body closure).
- Replace AnyView returns with @ViewBuilder computed property to avoid complex generic inference.
- Restore matching braces and remove stray method-chain expressions placed outside of view builders.

File to inspect: Roots/Roots/Roots/CalendarPageView.swift

Timestamp: 2025-12-11T20:14:23.124Z
