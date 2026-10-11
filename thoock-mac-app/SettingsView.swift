import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var confirmDisconnect = false
    @State private var selection = SettingsSection.general
    @State private var workspaceName = "Thoock"
    @AppStorage("thoock.appearance") private var appearance = AppAppearance.system.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ScreenHeader("Settings", subtitle: "Configure this private production workspace.")

            HStack(alignment: .top, spacing: 16) {
                settingsNavigation
                    .frame(width: 250)

                Group {
                    switch selection {
                    case .general: generalSettings
                    case .providers: providerSettings
                    case .storage: storageSettings
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(28)
        .confirmationDialog(
            "Disconnect this workspace?",
            isPresented: $confirmDisconnect,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) {
                appState.resetWorkspaceConnection()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Library files will remain untouched.")
        }
    }

    private var settingsNavigation: some View {
        VStack(spacing: 8) {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) { selection = section }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: section.icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(selection == section ? ThoockTheme.accent : ThoockTheme.muted)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.title).font(.system(size: 13, weight: .semibold))
                            Text(section.subtitle).font(.system(size: 10)).foregroundStyle(ThoockTheme.muted)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 58)
                    .background(selection == section ? ThoockTheme.accentSoft : ThoockTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11).stroke(ThoockTheme.border)
                    }
                    .overlay(alignment: .leading) {
                        if selection == section {
                            RoundedRectangle(cornerRadius: 2).fill(ThoockTheme.accent).frame(width: 3, height: 38)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .thoockPanel()
    }

    private var generalSettings: some View {
        SettingsCard(title: "General settings", subtitle: "Basic information and production preferences") {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Workspace name").font(.system(size: 12, weight: .semibold))
                    TextField("Workspace name", text: $workspaceName)
                        .textFieldStyle(.plain)
                        .thoockControl(fill: ThoockTheme.accentWash)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Workspace mode").font(.system(size: 12, weight: .semibold))
                    HStack {
                        Circle().fill(ThoockTheme.accent).frame(width: 7, height: 7)
                        Text("Local, private, single user").font(.system(size: 12))
                        Spacer()
                    }
                    .thoockControl(fill: ThoockTheme.accentWash)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Appearance").font(.system(size: 12, weight: .semibold))
                    Text("Follow macOS or keep a fixed theme.").font(.system(size: 11)).foregroundStyle(ThoockTheme.muted)
                }
                Spacer()
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 230)
            }

            Divider().padding(.vertical, 4)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Demo workspace").font(.system(size: 12, weight: .semibold))
                    Text("Add sample opportunities, briefs, images, review states, metadata, and provider logs.")
                        .font(.system(size: 11)).foregroundStyle(ThoockTheme.muted)
                }
                Spacer()
                if appState.containsDemoData {
                    HStack(spacing: 10) {
                        Label("Loaded", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ThoockTheme.accentDark)
                        Button("Remove") { appState.removeDemoData() }
                            .buttonStyle(ThoockSecondaryButtonStyle())
                    }
                } else {
                    Button("Load demo data", systemImage: "sparkles") {
                        appState.installDemoData()
                    }
                    .buttonStyle(ThoockSecondaryButtonStyle())
                }
            }

            Divider().padding(.vertical, 4)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Provider credentials").font(.system(size: 12, weight: .semibold))
                    Text("API keys remain in macOS Keychain and are redacted from logs.")
                        .font(.system(size: 11)).foregroundStyle(ThoockTheme.muted)
                }
                Spacer()
                Label("Protected", systemImage: "checkmark.shield.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ThoockTheme.accentDark)
            }

            Spacer(minLength: 16)
            HStack {
                Spacer()
                Button("Save changes", systemImage: "square.and.arrow.down") {
                    appState.updateWorkspaceName(workspaceName)
                }
                .buttonStyle(ThoockPrimaryButtonStyle())
            }
        }
    }

    private var providerSettings: some View {
        SettingsCard(title: "Providers", subtitle: "Connections and credentials stored in macOS Keychain") {
            ForEach(ProviderKind.allCases) { kind in
                HStack(spacing: 13) {
                    ThoockIconTile(
                        icon: appState.providerConfigs[kind] == nil ? "key.slash" : "key",
                        tint: appState.providerConfigs[kind] == nil ? ThoockTheme.muted : ThoockTheme.accent,
                        size: 38
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(kind.title).font(.system(size: 13, weight: .semibold))
                        Text(providerDescription(kind)).font(.system(size: 11)).foregroundStyle(ThoockTheme.muted)
                    }
                    Spacer()
                    if appState.providerConfigs[kind] != nil {
                        TagLabel(appState.hasCredential(for: kind) ? "Keychain" : "No key",
                                 tint: appState.hasCredential(for: kind) ? ThoockTheme.accentDark : ThoockTheme.warning)
                        Button("Remove", role: .destructive) { appState.removeProvider(kind) }
                            .buttonStyle(ThoockSecondaryButtonStyle())
                    } else {
                        Text("Not configured").font(.system(size: 11)).foregroundStyle(ThoockTheme.muted)
                    }
                }
                .padding(.vertical, 7)
                if kind != ProviderKind.allCases.last { Divider() }
            }
        }
    }

    private var storageSettings: some View {
        SettingsCard(title: "Storage", subtitle: "Managed local files and workspace data") {
            VStack(alignment: .leading, spacing: 7) {
                Text("Asset library").font(.system(size: 12, weight: .semibold))
                HStack {
                    Image(systemName: "externaldrive").foregroundStyle(ThoockTheme.accent)
                    Text(appState.libraryURL?.path ?? "Not connected")
                        .font(.system(size: 12)).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                    Spacer()
                    Button("Reveal in Finder") { appState.revealLibraryInFinder() }
                        .buttonStyle(ThoockSecondaryButtonStyle())
                }
                .padding(12)
                .thoockPanel(radius: 10)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Managed folders").font(.system(size: 12, weight: .semibold))
                Text(LibraryLayout.managedDirectories.joined(separator: "  ·  "))
                    .font(.system(size: 11)).foregroundStyle(ThoockTheme.muted)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(ThoockTheme.accentWash, in: RoundedRectangle(cornerRadius: 9))
            }

            Divider().padding(.vertical, 4)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Disconnect workspace").font(.system(size: 12, weight: .semibold))
                    Text("Library files remain untouched.").font(.system(size: 11)).foregroundStyle(ThoockTheme.muted)
                }
                Spacer()
                Button("Disconnect", role: .destructive) { confirmDisconnect = true }
                    .buttonStyle(ThoockSecondaryButtonStyle())
            }
        }
    }

    private func providerDescription(_ kind: ProviderKind) -> String {
        guard let config = appState.providerConfigs[kind] else { return "Configure during workspace setup" }
        var parts = [config.providerName]
        if let model = config.defaultModel, !model.isEmpty { parts.append(model) }
        return parts.joined(separator: " · ")
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case providers
    case storage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .providers: "Providers"
        case .storage: "Storage"
        }
    }

    var subtitle: String {
        switch self {
        case .general: "Workspace and preferences"
        case .providers: "AI and external services"
        case .storage: "Files and local storage"
        }
    }

    var icon: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .providers: "key"
        case .storage: "externaldrive"
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 19, weight: .bold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(ThoockTheme.muted)
            }
            Divider()
            content
        }
        .padding(22)
        .thoockPanel()
    }
}
