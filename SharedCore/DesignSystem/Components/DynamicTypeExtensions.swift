import SwiftUI

// MARK: - Dynamic Type Compatible Font Extensions
// These extensions provide semantic font styles that scale with Dynamic Type

extension Font {
    /// Extra small text (replaces hard-coded 10pt)
    static var extraSmallCaption: Font {
        .system(size: 10, weight: .regular).weight(.regular)
    }
    
    /// Small caption (replaces hard-coded 12-13pt)
    static var smallCaption: Font {
        .caption2
    }
    
    /// Standard caption (replaces hard-coded 13-14pt)
    static var standardCaption: Font {
        .caption
    }
    
    /// Body text (replaces hard-coded 14-17pt)
    static var standardBody: Font {
        .body
    }
    
    /// Subheadline (replaces hard-coded 17pt medium)
    static var strongSubheadline: Font {
        .subheadline.weight(.medium)
    }
    
    /// Large display number (replaces hard-coded 34pt)
    static var largeNumber: Font {
        .title.weight(.semibold)
    }
    
    /// Extra large display number (replaces hard-coded 48pt)
    static var extraLargeNumber: Font {
        .largeTitle.weight(.light)
    }
    
    /// Timer display (replaces hard-coded 60pt monospaced)
    static var timerDisplay: Font {
        .system(.largeTitle, design: .monospaced).weight(.light)
    }
    
    /// Small icon label (replaces hard-coded 6pt)
    static var tinyIcon: Font {
        .system(size: 6, weight: .regular)
    }
}

// MARK: - Text Style View Modifiers

extension View {
    /// Applies extra small caption style (Dynamic Type compatible)
    func extraSmallCaptionStyle() -> some View {
        self.font(.extraSmallCaption)
            .foregroundStyle(.secondary)
    }
    
    /// Applies small caption style (Dynamic Type compatible)
    func smallCaptionStyle() -> some View {
        self.font(.smallCaption)
            .foregroundStyle(.secondary)
    }
    
    /// Applies standard caption style (Dynamic Type compatible)
    func standardCaptionStyle() -> some View {
        self.font(.standardCaption)
            .foregroundStyle(.secondary)
    }
    
    /// Applies body text style (Dynamic Type compatible)
    func standardBodyStyle() -> some View {
        self.font(.standardBody)
    }
    
    /// Applies subheadline style with medium weight (Dynamic Type compatible)
    func strongSubheadlineStyle() -> some View {
        self.font(.strongSubheadline)
    }
    
    /// Applies large number display style (Dynamic Type compatible)
    func largeNumberStyle() -> some View {
        self.font(.largeNumber)
    }
    
    /// Applies extra large number display style (Dynamic Type compatible)
    func extraLargeNumberStyle() -> some View {
        self.font(.extraLargeNumber)
    }
    
    /// Applies timer display style (Dynamic Type compatible)
    func timerDisplayStyle() -> some View {
        self.font(.timerDisplay)
    }
}

// MARK: - Migration Guide for Hard-Coded Sizes
/*
 Replace hard-coded font sizes with semantic equivalents:
 
 .font(.system(size: 6))  → .font(.tinyIcon)
 .font(.system(size: 10)) → .font(.extraSmallCaption)
 .font(.system(size: 12)) → .font(.smallCaption) or .font(.caption2)
 .font(.system(size: 13)) → .font(.standardCaption) or .font(.caption)
 .font(.system(size: 14)) → .font(.standardBody) or .font(.body)
 .font(.system(size: 17)) → .font(.strongSubheadline) or .font(.subheadline)
 .font(.system(size: 34)) → .font(.largeNumber) or .font(.title)
 .font(.system(size: 48)) → .font(.extraLargeNumber) or .font(.largeTitle)
 .font(.system(size: 60, design: .monospaced)) → .font(.timerDisplay)
 
 For icons in overlays, use Image's built-in font modifier:
 Image(systemName: "plus").font(.body) instead of .font(.system(size: 14))
 */
