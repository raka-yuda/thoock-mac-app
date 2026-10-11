import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("thoock.appearance") private var appearance = AppAppearance.system.rawValue
    @State private var sidebarVisible = true
    @State private var commandText = ""

    var body: some View {
        HStack(spacing: 0) {
            if sidebarVisible {
                Sidebar(selection: $appState.selectedSection)
                    .frame(width: 252)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            VStack(spacing: 0) {
                topBar
                destination
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        LinearGradient(
                            colors: [ThoockTheme.canvas, ThoockTheme.accentWash.opacity(0.55), ThoockTheme.canvas],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            }
        }
        .background(ThoockTheme.canvas)
        .foregroundStyle(ThoockTheme.ink)
        .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
        .onAppear(perform: performDebugAppearanceOverride)
        .alert(item: $appState.presentedError) { error in
            Alert(
                title: Text("Thoock encountered a problem"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy(duration: 0.24)) { sidebarVisible.toggle() }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(ThoockIconButtonStyle())
            .help(sidebarVisible ? "Hide sidebar" : "Show sidebar")

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ThoockTheme.muted)
                TextField("Search or run a command…", text: $commandText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit(performCommand)
                Text("⌘ K")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ThoockTheme.muted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(ThoockTheme.accentWash, in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6).stroke(ThoockTheme.borderSoft)
                    }
            }
            .padding(.horizontal, 12)
            .frame(width: 420, height: 38)
            .background(ThoockTheme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(LinearGradient(colors: [ThoockTheme.surfaceRaised, ThoockTheme.border], startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 11).inset(by: 1).stroke(Color.white.opacity(0.65))
            }
            .shadow(color: Color.black.opacity(0.055), radius: 3, y: 2)

            Spacer()

            HStack(spacing: 7) {
                Circle().fill(ThoockTheme.accent).frame(width: 7, height: 7)
                Text("Local workspace").font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(ThoockTheme.accentDark)
            .padding(.horizontal, 13)
            .frame(height: 36)
            .background(ThoockTheme.accentSoft, in: Capsule())
            .overlay { Capsule().stroke(ThoockTheme.border) }

            Button(action: cycleAppearance) {
                Image(systemName: appearanceIcon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(ThoockIconButtonStyle())
            .help("Appearance: \(AppAppearance(rawValue: appearance)?.title ?? "System")")

            Button {
                appState.selectedSection = .settings
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(ThoockIconButtonStyle())
            .help("Settings")
        }
        .padding(.horizontal, 24)
        .frame(height: 68)
        .background(.regularMaterial)
    }

    private func performCommand() {
        let query = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        if let match = AppSection.allCases.first(where: {
            $0.title.localizedCaseInsensitiveContains(query) || $0.rawValue.localizedCaseInsensitiveContains(query)
        }) {
            withAnimation(.easeInOut(duration: 0.18)) { appState.selectedSection = match }
            commandText = ""
        }
    }

    private var appearanceIcon: String {
        switch AppAppearance(rawValue: appearance) ?? .system {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon.stars"
        }
    }

    private func cycleAppearance() {
        let current = AppAppearance(rawValue: appearance) ?? .system
        let next: AppAppearance = switch current {
        case .system: .light
        case .light: .dark
        case .dark: .system
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            appearance = next.rawValue
        }
    }

    private func performDebugAppearanceOverride() {
        #if DEBUG
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--appearance=") }),
              let debugAppearance = AppAppearance(rawValue: String(argument.dropFirst("--appearance=".count))) else {
            return
        }
        appearance = debugAppearance.rawValue
        #endif
    }

    @ViewBuilder
    private var destination: some View {
        switch appState.selectedSection {
        case .dashboard:
            DashboardView()
        case .opportunities:
            OpportunitiesView()
        case .briefs:
            BriefsView()
        case .generation:
            GenerationView()
        case .review:
            ReviewView()
        case .metadata:
            MetadataView()
        case .exports:
            ExportView()
        case .providerLogs:
            ProviderLogsView()
        case .settings:
            SettingsView()
        }
    }
}

private struct Sidebar: View {
    @Binding var selection: AppSection

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    Circle().fill(
                        LinearGradient(
                            colors: [ThoockTheme.accent.opacity(0.78), ThoockTheme.accentDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 34, height: 34)
                .shadow(color: ThoockTheme.accent.opacity(0.2), radius: 5, y: 2)
                Text("Thoock")
                    .font(.system(size: 21, weight: .bold))
                    .tracking(-0.5)
                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(height: 68)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    sidebarItem(.dashboard)
                    sidebarSection("Research", items: [.opportunities])
                    sidebarSection("Production", items: [.briefs, .generation, .review, .metadata])
                    sidebarSection("Delivery", items: [.exports])
                    sidebarSection("System", items: [.providerLogs, .settings])
                }
                .padding(.horizontal, 15)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Text("T")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(ThoockTheme.primaryButton, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("Local library").font(.system(size: 12, weight: .semibold))
                    Text("Private workspace").font(.system(size: 10)).foregroundStyle(ThoockTheme.muted)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(ThoockTheme.sidebar.opacity(0.86))
        .background(.regularMaterial)
    }

    private func sidebarSection(_ title: String, items: [AppSection]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.7)
                .foregroundStyle(ThoockTheme.muted)
                .padding(.leading, 9)
            ForEach(items) { sidebarItem($0) }
        }
    }

    private func sidebarItem(_ section: AppSection) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) { selection = section }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 20)
                Text(section.title)
                    .font(.system(size: 13, weight: selection == section ? .semibold : .regular))
                Spacer()
            }
            .foregroundStyle(selection == section ? ThoockTheme.accentDark : ThoockTheme.ink.opacity(0.8))
            .padding(.horizontal, 13)
            .frame(height: 43)
            .background {
                if selection == section {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [ThoockTheme.surfaceRaised.opacity(0.76), ThoockTheme.accentSoft],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(selection == section ? ThoockTheme.accent.opacity(0.28) : Color.clear)
            }
            .shadow(color: selection == section ? ThoockTheme.accentDark.opacity(0.10) : .clear, radius: 4, y: 3)
        }
        .buttonStyle(.plain)
    }
}

struct ScreenHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: Trailing

    init(
        _ title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 29, weight: .bold))
                    .tracking(-0.9)
                    .foregroundStyle(ThoockTheme.ink)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(ThoockTheme.muted)
            }
            Spacer()
            trailing
        }
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}
