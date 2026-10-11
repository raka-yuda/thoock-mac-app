import Foundation

enum ProviderRequestStatus: String, CaseIterable, Codable, Identifiable {
    case pending = "Pending"
    case succeeded = "Succeeded"
    case failed = "Failed"

    var id: String { rawValue }
}

struct ProviderLogEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var startedAt = Date()
    var completedAt: Date?
    var providerKind: ProviderKind
    var providerName: String
    var model: String?
    var operation: String
    var requestIdentifier: String?
    var status: ProviderRequestStatus
    var requestSummary: String?
    var responseSummary: String?
    var errorMessage: String?

    var duration: TimeInterval? {
        completedAt.map { max(0, $0.timeIntervalSince(startedAt)) }
    }
}

struct ProviderLogRepository {
    private let fileURL: URL

    init(libraryURL: URL) {
        fileURL = libraryURL
            .appendingPathComponent("logs", isDirectory: true)
            .appendingPathComponent("provider-requests.json", isDirectory: false)
    }

    func load() throws -> [ProviderLogEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try Self.decoder.decode([ProviderLogEntry].self, from: data)
            .sorted { $0.startedAt > $1.startedAt }
    }

    @discardableResult
    func append(_ entry: ProviderLogEntry, secrets: [String] = []) throws -> ProviderLogEntry {
        let safeEntry = ProviderLogSanitizer.redact(entry, secrets: secrets)
        var entries = try load()
        entries.insert(safeEntry, at: 0)
        try save(entries)
        return safeEntry
    }

    func save(_ entries: [ProviderLogEntry]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try Self.encoder.encode(entries)
        try data.write(to: fileURL, options: .atomic)
    }

    func exportCSV(_ entries: [ProviderLogEntry], to destinationURL: URL) throws {
        let rows = entries.map { entry in
            [
                ISO8601DateFormatter().string(from: entry.startedAt),
                entry.providerKind.title,
                entry.providerName,
                entry.model ?? "",
                entry.operation,
                entry.requestIdentifier ?? "",
                entry.status.rawValue,
                entry.duration.map { String(format: "%.3f", $0) } ?? "",
                entry.errorMessage ?? ""
            ].map(Self.csvEscape).joined(separator: ",")
        }
        let header = "Started,Provider type,Provider,Model,Operation,Request ID,Status,Duration seconds,Error"
        try ([header] + rows).joined(separator: "\n").appending("\n")
            .write(to: destinationURL, atomically: true, encoding: .utf8)
    }

    nonisolated private static func csvEscape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

enum ProviderLogSanitizer {
    private static let patterns: [(String, String)] = [
        (#"(?i)(authorization\s*[:=]\s*(?:bearer\s+)?)[^\s\",}]+"#, "$1[REDACTED]"),
        (#"(?i)(\"(?:api[_-]?key|token|access[_-]?token|secret|password)\"\s*:\s*\")[^\"]*(\")"#, "$1[REDACTED]$2"),
        (#"(?i)([?&](?:api[_-]?key|token|access[_-]?token|secret|password)=)[^&\s]+"#, "$1[REDACTED]")
    ]

    static func redact(_ entry: ProviderLogEntry, secrets: [String]) -> ProviderLogEntry {
        var entry = entry
        entry.providerName = redact(entry.providerName, secrets: secrets)
        entry.model = entry.model.map { redact($0, secrets: secrets) }
        entry.operation = redact(entry.operation, secrets: secrets)
        entry.requestIdentifier = entry.requestIdentifier.map { redact($0, secrets: secrets) }
        entry.requestSummary = entry.requestSummary.map { redact($0, secrets: secrets) }
        entry.responseSummary = entry.responseSummary.map { redact($0, secrets: secrets) }
        entry.errorMessage = entry.errorMessage.map { redact($0, secrets: secrets) }
        return entry
    }

    static func redact(_ text: String, secrets: [String] = []) -> String {
        var redacted = text
        for secret in secrets where !secret.isEmpty {
            redacted = redacted.replacingOccurrences(of: secret, with: "[REDACTED]")
        }
        for (pattern, replacement) in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(redacted.startIndex..., in: redacted)
            redacted = expression.stringByReplacingMatches(
                in: redacted,
                range: range,
                withTemplate: replacement
            )
        }
        return redacted
    }
}
