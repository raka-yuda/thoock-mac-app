import SwiftUI

#if os(macOS)
import AppKit
#endif

struct FirstLaunchView: View {
    @EnvironmentObject private var appState: AppState

    @State private var step = 0
    @State private var selectedLibraryURL: URL?
    @State private var research = ProviderSetup()
    @State private var brief = ProviderSetup()
    @State private var image = ProviderSetup()
    @State private var upscaler = ProviderSetup()
    @State private var logoRemoval = ProviderSetup()
    @State private var setupError: String?

    private let stepCount = 6

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            Group {
                switch step {
                case 0:
                    libraryStep
                case 1:
                    ProviderSetupStep(
                        title: "Research provider",
                        subtitle: "Used to discover and score stock-image opportunities.",
                        setup: $research,
                        examples: "OpenAI, Gemini, or a compatible endpoint"
                    )
                case 2:
                    ProviderSetupStep(
                        title: "Brief & metadata provider",
                        subtitle: "Used to draft commercial briefs, titles, and keywords.",
                        setup: $brief,
                        examples: "OpenAI, Gemini, or a compatible endpoint"
                    )
                case 3:
                    ProviderSetupStep(
                        title: "Image provider",
                        subtitle: "Used to create the original production images.",
                        setup: $image,
                        examples: "OpenAI, BFL, Stability, SnapGenAI, or another provider"
                    )
                case 4:
                    preparationProvidersStep
                default:
                    summaryStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(32)

            Divider()
            footer
        }
        .frame(width: 720, height: 560)
        .interactiveDismissDisabled()
        .alert("Setup could not be completed", isPresented: Binding(
            get: { setupError != nil },
            set: { if !$0 { setupError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(setupError ?? "Unknown error")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text("Set up Thoock")
                    .font(.title2.weight(.semibold))
                Text("Private, local-first creative production")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(step + 1) of \(stepCount)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private var libraryStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            StepTitle(
                title: "Choose your asset library",
                subtitle: "Thoock keeps originals, thumbnails, prepared files, and exports in a folder you control."
            )

            VStack(alignment: .leading, spacing: 12) {
                Label("Your files stay on this Mac or a connected drive.", systemImage: "lock.shield")
                Label("Original provider results are never overwritten.", systemImage: "square.stack.3d.up")
                Label("You can reveal and back up the library from Finder.", systemImage: "externaldrive")
            }
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: "folder")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedLibraryURL?.lastPathComponent ?? "No folder selected")
                        .fontWeight(.medium)
                    Text(selectedLibraryURL?.path ?? "Choose an empty folder or an existing Thoock library")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button("Choose Folder…", action: chooseFolder)
            }
            .padding(16)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var preparationProvidersStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepTitle(
                title: "Optional preparation providers",
                subtitle: "Add these now or configure them later in Settings."
            )
            HStack(alignment: .top, spacing: 18) {
                CompactProviderForm(title: "Upscaler", setup: $upscaler)
                CompactProviderForm(title: "Logo removal", setup: $logoRemoval)
            }
        }
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            StepTitle(
                title: "Ready to create",
                subtitle: "Thoock will initialize the managed folders and save credentials securely in Keychain."
            )

            VStack(spacing: 0) {
                SummaryRow(label: "Asset library", value: selectedLibraryURL?.path ?? "Not selected")
                Divider()
                SummaryRow(label: "Research", value: providerSummary(research))
                Divider()
                SummaryRow(label: "Brief & metadata", value: providerSummary(brief))
                Divider()
                SummaryRow(label: "Image generation", value: providerSummary(image))
                Divider()
                SummaryRow(label: "Upscaler", value: providerSummary(upscaler))
                Divider()
                SummaryRow(label: "Logo removal", value: providerSummary(logoRemoval))
            }
            .padding(.horizontal, 16)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))

            Label("Provider setup is optional. Manual opportunities and briefs work without an API key.", systemImage: "info.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Back") { step -= 1 }
                    .keyboardShortcut(.cancelAction)
            }
            Spacer()
            Button(step == stepCount - 1 ? "Finish Setup" : "Continue") {
                advance()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(ThoockPrimaryButtonStyle())
            .disabled(step == 0 && selectedLibraryURL == nil)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(ThoockTheme.sidebar)
    }

    private func providerSummary(_ setup: ProviderSetup) -> String {
        setup.isConfigured ? setup.configuration.providerName : "Configure later"
    }

    private func advance() {
        guard step == stepCount - 1 else {
            step += 1
            return
        }
        guard let selectedLibraryURL else { return }

        do {
            try appState.completeFirstLaunch(
                libraryURL: selectedLibraryURL,
                providers: [
                    .research: research,
                    .briefAndMetadata: brief,
                    .image: image,
                    .upscaler: upscaler,
                    .logoRemoval: logoRemoval
                ]
            )
        } catch {
            setupError = error.localizedDescription
        }
    }

    private func chooseFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Library"
        panel.message = "Choose where Thoock should keep its managed asset library."
        if panel.runModal() == .OK {
            selectedLibraryURL = panel.url
        }
        #endif
    }
}

private struct StepTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.title.weight(.semibold))
            Text(subtitle).font(.body).foregroundStyle(.secondary)
        }
    }
}

private struct ProviderSetupStep: View {
    let title: String
    let subtitle: String
    @Binding var setup: ProviderSetup
    let examples: String

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            StepTitle(title: title, subtitle: subtitle)
            Form {
                TextField("Provider", text: $setup.configuration.providerName, prompt: Text(examples))
                SecureField("API key or access token", text: $setup.apiKey)
                TextField("Default model", text: optionalBinding($setup.configuration.defaultModel), prompt: Text("Optional"))
                TextField("Base URL", text: optionalBinding($setup.configuration.baseURL), prompt: Text("Optional HTTPS endpoint"))
                TextField("Organization", text: optionalBinding($setup.configuration.organization), prompt: Text("Optional"))
                Toggle("Enable this provider", isOn: $setup.configuration.isEnabled)
            }
            .formStyle(.grouped)
            Text("Leave the provider blank to configure it later.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CompactProviderForm: View {
    let title: String
    @Binding var setup: ProviderSetup

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            TextField("Provider name", text: $setup.configuration.providerName)
            SecureField("API key or token", text: $setup.apiKey)
            TextField("Default model", text: optionalBinding($setup.configuration.defaultModel))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 390, alignment: .trailing)
        }
        .padding(.vertical, 12)
    }
}

private func optionalBinding(_ binding: Binding<String?>) -> Binding<String> {
    Binding(
        get: { binding.wrappedValue ?? "" },
        set: { binding.wrappedValue = $0.isEmpty ? nil : $0 }
    )
}
