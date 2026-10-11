import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case opportunities
    case briefs
    case generation
    case review
    case metadata
    case exports
    case providerLogs
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .opportunities: "Opportunities"
        case .briefs: "Commercial briefs"
        case .generation: "Image generation"
        case .review: "Review queue"
        case .metadata: "Metadata"
        case .exports: "Adobe exports"
        case .providerLogs: "Provider logs"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .opportunities: "magnifyingglass"
        case .briefs: "book.closed"
        case .generation: "wand.and.stars"
        case .review: "checkmark.rectangle.stack"
        case .metadata: "tag"
        case .exports: "square.and.arrow.down"
        case .providerLogs: "doc.text.magnifyingglass"
        case .settings: "slider.horizontal.3"
        }
    }
}

enum ProviderKind: String, CaseIterable, Codable, Hashable, Identifiable {
    case research
    case briefAndMetadata
    case image
    case upscaler
    case logoRemoval

    var id: String { rawValue }

    var title: String {
        switch self {
        case .research: "Research"
        case .briefAndMetadata: "Brief & Metadata"
        case .image: "Image Generation"
        case .upscaler: "Upscaler"
        case .logoRemoval: "Logo Removal"
        }
    }
}

struct ProviderConfig: Identifiable, Codable, Hashable {
    var id = UUID()
    var providerName = ""
    var baseURL: String?
    var organization: String?
    var isEnabled = true
    var defaultModel: String?
    var lastVerified: Date?
}

struct ProviderSetup: Hashable {
    var configuration = ProviderConfig()
    var apiKey = ""

    var isConfigured: Bool {
        !configuration.providerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum OpportunityKind: String, CaseIterable, Codable, Identifiable {
    case evergreen = "Evergreen"
    case seasonal = "Seasonal"
    case trending = "Trending"

    var id: String { rawValue }
}

enum SupplyEstimate: String, CaseIterable, Codable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }
}

enum OpportunityStatus: String, CaseIterable, Codable, Identifiable {
    case reviewing = "Reviewing"
    case readyForBrief = "Ready for brief"
    case briefed = "Briefed"

    var id: String { rawValue }
}

struct Opportunity: Identifiable, Codable, Hashable {
    var id = UUID()
    var topic: String
    var region: String
    var kind: OpportunityKind
    var supply: SupplyEstimate
    var score: Int
    var notes: String
    var status: OpportunityStatus
    var createdAt = Date()
}

enum BriefStatus: String, CaseIterable, Codable, Identifiable {
    case draft = "Draft"
    case ready = "Ready"
    case generating = "Generating"
    case completed = "Completed"

    var id: String { rawValue }
}

enum AssetReviewStatus: String, CaseIterable, Codable, Identifiable {
    case awaitingReview = "Awaiting review"
    case approved = "Approved"
    case rejected = "Rejected"

    var id: String { rawValue }
}

struct AdobeMetadata: Codable, Hashable {
    var title = ""
    var category = ""
    var keywords: [String] = []

    var isComplete: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !keywords.isEmpty
    }
}

struct AssetRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var briefID: UUID?
    var originalFilename: String
    var originalRelativePath: String
    var thumbnailRelativePath: String
    var width: Int
    var height: Int
    var fileSize: Int64
    var format: String
    var checksum: String
    var reviewStatus = AssetReviewStatus.awaitingReview
    var metadata = AdobeMetadata()
    var createdAt = Date()

    var megapixels: Double {
        Double(width * height) / 1_000_000
    }

    var isExportEligible: Bool {
        reviewStatus == .approved && metadata.isComplete
    }
}

struct CommercialBrief: Identifiable, Codable, Hashable {
    var id = UUID()
    var opportunityID: UUID?
    var title: String
    var concept: String
    var audience: String
    var aspectRatio: String
    var imageCount: Int
    var status: BriefStatus
    var createdAt = Date()
}

struct WorkspaceData: Codable {
    var opportunities: [Opportunity] = []
    var briefs: [CommercialBrief] = []
    var assets: [AssetRecord] = []
    var schemaVersion = 1

    private enum CodingKeys: String, CodingKey {
        case opportunities, briefs, assets, schemaVersion
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        opportunities = try container.decodeIfPresent([Opportunity].self, forKey: .opportunities) ?? []
        briefs = try container.decodeIfPresent([CommercialBrief].self, forKey: .briefs) ?? []
        assets = try container.decodeIfPresent([AssetRecord].self, forKey: .assets) ?? []
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    }
}

struct ExportResult {
    let folderURL: URL
    let assetCount: Int
}

struct AppError: Identifiable {
    let id = UUID()
    let message: String
}
