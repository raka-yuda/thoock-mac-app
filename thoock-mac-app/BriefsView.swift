import SwiftUI

struct BriefsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var isCreatingBrief = false
    @State private var currentPage = 1
    @State private var selectedStatus: BriefStatus?

    private let pageSize = 10

    private var briefs: [CommercialBrief] {
        appState.workspace.briefs
            .filter {
                (selectedStatus == nil || $0.status == selectedStatus) &&
                (searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText))
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var pagedBriefs: [CommercialBrief] {
        briefs.page(currentPage, pageSize: pageSize)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScreenHeader("Commercial briefs", subtitle: "Turn opportunities into clear, production-ready image directions.") {
                Button("Create brief", systemImage: "plus") { isCreatingBrief = true }
                    .buttonStyle(ThoockPrimaryButtonStyle())
            }

            HStack(spacing: 12) {
                SummaryMetric(title: "All briefs", value: appState.workspace.briefs.count)
                SummaryMetric(title: "Draft", value: count(.draft))
                SummaryMetric(title: "Ready", value: count(.ready))
                SummaryMetric(title: "Completed", value: count(.completed))
            }

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    TextField("Search briefs", text: $searchText)
                        .textFieldStyle(.plain)
                        .thoockControl()
                    Picker("Status", selection: $selectedStatus) {
                        Text("All statuses").tag(nil as BriefStatus?)
                        ForEach(BriefStatus.allCases) { status in
                            Text(status.rawValue).tag(Optional(status))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                    .thoockControl()
                }
                .padding(14)
                Divider()

                if briefs.isEmpty {
                    ThoockEmptyState(
                        icon: "book.closed",
                        title: "No commercial briefs",
                        message: "Create a manual brief from an opportunity or a new concept."
                    ) {
                        Button("Create brief") { isCreatingBrief = true }
                            .buttonStyle(ThoockPrimaryButtonStyle())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(pagedBriefs) { brief in
                            BriefRow(brief: brief)
                                .listRowBackground(ThoockTheme.surface)
                                .listRowSeparatorTint(ThoockTheme.borderSoft)
                        }
                        .onDelete { offsets in
                            appState.deleteBriefs(at: offsets, from: pagedBriefs)
                        }
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                    Divider()
                    PaginationBar(totalItems: briefs.count, pageSize: pageSize, currentPage: $currentPage)
                }
            }
            .thoockPanel()
        }
        .padding(28)
        .sheet(isPresented: $isCreatingBrief) {
            AddBriefView().environmentObject(appState)
        }
        .onChange(of: searchText) { _, _ in currentPage = 1 }
        .onChange(of: selectedStatus) { _, _ in currentPage = 1 }
    }

    private func count(_ status: BriefStatus) -> Int {
        appState.workspace.briefs.filter { $0.status == status }.count
    }
}

private struct BriefRow: View {
    let brief: CommercialBrief

    var body: some View {
        HStack(spacing: 14) {
            ThoockIconTile(icon: "book.closed", size: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(brief.title).fontWeight(.medium).lineLimit(1)
                Text(brief.concept).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text("\(brief.imageCount) images").font(.callout).foregroundStyle(.secondary)
            TagLabel(brief.aspectRatio, tint: .blue)
            TagLabel(brief.status.rawValue, tint: brief.status == .ready ? .green : .secondary)
                .frame(width: 80, alignment: .leading)
            Text(brief.createdAt, format: .dateTime.month(.abbreviated).day())
                .font(.caption).foregroundStyle(.secondary)
                .frame(width: 62, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}

private struct AddBriefView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var opportunityID: UUID?
    @State private var title = ""
    @State private var concept = ""
    @State private var audience = "Commercial stock buyers"
    @State private var aspectRatio = "4:3"
    @State private var imageCount = 4
    @State private var status = BriefStatus.draft

    private let aspectRatios = ["1:1", "4:3", "3:2", "16:9", "9:16"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Create commercial brief")
                .font(.system(size: 22, weight: .bold))
                .padding(24)
            Form {
                Picker("Opportunity", selection: $opportunityID) {
                    Text("No linked opportunity").tag(nil as UUID?)
                    ForEach(appState.workspace.opportunities) { opportunity in
                        Text(opportunity.topic).tag(Optional(opportunity.id))
                    }
                }
                .onChange(of: opportunityID) { _, newValue in
                    guard title.isEmpty,
                          let opportunity = appState.workspace.opportunities.first(where: { $0.id == newValue }) else { return }
                    title = opportunity.topic
                    concept = opportunity.notes
                }
                TextField("Title", text: $title)
                TextField("Visual concept", text: $concept, axis: .vertical)
                    .lineLimit(3...6)
                TextField("Target audience", text: $audience)
                Picker("Aspect ratio", selection: $aspectRatio) {
                    ForEach(aspectRatios, id: \.self) { Text($0).tag($0) }
                }
                Stepper("Image count: \(imageCount)", value: $imageCount, in: 1...100)
                Picker("Status", selection: $status) {
                    ForEach([BriefStatus.draft, .ready]) { Text($0.rawValue).tag($0) }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .buttonStyle(ThoockSecondaryButtonStyle())
                Button("Create brief") { save() }
                    .buttonStyle(ThoockPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || concept.isEmpty)
            }
            .padding(20)
        }
        .frame(width: 600, height: 590)
        .background(ThoockTheme.canvas)
    }

    private func save() {
        appState.addBrief(CommercialBrief(
            opportunityID: opportunityID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            concept: concept.trimmingCharacters(in: .whitespacesAndNewlines),
            audience: audience.trimmingCharacters(in: .whitespacesAndNewlines),
            aspectRatio: aspectRatio,
            imageCount: imageCount,
            status: status
        ))
        dismiss()
    }
}
