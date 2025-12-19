//
//  IOSRootView.swift
//  Roots (iOS)
//

#if os(iOS)
import SwiftUI

struct IOSRootView: View {
    var body: some View {
        TabView {
            IOSTimerPageView()
                .tabItem {
                    Label("Timer", systemImage: "timer")
                }
        }
        .background(DesignSystem.Colors.appBackground)
    }
}
#endif
