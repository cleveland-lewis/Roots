# Multi-Target Quick Reference Card

## When to Put Code in RootsShared vs Platform Targets

### ✅ RootsShared (Cross-Platform)

**Models**
```swift
// YES - Business entities
struct Course { }
struct Assignment { }
struct Exam { }

// YES - Enums without platform UI types
enum AssignmentUrgency: String {
    case low, medium, high, critical
    var label: String { "Low" }
}
```

**Services**
```swift
// YES - Business logic
struct AssignmentPlanEngine { }
actor SchedulingService { }

// YES - Protocols for platform implementations
protocol PersistenceService { }
```

**Utilities**
```swift
// YES - Date/String helpers
extension Date { }
extension String { }

// YES - Formatters
struct DateFormatter { }
```

**Design Tokens**
```swift
// YES - Platform-neutral layout values
struct Spacing {
    static let small: CGFloat = 8
}

// YES - Typography names (not actual fonts)
struct TypographyNames {
    static let body = "body"
}
```

### ❌ Platform Targets (iOS/macOS)

**SwiftUI Views**
```swift
// Platform-specific
struct DashboardView: View { }
struct CalendarView: View { }
```

**Platform Extensions**
```swift
// Platform-specific color mapping
extension AssignmentUrgency {
    var color: Color { .red }
}

extension Course {
    var color: Color { Color(hex: colorHex) }
}
```

**Platform Capabilities**
```swift
// iOS EventKit integration
class IOSEventKitManager { }

// macOS Commands
struct MacCommands: Commands { }
```

**App Entry Points**
```swift
@main
struct RootsApp: App { }
```

---

## Quick Decision Tree

```
Is this code...

├─ A data model?
│  ├─ Does it use Color/UIColor/NSColor?
│  │  ├─ Yes → Store as hex string in RootsShared + platform extension
│  │  └─ No → Put in RootsShared
│  └─ Yes → Put in RootsShared
│
├─ Business logic?
│  ├─ Does it call platform APIs?
│  │  ├─ Yes → Protocol in RootsShared, implementation in target
│  │  └─ No → Put in RootsShared
│  └─ Yes → Put in RootsShared
│
├─ A SwiftUI View?
│  └─ Always put in platform target
│
├─ An extension adding Color?
│  └─ Always put in platform target
│
└─ Platform capability (EventKit, Menus, Windows)?
   └─ Always put in platform target
```

---

## Import Statements

### In RootsShared
```swift
import Foundation  // ✅ Always OK
import SwiftUI     // ⚠️  Only if needed for @Observable, etc.
// NO UIKit, AppKit, EventKit, etc.
```

### In Platform Targets
```swift
import SwiftUI     // ✅ Always OK
import RootsShared // ✅ Always needed
import EventKit    // ✅ OK (platform-specific)
```

---

## Common Patterns

### Pattern 1: Model with Platform-Specific Colors

**RootsShared**:
```swift
public struct Course {
    public let id: UUID
    public var colorHex: String  // ← Stored as hex
}
```

**iOS/macOS Target**:
```swift
import SwiftUI
import RootsShared

extension Course {
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}
```

### Pattern 2: Protocol + Platform Implementation

**RootsShared**:
```swift
public protocol PersistenceService: Actor {
    func saveCourse(_ course: Course) async throws
}
```

**iOS Target**:
```swift
import RootsShared

actor IOSPersistenceService: PersistenceService {
    func saveCourse(_ course: Course) async throws {
        // CoreData implementation
    }
}
```

**macOS Target**:
```swift
import RootsShared

actor MacPersistenceService: PersistenceService {
    func saveCourse(_ course: Course) async throws {
        // CoreData implementation
    }
}
```

### Pattern 3: Shared Container + Platform Injection

**RootsShared**:
```swift
@MainActor
public final class AppContainer: ObservableObject {
    public let persistenceService: any PersistenceService
    public init(persistenceService: any PersistenceService) {
        self.persistenceService = persistenceService
    }
}
```

**iOS App**:
```swift
@main
struct RootsApp: App {
    @StateObject private var container = AppContainer(
        persistenceService: IOSPersistenceService()
    )
    
    var body: some Scene {
        WindowGroup {
            IOSRootView()
                .environmentObject(container)
        }
    }
}
```

**macOS App**:
```swift
@main
struct RootsMacApp: App {
    @StateObject private var container = AppContainer(
        persistenceService: MacPersistenceService()
    )
    
    var body: some Scene {
        WindowGroup {
            MacRootView()
                .environmentObject(container)
        }
    }
}
```

---

## File Naming Conventions

| Type | Location | Example |
|------|----------|---------|
| Model | `RootsShared/Models/` | `Course.swift` |
| Service | `RootsShared/Services/` | `AssignmentPlanEngine.swift` |
| Protocol | `RootsShared/Services/Protocols/` | `PersistenceService.swift` |
| iOS View | `RootsApp/Views/` | `DashboardView.swift` |
| macOS View | `RootsMac/Views/` | `DashboardView.swift` |
| iOS Extension | `RootsApp/PlatformExtensions/` | `Color+iOS.swift` |
| macOS Extension | `RootsMac/PlatformExtensions/` | `Color+macOS.swift` |

---

## Testing Strategy

### Test Shared Code
```swift
// RootsSharedTests/AssignmentPlanEngineTests.swift
import XCTest
@testable import RootsShared

final class AssignmentPlanEngineTests: XCTestCase {
    func testGeneratePlan() {
        let engine = AssignmentPlanEngine()
        // Test cross-platform logic
    }
}
```

### Test Platform Code
```swift
// RootsTests/IOSViewTests.swift
import XCTest
@testable import RootsApp

final class IOSViewTests: XCTestCase {
    func testDashboardView() {
        // Test iOS-specific view logic
    }
}
```

---

## Build Commands

```bash
# Build iOS
xcodebuild -project Roots.xcodeproj -scheme RootsApp -sdk iphonesimulator

# Build macOS
xcodebuild -project Roots.xcodeproj -scheme RootsMac -sdk macosx

# Build and Test Shared Package
cd RootsShared
swift build
swift test

# Build All Targets
xcodebuild -project Roots.xcodeproj -scheme "All" build
```

---

## Troubleshooting

### "Cannot find 'RootsShared' in scope"
→ Verify `RootsShared` is added to target dependencies  
→ Check `import RootsShared` statement  
→ Clean build folder (⇧⌘K)

### "Type 'Color' not found"
→ Make sure you're using hex strings in models  
→ Create platform extension for `var color: Color`  
→ Import `SwiftUI` in extension file

### "Duplicate symbol" errors
→ Make sure code isn't duplicated in both targets  
→ Check that shared code is only in `RootsShared`  
→ Verify platform extensions use `#if os(...)` guards

### Package doesn't update
→ File → Packages → Reset Package Caches  
→ File → Packages → Update to Latest Package Versions  
→ Clean build folder

---

## Migration Checklist (Existing Code → New Architecture)

1. **Identify shared code**
   - [ ] List all model files
   - [ ] List all service/business logic files
   - [ ] List all utility files

2. **Move to RootsShared**
   - [ ] Move models (remove Color properties)
   - [ ] Move services
   - [ ] Move utilities
   - [ ] Update imports to `import Foundation`

3. **Create platform extensions**
   - [ ] Create `Color+iOS.swift`
   - [ ] Create `Color+macOS.swift`
   - [ ] Add color computed properties

4. **Update views**
   - [ ] Add `import RootsShared` to all views
   - [ ] Update color references to use extensions
   - [ ] Verify compilation

5. **Test**
   - [ ] Build iOS target
   - [ ] Build macOS target
   - [ ] Run both apps
   - [ ] Verify shared changes affect both

---

## Remember

**The Golden Rule**: If it compiles without `import SwiftUI`, `import UIKit`, or `import AppKit`, it belongs in `RootsShared`.

**The Color Rule**: Models store hex strings. Platform targets provide `var color: Color` computed properties.

**The Service Rule**: Protocols in `RootsShared`, implementations in platform targets.

**The View Rule**: All SwiftUI views live in platform targets. No exceptions.
