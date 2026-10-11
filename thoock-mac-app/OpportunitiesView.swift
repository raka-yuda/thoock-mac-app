import SwiftUI

struct OpportunitiesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var selectedStatus: OpportunityStatus?
    @State private var isAddingOpportunity = false
    @State private var currentPage = 1

    private let pageSize = 10

    private var opportunities: [Opportunity] {
        appState.workspace.opportunities
            .filter { opportunity in
                (selectedStatus == nil || opportunity.status == selectedStatus) &&
                (searchText.isEmpty || opportunity.topic.localizedCaseInsensitiveContains(searchText) ||
                    opportunity.region.localizedCaseInsensitiveContains(searchText))
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score { return lhs.createdAt > rhs.createdAt }
                return lhs.score > rhs.score
            }
    }

    private var pagedOpportunities: [Opportunity] {
        opportunities.page(currentPage, pageSize: pageSize)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScreenHeader("Opportunities", subtitle: "Research and score commercially useful image topics.") {
                Button("Add opportunity", systemImage: "plus") {
                    isAddingOpportunity = true
                }
                .buttonStyle(ThoockPrimaryButtonStyle())
            }

            summaryCards

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    TextField("Search opportunities", text: $searchText)
                        .textFieldStyle(.plain)
                        .thoockControl()
                    Picker("Status", selection: $selectedStatus) {
                        Text("All statuses").tag(nil as OpportunityStatus?)
                        ForEach(OpportunityStatus.allCases) { status in
                            Text(status.rawValue).tag(Optional(status))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                    .thoockControl()
                }
                .padding(14)

                Divider()

                if opportunities.isEmpty {
                    ThoockEmptyState(
                        icon: "magnifyingglass",
                        title: searchText.isEmpty ? "No opportunities" : "No results",
                        message: searchText.isEmpty
                            ? "Add your first commercial topic to begin the production pipeline."
                            : "Try a different search or status filter."
                    ) {
                        if searchText.isEmpty {
                            Button("Add opportunity", systemImage: "plus") { isAddingOpportunity = true }
                                .buttonStyle(ThoockPrimaryButtonStyle())
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(pagedOpportunities) { opportunity in
                            OpportunityRow(opportunity: opportunity)
                                .listRowBackground(ThoockTheme.surface)
                                .listRowSeparatorTint(ThoockTheme.borderSoft)
                                .contextMenu {
                                    Button("Mark ready for brief") {
                                        var updated = opportunity
                                        updated.status = .readyForBrief
                                        appState.updateOpportunity(updated)
                                    }
                                    Divider()
                                    Button("Delete", role: .destructive) {
                                        if let index = opportunities.firstIndex(where: { $0.id == opportunity.id }) {
                                            appState.deleteOpportunities(at: IndexSet(integer: index), from: opportunities)
                                        }
                                    }
                                }
                        }
                        .onDelete { offsets in
                            appState.deleteOpportunities(at: offsets, from: pagedOpportunities)
                        }
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                    Divider()
                    PaginationBar(totalItems: opportunities.count, pageSize: pageSize, currentPage: $currentPage)
                }
            }
            .thoockPanel()
        }
        .padding(28)
        .sheet(isPresented: $isAddingOpportunity) {
            AddOpportunityView()
                .environmentObject(appState)
        }
        .onChange(of: searchText) { _, _ in currentPage = 1 }
        .onChange(of: selectedStatus) { _, _ in currentPage = 1 }
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            SummaryMetric(title: "Total", value: appState.workspace.opportunities.count)
            SummaryMetric(title: "Reviewing", value: count(.reviewing))
            SummaryMetric(title: "Ready for brief", value: count(.readyForBrief))
            SummaryMetric(title: "Briefed", value: count(.briefed))
        }
    }

    private func count(_ status: OpportunityStatus) -> Int {
        appState.workspace.opportunities.filter { $0.status == status }.count
    }
}

struct SummaryMetric: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 11)).foregroundStyle(ThoockTheme.muted)
            Text(value, format: .number)
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .tracking(-0.4)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .thoockPanel(radius: 12, raised: true)
    }
}

private struct OpportunityRow: View {
    let opportunity: Opportunity

    var body: some View {
        HStack(spacing: 14) {
            ThoockIconTile(icon: "magnifyingglass", size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(opportunity.topic).fontWeight(.medium).lineLimit(1)
                Text(opportunity.region).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            TagLabel(opportunity.kind.rawValue, tint: .blue)
            TagLabel(opportunity.supply.rawValue, tint: opportunity.supply == .high ? .orange : .green)
            Text(opportunity.score, format: .number)
                .font(.headline.monospacedDigit())
                .foregroundStyle(ThoockTheme.accentDark)
                .frame(width: 42, alignment: .trailing)
            TagLabel(opportunity.status.rawValue, tint: .secondary)
                .frame(width: 108, alignment: .leading)
            Text(opportunity.createdAt, format: .dateTime.month(.abbreviated).day())
                .font(.caption).foregroundStyle(.secondary)
                .frame(width: 62, alignment: .trailing)
        }
        .padding(.vertical, 7)
    }
}

struct TagLabel: View {
    let text: String
    let tint: Color

    init(_ text: String, tint: Color) {
        self.text = text
        self.tint = tint
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ThoockTheme.surfaceRaised.opacity(0.78), tint.opacity(0.11)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(tint.opacity(0.2), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.045), radius: 2, y: 1)
    }
}

private struct AddOpportunityView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var topic = ""
    @State private var region = "Global"
    @State private var kind = OpportunityKind.evergreen
    @State private var supply = SupplyEstimate.low
    @State private var score = 50
    @State private var notes = ""
    @State private var status = OpportunityStatus.reviewing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add opportunity")
                .font(.system(size: 22, weight: .bold))
                .padding(24)

            Form {
                TextField("Topic", text: $topic, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Region", text: $region)
                Picker("Type", selection: $kind) {
                    ForEach(OpportunityKind.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Supply estimate", selection: $supply) {
                    ForEach(SupplyEstimate.allCases) { Text($0.rawValue).tag($0) }
                }
                LabeledContent("Score") {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(score) },
                            set: { score = Int($0) }
                        ), in: 0...100, step: 1)
                        Text(score, format: .number).monospacedDigit().frame(width: 32)
                    }
                }
                Picker("Status", selection: $status) {
                    ForEach(OpportunityStatus.allCases) { Text($0.rawValue).tag($0) }
                }
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .buttonStyle(ThoockSecondaryButtonStyle())
                Button("Add opportunity") { save() }
                    .buttonStyle(ThoockPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(20)
        }
        .frame(width: 560, height: 560)
        .background(ThoockTheme.canvas)
    }

    private func save() {
        appState.addOpportunity(Opportunity(
            topic: topic.trimmingCharacters(in: .whitespacesAndNewlines),
            region: region.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            supply: supply,
            score: score,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status
        ))
        dismiss()
    }
}
