import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

struct GenerationView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedBriefID: UUID?
    @State private var currentPage = 1

    private let pageSize = 8

    private var readyBriefs: [CommercialBrief] {
        appState.workspace.briefs.filter { $0.status == .ready || $0.status == .draft }
    }

    private var pagedAssets: [AssetRecord] {
        appState.workspace.assets
            .sorted { $0.createdAt > $1.createdAt }
            .page(currentPage, pageSize: pageSize)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
            ScreenHeader("Image generation", subtitle: "Create with a provider or bring existing results into the managed library.") {
                Button("Import images", systemImage: "square.and.arrow.down", action: chooseImages)
                    .buttonStyle(ThoockPrimaryButtonStyle())
            }

            Group {
                if geometry.size.width < 760 {
                    VStack(alignment: .leading, spacing: 14) {
                        importPanel
                        providerPanel
                    }
                } else {
                    HStack(alignment: .top, spacing: 18) {
                        importPanel
                        providerPanel
                    }
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("Managed assets").font(.title3.weight(.semibold))
                if appState.workspace.assets.isEmpty {
                    ThoockEmptyState(
                        icon: "photo.stack",
                        title: "No images yet",
                        message: "Import image results to begin review and metadata preparation."
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    ForEach(pagedAssets) { asset in
                        HStack(spacing: 12) {
                            AssetThumbnail(asset: asset, size: CGSize(width: 54, height: 54))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(asset.originalFilename).fontWeight(.medium).lineLimit(1)
                                Text("\(asset.width) × \(asset.height) · \(asset.megapixels.formatted(.number.precision(.fractionLength(2)))) MP")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            TagLabel(asset.reviewStatus.rawValue, tint: reviewColor(asset.reviewStatus))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if appState.workspace.assets.count > pageSize {
                        Divider()
                        PaginationBar(
                            totalItems: appState.workspace.assets.count,
                            pageSize: pageSize,
                            currentPage: $currentPage
                        )
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .thoockPanel()
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private var importPanel: some View {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Import existing images", systemImage: "photo.on.rectangle.angled")
                        .font(.title3.weight(.semibold))
                    Text("Imported files become immutable provider originals. Thoock inspects their real dimensions, computes a checksum, and creates review thumbnails.")
                        .foregroundStyle(.secondary)
                    Picker("Link to brief", selection: $selectedBriefID) {
                        Text("No linked brief").tag(nil as UUID?)
                        ForEach(readyBriefs) { brief in
                            Text(brief.title).tag(Optional(brief.id))
                        }
                    }
                    Button("Choose image files…", action: chooseImages)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .thoockPanel()
    }

    private var providerPanel: some View {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Live provider generation", systemImage: "wand.and.stars")
                        .font(.title3.weight(.semibold))
                    if let provider = appState.providerConfigs[.image] {
                        Text("\(provider.providerName) is configured\(provider.defaultModel.map { " with \($0)" } ?? "").")
                            .foregroundStyle(.secondary)
                        Label("Provider adapter is the next implementation slice.", systemImage: "hammer")
                            .font(.callout)
                    } else {
                        Text("Configure an image provider to generate directly from ready briefs.")
                            .foregroundStyle(.secondary)
                        Button("Open Settings") { appState.selectedSection = .settings }
                            .buttonStyle(ThoockSecondaryButtonStyle())
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .thoockPanel()
    }

    private func chooseImages() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Choose image results to copy into the Thoock library."
        if panel.runModal() == .OK {
            appState.importAssets(from: panel.urls, briefID: selectedBriefID)
        }
        #endif
    }
}

struct ReviewView: View {
    @EnvironmentObject private var appState: AppState
    @State private var filter: AssetReviewStatus?
    @State private var currentPage = 1

    private let pageSize = 12

    private var assets: [AssetRecord] {
        appState.workspace.assets.filter { filter == nil || $0.reviewStatus == filter }
    }

    private var pagedAssets: [AssetRecord] {
        assets.page(currentPage, pageSize: pageSize)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScreenHeader("Review queue", subtitle: "Inspect quality and make the human approval decision.") {
                Picker("Review status", selection: $filter) {
                    Text("All images").tag(nil as AssetReviewStatus?)
                    ForEach(AssetReviewStatus.allCases) { status in
                        Text(status.rawValue).tag(Optional(status))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 190, minHeight: 38)
                .thoockControl()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if assets.isEmpty {
                ThoockEmptyState(
                    icon: "checkmark.rectangle.stack",
                    title: "No images to review",
                    message: "Import or generate images to begin quality review."
                ) {
                    Button("Go to generation") { appState.selectedSection = .generation }
                        .buttonStyle(ThoockPrimaryButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .thoockPanel()
            } else {
                GeometryReader { geometry in
                    let columnCount = max(1, min(4, Int((geometry.size.width + 14) / 286)))
                    let columns = Array(
                        repeating: GridItem(.flexible(minimum: 0), spacing: 14, alignment: .top),
                        count: columnCount
                    )

                    VStack(spacing: 0) {
                        ScrollView {
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                                ForEach(pagedAssets) { asset in
                                    ReviewAssetCard(asset: asset)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(2)
                        }
                        PaginationBar(totalItems: assets.count, pageSize: pageSize, currentPage: $currentPage)
                    }
                }
            }
        }
        .padding(28)
        .onChange(of: filter) { _, _ in currentPage = 1 }
    }
}

private struct ReviewAssetCard: View {
    @EnvironmentObject private var appState: AppState
    let asset: AssetRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AssetThumbnail(asset: asset, size: CGSize(width: 320, height: 210), fillsWidth: true)
                .frame(maxWidth: .infinity)
                .clipped()
            VStack(alignment: .leading, spacing: 9) {
                Text(asset.originalFilename)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(asset.width) × \(asset.height) · \(asset.megapixels.formatted(.number.precision(.fractionLength(2)))) MP · \(asset.format)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                HStack {
                    Button {
                        appState.updateReviewStatus(for: asset.id, to: .approved)
                    } label: {
                        Label("Approve", systemImage: "checkmark")
                    }
                    .tint(.green)
                    .buttonStyle(ThoockIconButtonStyle(tint: ThoockTheme.accentDark))

                    Button {
                        appState.updateReviewStatus(for: asset.id, to: .rejected)
                    } label: {
                        Label("Reject", systemImage: "xmark")
                    }
                    .tint(.red)
                    .buttonStyle(ThoockIconButtonStyle(tint: ThoockTheme.danger))
                    Spacer(minLength: 4)
                    TagLabel(asset.reviewStatus.rawValue, tint: reviewColor(asset.reviewStatus))
                }
                .labelStyle(.iconOnly)
                .frame(maxWidth: .infinity)
            }
            .padding(13)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .thoockPanel(raised: true)
    }
}

struct MetadataView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: UUID?

    private var approvedAssets: [AssetRecord] {
        appState.workspace.assets.filter { $0.reviewStatus == .approved }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScreenHeader("Metadata", subtitle: "Prepare Adobe-compatible titles, categories, and ordered keywords.")

            if approvedAssets.isEmpty {
                ThoockEmptyState(
                    icon: "tag",
                    title: "No approved images",
                    message: "Approve an image in the review queue before editing its metadata."
                ) {
                    Button("Open Review") { appState.selectedSection = .review }
                        .buttonStyle(ThoockPrimaryButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .thoockPanel()
            } else {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        List(approvedAssets, selection: $selection) { asset in
                            HStack(spacing: 10) {
                                AssetThumbnail(asset: asset, size: CGSize(width: 46, height: 46))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(asset.metadata.title.isEmpty ? asset.originalFilename : asset.metadata.title)
                                        .fontWeight(.medium).lineLimit(1)
                                    Label(asset.metadata.isComplete ? "Complete" : "Needs metadata",
                                          systemImage: asset.metadata.isComplete ? "checkmark.circle.fill" : "exclamationmark.circle")
                                        .font(.caption)
                                        .foregroundStyle(asset.metadata.isComplete ? .green : .orange)
                                }
                            }
                            .tag(asset.id)
                        }
                        .frame(width: min(310, max(220, geometry.size.width * 0.34)))
                        .scrollContentBackground(.hidden)

                        Divider()

                        if let selection,
                           let asset = approvedAssets.first(where: { $0.id == selection }) {
                            MetadataEditor(asset: asset)
                                .id(asset.id)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ThoockEmptyState(icon: "photo", title: "Select an image", message: "Choose an approved image to edit its Adobe metadata.")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .thoockPanel()
                .onAppear { selection = selection ?? approvedAssets.first?.id }
            }
        }
        .padding(28)
    }
}

private struct MetadataEditor: View {
    @EnvironmentObject private var appState: AppState
    let asset: AssetRecord
    @State private var title: String
    @State private var category: String
    @State private var keywords: String

    init(asset: AssetRecord) {
        self.asset = asset
        _title = State(initialValue: asset.metadata.title)
        _category = State(initialValue: asset.metadata.category)
        _keywords = State(initialValue: asset.metadata.keywords.joined(separator: ", "))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AssetThumbnail(asset: asset, size: CGSize(width: 420, height: 220), fillsWidth: true)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                TextField("Title", text: $title, axis: .vertical)
                    .lineLimit(2...3)
                    .textFieldStyle(.plain)
                    .thoockControl()
                TextField("Adobe category", text: $category)
                    .textFieldStyle(.plain)
                    .thoockControl()
                VStack(alignment: .leading, spacing: 7) {
                    Text("Keywords").font(.callout.weight(.medium))
                    TextField("comma, separated, ordered keywords", text: $keywords, axis: .vertical)
                        .lineLimit(4...8)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .thoockPanel(radius: 9)
                    Text("Put the strongest keywords first. Duplicates and empty entries are removed when saved.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Spacer()
                    Button("Save metadata", action: save)
                        .buttonStyle(ThoockPrimaryButtonStyle())
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(22)
        }
    }

    private func save() {
        var seen = Set<String>()
        let normalizedKeywords = keywords
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
        appState.updateMetadata(
            for: asset.id,
            metadata: AdobeMetadata(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category.trimmingCharacters(in: .whitespacesAndNewlines),
                keywords: normalizedKeywords
            )
        )
    }
}

struct ExportView: View {
    @EnvironmentObject private var appState: AppState
    @State private var exportResult: ExportResult?

    private var approvedCount: Int {
        appState.workspace.assets.filter { $0.reviewStatus == .approved }.count
    }

    private var eligibleCount: Int {
        appState.workspace.assets.filter(\.isExportEligible).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ScreenHeader("Adobe exports", subtitle: "Build a local package of JPEGs, CSV metadata, a manifest, and compliance report.") {
                Button("Create export", systemImage: "square.and.arrow.down", action: chooseExportFolder)
                    .buttonStyle(ThoockPrimaryButtonStyle())
                    .disabled(eligibleCount == 0)
            }

            HStack(spacing: 14) {
                SummaryMetric(title: "Approved images", value: approvedCount)
                SummaryMetric(title: "Complete metadata", value: eligibleCount)
                SummaryMetric(title: "Needs metadata", value: max(0, approvedCount - eligibleCount))
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Package contents").font(.title3.weight(.semibold))
                ExportPackageRow(icon: "photo", title: "Prepared JPEG images", detail: "High-quality JPEG copies; originals remain untouched")
                ExportPackageRow(icon: "tablecells", title: "adobe-metadata.csv", detail: "Filename, title, ordered keywords, and category")
                ExportPackageRow(icon: "doc.text", title: "manifest.json", detail: "Stable IDs, source names, dimensions, and checksums")
                ExportPackageRow(icon: "checkmark.shield", title: "compliance-report.txt", detail: "Records approval and metadata completeness at export time")
                Divider()
                if eligibleCount == 0 {
                    Label("Approve images and complete their metadata to enable export.", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                } else {
                    Label("\(eligibleCount) image\(eligibleCount == 1 ? "" : "s") ready to export", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .thoockPanel()

            Spacer()
        }
        .padding(28)
        .alert("Export complete", isPresented: Binding(
            get: { exportResult != nil },
            set: { if !$0 { exportResult = nil } }
        )) {
            Button("Reveal in Finder") {
                #if os(macOS)
                if let url = exportResult?.folderURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                #endif
            }
            Button("Done", role: .cancel) {}
        } message: {
            Text("Exported \(exportResult?.assetCount ?? 0) images and metadata files.")
        }
    }

    private func chooseExportFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        if panel.runModal() == .OK, let url = panel.url {
            exportResult = appState.exportApprovedAssets(to: url)
        }
        #endif
    }
}

private struct ExportPackageRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 13) {
            ThoockIconTile(icon: icon, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct AssetThumbnail: View {
    @EnvironmentObject private var appState: AppState
    let asset: AssetRecord
    let size: CGSize
    var fillsWidth = false

    var body: some View {
        Group {
            #if os(macOS)
            if let url = appState.fileURL(for: asset.thumbnailRelativePath),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
            #else
            placeholder
            #endif
        }
        .frame(width: fillsWidth ? nil : size.width, height: size.height)
        .frame(maxWidth: fillsWidth ? .infinity : nil)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var placeholder: some View {
        Image(systemName: "photo").foregroundStyle(.secondary)
    }
}

private func reviewColor(_ status: AssetReviewStatus) -> Color {
    switch status {
    case .awaitingReview: .orange
    case .approved: .green
    case .rejected: .red
    }
}
