import Combine
import Foundation

#if os(macOS)
import AppKit
#endif

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var needsFirstLaunchSetup = true
    @Published private(set) var libraryURL: URL?
    @Published private(set) var providerConfigs: [ProviderKind: ProviderConfig] = [:]
    @Published private(set) var workspace = WorkspaceData()
    @Published private(set) var providerLogs: [ProviderLogEntry] = []
    @Published var selectedSection: AppSection = .dashboard
    @Published var presentedError: AppError?

    private let preferences: PreferencesStore
    private let vault: KeychainVault
    private var isAccessingLibrary = false

    init() {
        self.preferences = PreferencesStore()
        self.vault = KeychainVault()
        restoreWorkspace()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--load-demo") {
            installDemoData()
        }
        if let sectionArgument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--section=") }),
           let section = AppSection(rawValue: String(sectionArgument.dropFirst("--section=".count))) {
            selectedSection = section
        }
        #endif
    }

    init(preferences: PreferencesStore, vault: KeychainVault) {
        self.preferences = preferences
        self.vault = vault
        restoreWorkspace()
    }

    func completeFirstLaunch(
        libraryURL: URL,
        providers: [ProviderKind: ProviderSetup]
    ) throws {
        let bookmark = try libraryURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        if !isAccessingLibrary {
            isAccessingLibrary = libraryURL.startAccessingSecurityScopedResource()
        }

        try LibraryLayout.prepare(at: libraryURL)

        var configurations: [ProviderKind: ProviderConfig] = [:]
        for (kind, setup) in providers where setup.isConfigured {
            configurations[kind] = setup.configuration
            if !setup.apiKey.isEmpty {
                try vault.save(setup.apiKey, for: kind)
            }
        }

        try preferences.save(
            AppPreferences(
                libraryBookmark: bookmark,
                providerConfigs: configurations,
                workspaceName: "Thoock"
            )
        )

        self.libraryURL = libraryURL
        providerConfigs = configurations
        workspace = try WorkspaceRepository(libraryURL: libraryURL).load()
        providerLogs = try ProviderLogRepository(libraryURL: libraryURL).load()
        needsFirstLaunchSetup = false
    }

    func addOpportunity(_ opportunity: Opportunity) {
        workspace.opportunities.insert(opportunity, at: 0)
        persistWorkspace()
    }

    func deleteOpportunities(at offsets: IndexSet, from opportunities: [Opportunity]) {
        let ids = Set(offsets.map { opportunities[$0].id })
        workspace.opportunities.removeAll { ids.contains($0.id) }
        persistWorkspace()
    }

    func updateOpportunity(_ opportunity: Opportunity) {
        guard let index = workspace.opportunities.firstIndex(where: { $0.id == opportunity.id }) else { return }
        workspace.opportunities[index] = opportunity
        persistWorkspace()
    }

    func addBrief(_ brief: CommercialBrief) {
        workspace.briefs.insert(brief, at: 0)
        if let opportunityID = brief.opportunityID,
           let index = workspace.opportunities.firstIndex(where: { $0.id == opportunityID }) {
            workspace.opportunities[index].status = .briefed
        }
        persistWorkspace()
    }

    func deleteBriefs(at offsets: IndexSet, from briefs: [CommercialBrief]) {
        let ids = Set(offsets.map { briefs[$0].id })
        workspace.briefs.removeAll { ids.contains($0.id) }
        persistWorkspace()
    }

    func importAssets(from urls: [URL], briefID: UUID?) {
        guard let libraryURL else { return }
        do {
            let records = try AssetImporter(libraryURL: libraryURL).importImages(at: urls, briefID: briefID)
            workspace.assets.insert(contentsOf: records, at: 0)
            persistWorkspace()
            selectedSection = .review
        } catch {
            present(error)
        }
    }

    func updateReviewStatus(for assetID: UUID, to status: AssetReviewStatus) {
        guard let index = workspace.assets.firstIndex(where: { $0.id == assetID }) else { return }
        workspace.assets[index].reviewStatus = status
        persistWorkspace()
    }

    func updateMetadata(for assetID: UUID, metadata: AdobeMetadata) {
        guard let index = workspace.assets.firstIndex(where: { $0.id == assetID }) else { return }
        workspace.assets[index].metadata = metadata
        persistWorkspace()
    }

    func exportApprovedAssets(to parentURL: URL) -> ExportResult? {
        guard let libraryURL else { return nil }
        do {
            return try AdobeExporter(libraryURL: libraryURL).export(workspace.assets, to: parentURL)
        } catch {
            present(error)
            return nil
        }
    }

    func recordProviderLog(_ entry: ProviderLogEntry) {
        guard let libraryURL else { return }
        do {
            let secrets = ProviderKind.allCases.compactMap { try? vault.credential(for: $0) }
            let safeEntry = try ProviderLogRepository(libraryURL: libraryURL).append(entry, secrets: secrets)
            providerLogs.insert(safeEntry, at: 0)
        } catch {
            present(error)
        }
    }

    func exportProviderLogs(_ entries: [ProviderLogEntry], to destinationURL: URL) -> Bool {
        guard let libraryURL else { return false }
        do {
            try ProviderLogRepository(libraryURL: libraryURL).exportCSV(entries, to: destinationURL)
            return true
        } catch {
            present(error)
            return false
        }
    }

    var containsDemoData: Bool {
        workspace.opportunities.contains { $0.notes.hasPrefix(DemoDataFactory.opportunityMarker) }
    }

    func installDemoData() {
        guard let libraryURL, !containsDemoData else { return }
        do {
            let payload = try DemoDataFactory.make(libraryURL: libraryURL)
            workspace.opportunities.insert(contentsOf: payload.workspace.opportunities, at: 0)
            workspace.briefs.insert(contentsOf: payload.workspace.briefs, at: 0)
            workspace.assets.insert(contentsOf: payload.workspace.assets, at: 0)
            providerLogs.insert(contentsOf: payload.providerLogs, at: 0)
            try WorkspaceRepository(libraryURL: libraryURL).save(workspace)
            try ProviderLogRepository(libraryURL: libraryURL).save(providerLogs)
            selectedSection = .dashboard
        } catch {
            present(error)
        }
    }

    func removeDemoData() {
        guard let libraryURL, containsDemoData else { return }
        do {
            let opportunityIDs = Set(
                workspace.opportunities
                    .filter { $0.notes.hasPrefix(DemoDataFactory.opportunityMarker) }
                    .map(\.id)
            )
            let briefIDs = Set(
                workspace.briefs
                    .filter { $0.opportunityID.map(opportunityIDs.contains) == true }
                    .map(\.id)
            )
            let demoAssets = workspace.assets.filter { $0.briefID.map(briefIDs.contains) == true }

            for asset in demoAssets {
                try? FileManager.default.removeItem(at: libraryURL.appendingPathComponent(asset.originalRelativePath))
                try? FileManager.default.removeItem(at: libraryURL.appendingPathComponent(asset.thumbnailRelativePath))
            }

            workspace.opportunities.removeAll { opportunityIDs.contains($0.id) }
            workspace.briefs.removeAll { briefIDs.contains($0.id) }
            workspace.assets.removeAll { demoAssets.contains($0) }
            providerLogs.removeAll { $0.providerName == DemoDataFactory.providerName }
            try WorkspaceRepository(libraryURL: libraryURL).save(workspace)
            try ProviderLogRepository(libraryURL: libraryURL).save(providerLogs)
        } catch {
            present(error)
        }
    }

    func fileURL(for relativePath: String) -> URL? {
        libraryURL?.appendingPathComponent(relativePath)
    }

    func updateWorkspaceName(_ name: String) {
        do {
            try updatePreferences { $0.workspaceName = name.trimmingCharacters(in: .whitespacesAndNewlines) }
            objectWillChange.send()
        } catch {
            present(error)
        }
    }

    func hasCredential(for kind: ProviderKind) -> Bool {
        vault.containsCredential(for: kind)
    }

    func removeProvider(_ kind: ProviderKind) {
        do {
            try vault.removeCredential(for: kind)
            providerConfigs[kind] = nil
            try updatePreferences { $0.providerConfigs = providerConfigs }
        } catch {
            present(error)
        }
    }

    func revealLibraryInFinder() {
        guard let libraryURL else { return }
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([libraryURL])
        #endif
    }

    func resetWorkspaceConnection() {
        if isAccessingLibrary {
            libraryURL?.stopAccessingSecurityScopedResource()
        }
        isAccessingLibrary = false
        libraryURL = nil
        providerConfigs = [:]
        workspace = WorkspaceData()
        providerLogs = []
        preferences.clear()
        needsFirstLaunchSetup = true
    }

    private func restoreWorkspace() {
        do {
            let stored = try preferences.load()
            var bookmarkIsStale = false
            let url = try URL(
                resolvingBookmarkData: stored.libraryBookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &bookmarkIsStale
            )
            isAccessingLibrary = url.startAccessingSecurityScopedResource()
            try LibraryLayout.prepare(at: url)

            if bookmarkIsStale {
                let renewed = try url.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                var renewedPreferences = stored
                renewedPreferences.libraryBookmark = renewed
                try preferences.save(renewedPreferences)
            }

            libraryURL = url
            providerConfigs = stored.providerConfigs
            workspace = try WorkspaceRepository(libraryURL: url).load()
            providerLogs = try ProviderLogRepository(libraryURL: url).load()
            needsFirstLaunchSetup = false
        } catch PreferencesError.notConfigured {
            needsFirstLaunchSetup = true
        } catch {
            needsFirstLaunchSetup = true
            present(error)
        }
    }

    private func persistWorkspace() {
        guard let libraryURL else { return }
        do {
            try WorkspaceRepository(libraryURL: libraryURL).save(workspace)
        } catch {
            present(error)
        }
    }

    private func updatePreferences(_ update: (inout AppPreferences) -> Void) throws {
        var stored = try preferences.load()
        update(&stored)
        try preferences.save(stored)
    }

    private func present(_ error: Error) {
        presentedError = AppError(message: error.localizedDescription)
    }
}
