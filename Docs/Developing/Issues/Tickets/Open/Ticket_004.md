# **TICKET-004 — Auto Appearance Mode (Critical)**

- **Title:** Implement and test Auto Appearance (sync with OS)
    
- **Goal:** When the user selects **Auto**, the app should **follow the system’s Light/Dark appearance** in real time, while still allowing explicit Light/Dark overrides when Auto is not selected.
    

---

## **1. Problem Statement**

  

Right now, you want:

- An **Auto** theme mode that means:
    
    - “Match whatever the OS is doing (Light/Dark).”
        
    
- A **clean separation** between:
    
    - **Explicit modes**: Light / Dark
        
    - **Auto mode**: Follow OS
        
    

  

This ticket is specifically about **OS sync behavior**, not about UI wiring or persistence—that’s primarily covered in TICKET-003 and TICKET-045. Here we make Auto mode actually _behave like Auto_:

- When preference == .system (Auto):
    
    - The app tracks OS appearance changes and updates theme accordingly.
        
    
- When preference == .light or .dark:
    
    - The app **ignores** OS appearance changes.
        
    

---

## **2. Functional Requirements**

- When the user chooses **Auto**:
    
    - On launch:
        
        - The app inspects the OS appearance and sets Light/Dark accordingly.
            
        
    - While running:
        
        - If OS appearance changes (e.g. sunset / manual toggle), the app updates its color scheme without relaunch.
            
        
    
- When the user chooses **Light** or **Dark**:
    
    - The app _stays_ in that mode regardless of OS.
        
    - OS transitions do not affect the app.
        
    
- Switching from:
    
    - Auto → Light/Dark: disconnect from OS.
        
    - Light/Dark → Auto: immediately match current OS appearance, then follow further changes.
        
    

---

## **3. Dependencies & Integration Points**

- **Depends on:**
    
    - TICKET-003: ThemeManager with preference + effectiveColorScheme is in place.
        
    
- **Touches:**
    
    - App entry (RootsApp / SceneDelegate)
        
    - ThemeManager logic
        
    - Platform-specific appearance observation (macOS + iOS/iPadOS)
        
    

  

The core idea:

- ThemeManager owns the **policy** (“Auto means follow OS”).
    
- Platform-specific helpers own the **mechanics** (“how do I detect OS appearance changes?”).
    

---

## **4. Design: ThemeManager Extensions**

  

You already have:

```
enum ThemePreference: String, Codable {
    case light
    case dark
    case system
}

final class ThemeManager: ObservableObject {
    @Published var preference: ThemePreference { didSet { … } }
    @Published private(set) var effectiveColorScheme: ColorScheme
    …
}
```

For Auto mode, extend ThemeManager with:

- A way to **apply system appearance** when preference == .system.
    
- A public function to be called by platform hooks when OS appearance changes.
    

  

### **4.1 System Appearance Integration Methods**

```
extension ThemeManager {
    func applySystemAppearance(_ systemScheme: ColorScheme) {
        // Only honor this if preference == .system
        guard preference == .system else { return }
        if effectiveColorScheme != systemScheme {
            effectiveColorScheme = systemScheme
        }
    }

    func refreshEffectiveColorSchemeUsingSystem(_ systemScheme: ColorScheme) {
        switch preference {
        case .light:
            effectiveColorScheme = .light
        case .dark:
            effectiveColorScheme = .dark
        case .system:
            effectiveColorScheme = systemScheme
        }
    }
}
```

Idea:

- On launch: call refreshEffectiveColorSchemeUsingSystem(currentSystemScheme).
    
- On OS change: call applySystemAppearance(newSystemScheme).
    

---

## **5. Platform-Specific OS Appearance Detection**

  

You need a **minimal abstraction** so ThemeManager doesn’t know about UIKit/AppKit directly.

  

### **5.1 SystemAppearanceProvider Protocol**

```
protocol SystemAppearanceProvider {
    func currentColorScheme() -> ColorScheme
    func startObservingAppearanceChanges(_ handler: @escaping (ColorScheme) -> Void)
}
```

Implement:

- iOSSystemAppearanceProvider
    
- macOSSystemAppearanceProvider
    

  

and inject one into the app at startup.

---

## **6. iOS / iPadOS Implementation**

  

SwiftUI complicates this slightly, because you usually read colorScheme from the environment. But here, we want to:

- Observe system userInterfaceStyle changes even when the app is running.
    

  

Two patterns:

  

### **6.1 Scene Phase & Trait Environment Bridge**

  

You can create a small UIViewController or UIWindowScene observer that hooks into traitCollection changes:

```
final class AppearanceObserverViewController: UIViewController {
    var onAppearanceChange: ((ColorScheme) -> Void)?

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }

        let style = traitCollection.userInterfaceStyle
        let scheme: ColorScheme = (style == .dark) ? .dark : .light
        onAppearanceChange?(scheme)
    }
}
```

Wrap this in a helper that satisfies SystemAppearanceProvider:

```
final class iOSSystemAppearanceProvider: SystemAppearanceProvider {
    private weak var observerVC: AppearanceObserverViewController?

    func attach(to window: UIWindow) {
        let vc = AppearanceObserverViewController()
        window.rootViewController = UIHostingController(rootView: RootView())
        observerVC = vc
    }

    func currentColorScheme() -> ColorScheme {
        let style = UITraitCollection.current.userInterfaceStyle
        return (style == .dark) ? .dark : .light
    }

    func startObservingAppearanceChanges(_ handler: @escaping (ColorScheme) -> Void) {
        observerVC?.onAppearanceChange = handler
    }
}
```

You don’t have to use this exact wiring, but **the behavior contract is what matters**:

- startObservingAppearanceChanges calls handler whenever OS dark/light flips.
    
- currentColorScheme returns the current OS choice.
    

  

In SwiftUI-first apps you can also use a small AppearanceReader View that listens to @Environment(\.colorScheme) and reports to ThemeManager via onChange(of:). For example:

```
struct SystemAppearanceListener: View {
    @Environment(\.colorScheme) private var systemScheme
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Color.clear
            .onAppear {
                themeManager.refreshEffectiveColorSchemeUsingSystem(systemScheme)
            }
            .onChange(of: systemScheme) { newScheme in
                themeManager.applySystemAppearance(newScheme)
            }
    }
}
```

Then include SystemAppearanceListener() somewhere high in your root view hierarchy.

  

This is usually the least painful SwiftUI-native way.

---

## **7. macOS Implementation**

  

On macOS, you can inspect:

- NSApp.effectiveAppearance
    
- Or NSAppearance.current from the main thread
    

  

Map to light/dark:

```
enum MacAppearanceResolver {
    static func currentColorScheme() -> ColorScheme {
        let appearance = NSApp.effectiveAppearance
        let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
        return (bestMatch == .darkAqua) ? .dark : .light
    }
}
```

Observer for changes:

- Observe NSApplication.didChangeEffectiveAppearanceNotification (or equivalent):
    

```
final class MacSystemAppearanceProvider: SystemAppearanceProvider {
    private var observer: NSObjectProtocol?

    func currentColorScheme() -> ColorScheme {
        MacAppearanceResolver.currentColorScheme()
    }

    func startObservingAppearanceChanges(_ handler: @escaping (ColorScheme) -> Void) {
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeEffectiveAppearanceNotification,
            object: nil,
            queue: .main
        ) { _ in
            let scheme = MacAppearanceResolver.currentColorScheme()
            handler(scheme)
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
}
```

---

## **8. App Entry Wiring**

  

In RootsApp (SwiftUI entry):

```
@main
struct RootsApp: App {
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.effectiveColorScheme)
                .overlay(
                    SystemAppearanceListener() // the SwiftUI-based listener shown above
                )
        }
    }
}
```

Key behavior:

- On appear, SystemAppearanceListener calls refreshEffectiveColorSchemeUsingSystem(systemScheme).
    
- On OS appearance change:
    
    - If preference == .system: effectiveColorScheme updates → UI re-themes.
        
    - If preference == .light/.dark: applySystemAppearance bails via guard preference == .system else { return }.
        
    

---

## **9. Behavior Matrix**

  

### **9.1 Mode vs System Behaviour**

|**User Preference**|**OS Changes Light↔Dark**|**App Behavior**|
|---|---|---|
|.light|Yes|App remains Light|
|.dark|Yes|App remains Dark|
|.system|Yes|App follows OS (updates in real time)|

### **9.2 Preference Changes**

- Auto → Light:
    
    - App switches to Light immediately
        
    - Ignores OS changes from then on
        
    
- Auto → Dark:
    
    - Switch to Dark immediately
        
    - Ignore OS changes
        
    
- Light/Dark → Auto:
    
    - Immediately set scheme to current system scheme
        
    - Then follow OS changes
        
    

---

## **10. Testing Strategy**

  

### **10.1 Unit-Level Logic Tests (Pure Swift)**

  

You can test ThemeManager logic in isolation, mocking system scheme:

- Given preference = .system and system = .dark:
    
    - refreshEffectiveColorSchemeUsingSystem → effectiveColorScheme == .dark
        
    
- If preference = .dark and system = .light:
    
    - refresh... → effectiveColorScheme == .dark (explicit wins)
        
    
- When applySystemAppearance(.light):
    
    - If preference == .system: effectiveColorScheme updates
        
    - If preference == .dark: no change
        
    

  

### **10.2 Manual Integration Tests (macOS)**

1. Set **macOS** to Light mode in System Settings.
    
2. Launch the app with **Auto** selected.
    
    - Expect the app in Light.
        
    
3. Flip macOS to Dark mode.
    
    - Expect the app to transition to Dark within one OS event cycle.
        
    
4. Switch app preference from Auto → Light while system is Dark.
    
    - App switches to Light and stays Light even if OS goes back to Light → Dark loops.
        
    

  

### **10.3 Manual Integration Tests (iOS)**

1. Set iOS to **Light Appearance**. Launch app with Auto.
    
2. Enable **Dark Mode** in Control Center.
    
    - Confirm app flips to Dark.
        
    
3. Set app to **Dark** manually.
    
    - Flip system back to Light.
        
    - App stays Dark.
        
    
4. Set app back to Auto.
    
    - It should instantly follow current system state.
        
    

---

## **11. Edge Cases**

  

### **11.1 App in Background During OS Change**

- User’s system goes Light → Dark while app is backgrounded.
    
- On next foreground:
    
    - SystemAppearanceListener.onAppear / onChange will update ThemeManager.
        
    
- Behavior: app snaps to correct scheme on resume.
    

  

### **11.2 Multi-Window / Scene Setup**

- Each window has the same ThemeManager reference via @EnvironmentObject.
    
- SystemAppearanceListener exists at least once per process; multiple instances all calling applySystemAppearance is harmless (idempotent if value unchanged).
    

  

### **11.3 Reduced Motion / Accessibility**

- Auto appearance changes can be animated **subtly** or not at all.
    
- You _can_ later tie this into reduced motion settings:
    
    - If UIAccessibility.isReduceMotionEnabled, use minimal animations.
        
    

---

## **12. Interactions With Other Tickets**

- **TICKET-003 (Theme toggles):**
    
    - Provides UI and preference/persistence backbone.
        
    - TICKET-004 plugs into that backbone for OS-aware behavior.
        
    
- **TICKET-027 (Apply preferredColorScheme globally):**
    
    - Ensures consistent .preferredColorScheme(themeManager.effectiveColorScheme) usage.
        
    
- **TICKET-026 (Visual verification):**
    
    - Debug overlay can show:
        
        - preference: system
            
        - effectiveColorScheme: dark
            
        - systemScheme: light/dark (for debugging).
            
        
    

---

## **13. Done Definition (Strict)**

  

TICKET-004 is done when:

- App in **Auto** mode:
    
    - Launches matching OS appearance
        
    - Tracks runtime OS appearance changes
        
    
- App in **Light/Dark** mode:
    
    - Does not change when OS switches
        
    
- Switching between modes behaves exactly as defined in the behavior matrix.
    
- On both macOS and iOS/iPadOS testing:
    
    - No “stuck theme” states
        
    - No need to relaunch app for theme to sync
        
    
- Unit tests validate ThemeManager logic for:
    
    - Auto vs manual modes
        
    - System appearance input
        
    
- Manual QA confirms:
    
    - No partial updates
        
    - No screens ignoring the new color scheme.
        
    

---
