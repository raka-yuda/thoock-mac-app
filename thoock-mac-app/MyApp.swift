import SwiftUI

@main struct MyApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 980, minHeight: 680)
                .tint(ThoockTheme.accent)
                .sheet(isPresented: Binding(
                    get: { appState.needsFirstLaunchSetup },
                    set: { _ in }
                )) {
                    FirstLaunchView()
                        .environmentObject(appState)
                }
        }
        .defaultSize(width: 1280, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("Navigate") {
                navigationCommand("Dashboard", section: .dashboard, key: "1")
                navigationCommand("Opportunities", section: .opportunities, key: "2")
                navigationCommand("Commercial Briefs", section: .briefs, key: "3")
                navigationCommand("Image Generation", section: .generation, key: "4")
                navigationCommand("Review Queue", section: .review, key: "5")
                navigationCommand("Adobe Exports", section: .exports, key: "6")
            }
        }
    }

    private func navigationCommand(_ title: String, section: AppSection, key: KeyEquivalent) -> some View {
        Button(title) { appState.selectedSection = section }
            .keyboardShortcut(key, modifiers: [.command])
    }
}
