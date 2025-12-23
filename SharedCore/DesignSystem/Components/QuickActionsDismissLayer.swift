import SwiftUI

struct QuickActionsDismissLayer: View {
    let isExpanded: Bool
    let onDismiss: () -> Void

    var body: some View {
        if isExpanded {
            TapPassthroughView(onTap: onDismiss)
                .ignoresSafeArea()
                .accessibilityHidden(true)
        }
    }
}

#if os(iOS)
private struct TapPassthroughView: UIViewRepresentable {
    let onTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let recognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        recognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    final class Coordinator: NSObject {
        let onTap: () -> Void

        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }

        @objc func handleTap() {
            onTap()
        }
    }
}
#elseif os(macOS)
private struct TapPassthroughView: NSViewRepresentable {
    let onTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        let recognizer = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        recognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class Coordinator: NSObject {
        let onTap: () -> Void

        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }

        @objc func handleTap() {
            onTap()
        }
    }
}
#endif
