import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

struct ProviderLogsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var status: ProviderRequestStatus?
    @State private var selectedEntry: ProviderLogEntry?
    @State private var exportedURL: URL?
    @State private var currentPage = 1

    private let pageSize = 10

    private var entries: [ProviderLogEntry] {
        appState.providerLogs.filter { entry in
            let matchesStatus = status == nil || entry.status == status
            let matchesSearch = searchText.isEmpty || [
                entry.providerName,
                entry.model ?? "",
                entry.operation,
                entry.requestIdentifier ?? ""
            ].contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesStatus && matchesSearch
        }
    }

    private var averageDuration: TimeInterval? {
        let durations = entries.compactMap(\.duration)
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / Double(durations.count)
    }

    private var pagedEntries: [ProviderLogEntry] {
        entries.page(currentPage, pageSize: pageSize)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScreenHeader("Provider logs", subtitle: "Inspect redacted provider requests, responses, timing, and recovery identifiers.") {
                Button("Export logs", systemImage: "square.and.arrow.up", action: exportLogs)
                    .buttonStyle(ThoockSecondaryButtonStyle())
                    .disabled(entries.isEmpty)
            }

            HStack(spacing: 12) {
                ProviderLogMetric(title: "Requests", value: entries.count.formatted(), icon: "eye")
                ProviderLogMetric(
                    title: "Succeeded",
                    value: entries.filter { $0.status == .succeeded }.count.formatted(),
                    icon: "checkmark.circle"
                )
                ProviderLogMetric(
                    title: "Failed",
                    value: entries.filter { $0.status == .failed }.count.formatted(),
                    icon: "exclamationmark.circle"
                )
                ProviderLogMetric(
                    title: "Avg duration",
                    value: averageDuration.map { $0.formatted(.number.precision(.fractionLength(2))) + " s" } ?? "—",
                    icon: "clock"
                )
            }

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    TextField("Search provider, model, operation, or request ID", text: $searchText)
                        .textFieldStyle(.plain)
                        .thoockControl()
                    Picker("Status", selection: $status) {
                        Text("All statuses").tag(nil as ProviderRequestStatus?)
                        ForEach(ProviderRequestStatus.allCases) { requestStatus in
                            Text(requestStatus.rawValue).tag(Optional(requestStatus))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                    .thoockControl()
                }
                .padding(14)

                Divider()

                if entries.isEmpty {
                    ThoockEmptyState(
                        icon: "doc.text.magnifyingglass",
                        title: appState.providerLogs.isEmpty ? "No provider requests yet" : "No matching requests",
                        message: appState.providerLogs.isEmpty
                            ? "Requests will appear here when a configured provider is used. Secrets are redacted before anything is written to disk."
                            : "Try a different search or status filter."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(pagedEntries) { entry in
                        Button {
                            selectedEntry = entry
                        } label: {
                            ProviderLogRow(entry: entry)
                                .contentShape(Rectangle())
                                .listRowBackground(ThoockTheme.surface)
                                .listRowSeparatorTint(ThoockTheme.borderSoft)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                    Divider()
                    PaginationBar(totalItems: entries.count, pageSize: pageSize, currentPage: $currentPage)
                }
            }
            .thoockPanel()
        }
        .padding(28)
        .sheet(item: $selectedEntry) { entry in
            ProviderLogDetailView(entry: entry)
        }
        .alert("Logs exported", isPresented: Binding(
            get: { exportedURL != nil },
            set: { if !$0 { exportedURL = nil } }
        )) {
            Button("Reveal in Finder") {
                #if os(macOS)
                if let exportedURL { NSWorkspace.shared.activateFileViewerSelecting([exportedURL]) }
                #endif
            }
            Button("Done", role: .cancel) {}
        } message: {
            Text("The filtered, redacted request log was exported as CSV.")
        }
        .onChange(of: searchText) { _, _ in currentPage = 1 }
        .onChange(of: status) { _, _ in currentPage = 1 }
    }

    private func exportLogs() {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "thoock-provider-logs.csv"
        panel.prompt = "Export"
        if panel.runModal() == .OK, let url = panel.url,
           appState.exportProviderLogs(entries, to: url) {
            exportedURL = url
        }
        #endif
    }
}

private struct ProviderLogMetric: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            ThoockIconTile(icon: icon, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 11)).foregroundStyle(ThoockTheme.muted)
                Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
            }
            Spacer()
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .thoockPanel(radius: 12, raised: true)
    }
}

private struct ProviderLogRow: View {
    let entry: ProviderLogEntry

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.startedAt, format: .dateTime.month(.abbreviated).day().hour().minute().second())
                    .font(.callout.monospacedDigit())
                Text(entry.providerKind.title).font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 170, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.providerName).fontWeight(.medium)
                Text(entry.model ?? "Default model").font(.caption).foregroundStyle(.secondary)
            }
            .frame(minWidth: 130, maxWidth: 210, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.operation).lineLimit(1)
                Text(entry.requestIdentifier ?? "No request identifier")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }

            Spacer()
            TagLabel(entry.status.rawValue, tint: statusColor(entry.status))
                .frame(width: 84, alignment: .leading)
            Text(entry.duration.map { $0.formatted(.number.precision(.fractionLength(2))) + " s" } ?? "—")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}

private struct ProviderLogDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let entry: ProviderLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.operation).font(.title2.weight(.semibold))
                    Text("\(entry.providerName) · \(entry.model ?? "Default model")")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                TagLabel(entry.status.rawValue, tint: statusColor(entry.status))
            }
            .padding(24)

            Divider()

            Form {
                LabeledContent("Started") { Text(entry.startedAt.formatted(date: .abbreviated, time: .standard)) }
                LabeledContent("Duration") {
                    Text(entry.duration.map { $0.formatted(.number.precision(.fractionLength(3))) + " seconds" } ?? "Pending")
                }
                LabeledContent("Provider type") { Text(entry.providerKind.title) }
                LabeledContent("Request ID") { Text(entry.requestIdentifier ?? "Unavailable").textSelection(.enabled) }
                if let requestSummary = entry.requestSummary {
                    ProviderLogTextBlock(title: "Redacted request", text: requestSummary)
                }
                if let responseSummary = entry.responseSummary {
                    ProviderLogTextBlock(title: "Redacted response", text: responseSummary)
                }
                if let errorMessage = entry.errorMessage {
                    ProviderLogTextBlock(title: "Error", text: errorMessage)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Label("Secrets are redacted before this log is saved.", systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
                    .buttonStyle(ThoockPrimaryButtonStyle())
            }
            .padding(20)
        }
        .frame(width: 680, height: 600)
        .background(ThoockTheme.canvas)
    }
}

private struct ProviderLogTextBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.callout.weight(.medium))
            ScrollView(.horizontal) {
                Text(text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private func statusColor(_ status: ProviderRequestStatus) -> Color {
    switch status {
    case .pending: .orange
    case .succeeded: .green
    case .failed: .red
    }
}
