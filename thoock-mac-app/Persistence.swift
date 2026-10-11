import Foundation

struct AppPreferences: Codable {
    var libraryBookmark: Data
    var providerConfigs: [ProviderKind: ProviderConfig]
    var workspaceName: String
}

enum PreferencesError: LocalizedError {
    case notConfigured
    case unreadable

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Thoock has not been configured yet."
        case .unreadable: "Thoock could not read the saved workspace settings."
        }
    }
}

struct PreferencesStore {
    private let key = "thoock.app-preferences.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> AppPreferences {
        guard let data = defaults.data(forKey: key) else {
            throw PreferencesError.notConfigured
        }
        guard let preferences = try? JSONDecoder().decode(AppPreferences.self, from: data) else {
            throw PreferencesError.unreadable
        }
        return preferences
    }

    func save(_ preferences: AppPreferences) throws {
        let data = try JSONEncoder().encode(preferences)
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

enum LibraryLayout {
    static let managedDirectories = [
        "config",
        "originals",
        "current",
        "thumbnails",
        "prepared",
        "exports",
        "logs"
    ]

    static func prepare(at root: URL) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            throw CocoaError(.fileWriteFileExists)
        }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        for directory in managedDirectories {
            try fileManager.createDirectory(
                at: root.appendingPathComponent(directory, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
    }
}

struct WorkspaceRepository {
    private let fileURL: URL

    init(libraryURL: URL) {
        fileURL = libraryURL
            .appendingPathComponent("config", isDirectory: true)
            .appendingPathComponent("workspace.json", isDirectory: false)
    }

    func load() throws -> WorkspaceData {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let empty = WorkspaceData()
            try save(empty)
            return empty
        }
        let data = try Data(contentsOf: fileURL)
        return try Self.decoder.decode(WorkspaceData.self, from: data)
    }

    func save(_ workspace: WorkspaceData) throws {
        let data = try Self.encoder.encode(workspace)
        try data.write(to: fileURL, options: [.atomic])
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
