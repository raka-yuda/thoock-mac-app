import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState

    private var readyOpportunities: Int {
        appState.workspace.opportunities.filter { $0.status == .readyForBrief }.count
    }

    private var readyBriefs: Int {
        appState.workspace.briefs.filter { $0.status == .ready }.count
    }

    private var awaitingReview: Int {
        appState.workspace.assets.filter { $0.reviewStatus == .awaitingReview }.count
    }

    private var exportReady: Int {
        appState.workspace.assets.filter(\.isExportEligible).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader("Creative production", subtitle: "Move research into submission-ready image packs.") {
                    HStack {
                        Button("Research topics", systemImage: "magnifyingglass") { appState.selectedSection = .opportunities }
                            .buttonStyle(ThoockSecondaryButtonStyle())
                        Button("Create brief", systemImage: "sparkles") { appState.selectedSection = .briefs }
                            .buttonStyle(ThoockPrimaryButtonStyle())
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 14)], spacing: 14) {
                    MetricCard(
                        title: "Opportunities",
                        value: appState.workspace.opportunities.count,
                        detail: "\(readyOpportunities) ready for brief",
                        icon: "magnifyingglass"
                    )
                    MetricCard(
                        title: "Briefs",
                        value: appState.workspace.briefs.count,
                        detail: "\(readyBriefs) ready to generate",
                        icon: "book.closed"
                    )
                    MetricCard(title: "Awaiting review", value: awaitingReview, detail: "Needs your decision", icon: "clock")
                    MetricCard(title: "Ready to export", value: exportReady, detail: "Adobe-ready assets", icon: "checkmark.circle")
                }

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Production pipeline").font(.system(size: 15, weight: .semibold))
                        Text("From research to Adobe-ready packages.")
                            .font(.system(size: 11)).foregroundStyle(ThoockTheme.muted)
                    }
                    HStack(spacing: 0) {
                        PipelineStage(title: "Research", value: appState.workspace.opportunities.count, icon: "magnifyingglass")
                        PipelineConnector()
                        PipelineStage(title: "Briefs", value: appState.workspace.briefs.count, icon: "book.closed")
                        PipelineConnector()
                        PipelineStage(title: "Generation", value: appState.workspace.assets.count, icon: "wand.and.stars")
                        PipelineConnector()
                        PipelineStage(title: "Export ready", value: exportReady, icon: "checkmark.circle")
                    }
                }
                .padding(22)
                .thoockPanel()

                RecentWorkView()
            }
            .padding(28)
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: Int
    let detail: String
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            ThoockIconTile(icon: icon, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 11)).foregroundStyle(ThoockTheme.muted)
                Text(value, format: .number)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .tracking(-0.6)
                    .monospacedDigit()
                Text(detail).font(.system(size: 10)).foregroundStyle(ThoockTheme.accentDark)
            }
            Spacer()
        }
        .padding(18)
        .thoockPanel(raised: true)
    }
}

private struct PipelineStage: View {
    let title: String
    let value: Int
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(ThoockTheme.accentDark)
                .frame(width: 42, height: 42)
                .background(ThoockTheme.accentSoft, in: Circle())
                .overlay { Circle().stroke(ThoockTheme.border) }
            Text(title).font(.system(size: 12, weight: .semibold))
            Text(value, format: .number).font(.system(size: 20, weight: .bold, design: .rounded)).monospacedDigit()
        }
        .frame(minWidth: 110)
    }
}

private struct PipelineConnector: View {
    var body: some View {
        Capsule()
            .fill(LinearGradient(colors: [ThoockTheme.accent, ThoockTheme.accent.opacity(0.42)], startPoint: .leading, endPoint: .trailing))
            .frame(maxWidth: .infinity, minHeight: 4, maxHeight: 4)
            .padding(.horizontal, 8)
            .offset(y: -22)
    }
}

private struct RecentWorkView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent work").font(.system(size: 15, weight: .semibold))
            if appState.workspace.opportunities.isEmpty && appState.workspace.briefs.isEmpty {
                ThoockEmptyState(
                    icon: "lightbulb",
                    title: "Start with an opportunity",
                    message: "Save a commercial topic, score it, and turn it into a production brief."
                ) {
                    Button("Load demo workspace", systemImage: "sparkles") {
                        appState.installDemoData()
                    }
                    .buttonStyle(ThoockPrimaryButtonStyle())
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                ForEach(appState.workspace.opportunities.prefix(5)) { opportunity in
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(ThoockTheme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(opportunity.topic).fontWeight(.medium).lineLimit(1)
                            Text("\(opportunity.kind.rawValue) · \(opportunity.status.rawValue)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(opportunity.score, format: .number)
                            .font(.headline.monospacedDigit())
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .padding(22)
        .thoockPanel()
    }
}
