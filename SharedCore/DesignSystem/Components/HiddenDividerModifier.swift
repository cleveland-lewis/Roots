import SwiftUI

#if os(macOS)
import AppKit

extension View {
    /// Hides the divider in a NavigationSplitView while maintaining resize functionality
    func hideSplitViewDivider() -> some View {
        self.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let window = NSApp.keyWindow ?? NSApp.windows.first {
                    hideDivider(in: window.contentView)
                }
            }
        }
    }
    
    private func hideDivider(in view: NSView?) {
        guard let view = view else { return }
        
        if let splitView = view as? NSSplitView {
            splitView.dividerStyle = .thin
            // Set divider thickness to 0 to make it invisible but still functional
            splitView.setValue(0, forKey: "dividerThickness")
        }
        
        for subview in view.subviews {
            hideDivider(in: subview)
        }
    }
}

#else
extension View {
    func hideSplitViewDivider() -> some View {
        self
    }
}
#endif

