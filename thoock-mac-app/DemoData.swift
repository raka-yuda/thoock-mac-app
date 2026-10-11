import AppKit
import Foundation

struct DemoWorkspacePayload {
    var workspace: WorkspaceData
    var providerLogs: [ProviderLogEntry]
}

enum DemoDataFactory {
    static let opportunityMarker = "[Thoock demo]"
    static let providerName = "Thoock Demo"

    private static let topics = [
        "Aurora reflected in a steaming geothermal lagoon",
        "Heat-safe outdoor work break in Southeast Asia",
        "Bioluminescent tidal coast under a calm night sky",
        "Solar eclipse shadow crossing quiet desert dunes",
        "Ramadan family meal preparation in Jakarta",
        "Low-waste refill station for neighborhood groceries",
        "Fogbow above a mirror-still alpine lake",
        "Climate-resilient rooftop garden after rainfall",
        "Accessible commuter platform during morning light",
        "Remote healthcare consultation in an island clinic",
        "Community mangrove restoration at low tide",
        "Minimal home office with warm indirect daylight",
        "Electric delivery bicycles outside a local market",
        "Young farmers inspecting hydroponic vegetables",
        "Rainwater harvesting system beside a modern home",
        "Quiet airport lounge for neurodiverse travelers",
        "Circular-fashion repair workshop with natural fabrics",
        "Senior friends learning mobile banking together",
        "Coastal warning signs before a tropical storm",
        "Urban pollinator garden between office buildings",
        "Small business packaging orders with recycled paper",
        "Forest bathing path in soft winter fog",
        "Solar technicians working on a school roof",
        "Inclusive classroom using tactile learning materials",
        "Night market vendors using reusable containers",
        "EV charging stop beside a rural coffee shop",
        "Cold-chain delivery for a neighborhood pharmacy",
        "Minimal wellness retreat beside a mountain lake",
        "Home energy dashboard during peak evening demand",
        "Volunteers preparing supplies after seasonal flooding"
    ]

    private static let regions = ["Global", "Southeast Asia", "Indonesia", "Nordic region", "Asia Pacific"]
    private static let concepts = [
        "Editorial wide shot with believable environmental detail and clear copy space.",
        "Human-centered commercial scene with natural gestures and soft directional light.",
        "Quiet premium composition built around texture, atmosphere, and usable negative space.",
        "Documentary-inspired frame with an authentic location and inclusive casting.",
        "Clean visual story suitable for sustainability, travel, or workplace campaigns."
    ]
    private static let categories = ["Lifestyle", "Travel", "Environment", "Business", "Technology"]

    static func make(libraryURL: URL, now: Date = Date()) throws -> DemoWorkspacePayload {
        var workspace = WorkspaceData()

        workspace.opportunities = topics.enumerated().map { index, topic in
            Opportunity(
                topic: topic,
                region: regions[index % regions.count],
                kind: OpportunityKind.allCases[index % OpportunityKind.allCases.count],
                supply: SupplyEstimate.allCases[(index * 2) % SupplyEstimate.allCases.count],
                score: 96 - ((index * 7) % 49),
                notes: "\(opportunityMarker) \(concepts[index % concepts.count])",
                status: OpportunityStatus.allCases[index % OpportunityStatus.allCases.count],
                createdAt: now.addingTimeInterval(-Double(index * 19_700))
            )
        }

        workspace.briefs = workspace.opportunities.prefix(26).enumerated().map { index, opportunity in
            CommercialBrief(
                opportunityID: opportunity.id,
                title: opportunity.topic,
                concept: concepts[index % concepts.count],
                audience: ["Travel publishers", "Sustainability teams", "Regional campaigns", "Editorial buyers"][index % 4],
                aspectRatio: ["4:3", "3:2", "16:9", "9:16", "1:1"][index % 5],
                imageCount: [4, 6, 8, 5][index % 4],
                status: BriefStatus.allCases[index % BriefStatus.allCases.count],
                createdAt: now.addingTimeInterval(-Double(index * 14_300))
            )
        }

        for (index, brief) in workspace.briefs.prefix(24).enumerated() {
            let id = UUID()
            let originalRelativePath = "originals/\(id.uuidString).jpg"
            let thumbnailRelativePath = "thumbnails/\(id.uuidString).jpg"
            let originalURL = libraryURL.appendingPathComponent(originalRelativePath)
            let thumbnailURL = libraryURL.appendingPathComponent(thumbnailRelativePath)
            let imageData = try makeDemoImage(index: index)
            try imageData.write(to: originalURL, options: .atomic)
            try imageData.write(to: thumbnailURL, options: .atomic)

            let reviewStatus: AssetReviewStatus = if index % 7 == 0 {
                .rejected
            } else if index % 5 == 0 {
                .awaitingReview
            } else {
                .approved
            }
            let metadataComplete = reviewStatus == .approved && index % 6 != 0
            let category = categories[index % categories.count]

            workspace.assets.append(AssetRecord(
                id: id,
                briefID: brief.id,
                originalFilename: "demo-\(String(format: "%02d", index + 1))-\(slug(brief.title)).jpg",
                originalRelativePath: originalRelativePath,
                thumbnailRelativePath: thumbnailRelativePath,
                width: 1200,
                height: 800,
                fileSize: Int64(imageData.count),
                format: "JPG",
                checksum: String(repeating: String(format: "%x", index % 16), count: 64),
                reviewStatus: reviewStatus,
                metadata: AdobeMetadata(
                    title: metadataComplete ? brief.title : "",
                    category: metadataComplete ? category : "",
                    keywords: metadataComplete
                        ? [category.lowercased(), "commercial", "authentic", regions[index % regions.count].lowercased(), "copy space"]
                        : []
                ),
                createdAt: now.addingTimeInterval(-Double(index * 8_900))
            ))
        }

        let operations = ["Topic research", "Brief generation", "Image generation", "Metadata generation", "Result recovery"]
        let providerKinds: [ProviderKind] = [.research, .briefAndMetadata, .image, .briefAndMetadata, .image]
        let logs = (0..<37).map { index in
            let startedAt = now.addingTimeInterval(-Double(index * 1_730))
            let status: ProviderRequestStatus = if index % 13 == 0 {
                .pending
            } else if index % 8 == 0 {
                .failed
            } else {
                .succeeded
            }
            return ProviderLogEntry(
                startedAt: startedAt,
                completedAt: status == .pending ? nil : startedAt.addingTimeInterval(Double(2 + (index * 7) % 19) / 2),
                providerKind: providerKinds[index % providerKinds.count],
                providerName: providerName,
                model: ["research-small", "brief-pro", "image-studio", "metadata-fast"][index % 4],
                operation: operations[index % operations.count],
                requestIdentifier: "demo_req_\(String(format: "%04d", 4100 + index))",
                status: status,
                requestSummary: "Demo request with \(2 + index % 6) normalized fields",
                responseSummary: status == .succeeded ? "Normalized response accepted" : nil,
                errorMessage: status == .failed ? "Provider returned a temporary capacity error" : nil
            )
        }

        return DemoWorkspacePayload(workspace: workspace, providerLogs: logs)
    }

    private static func slug(_ value: String) -> String {
        value.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(5)
            .joined(separator: "-")
    }

    private static func makeDemoImage(index: Int) throws -> Data {
        let size = NSSize(width: 1200, height: 800)
        let palettes: [(NSColor, NSColor, NSColor)] = [
            (.init(red: 0.72, green: 0.84, blue: 0.82, alpha: 1), .init(red: 0.19, green: 0.42, blue: 0.38, alpha: 1), .init(red: 0.94, green: 0.78, blue: 0.44, alpha: 1)),
            (.init(red: 0.76, green: 0.82, blue: 0.91, alpha: 1), .init(red: 0.26, green: 0.35, blue: 0.52, alpha: 1), .init(red: 0.90, green: 0.58, blue: 0.42, alpha: 1)),
            (.init(red: 0.88, green: 0.83, blue: 0.74, alpha: 1), .init(red: 0.40, green: 0.32, blue: 0.25, alpha: 1), .init(red: 0.62, green: 0.75, blue: 0.53, alpha: 1)),
            (.init(red: 0.68, green: 0.79, blue: 0.88, alpha: 1), .init(red: 0.21, green: 0.38, blue: 0.47, alpha: 1), .init(red: 0.93, green: 0.86, blue: 0.69, alpha: 1))
        ]
        let palette = palettes[index % palettes.count]
        let image = NSImage(size: size)
        image.lockFocus()

        NSGradient(starting: palette.0, ending: palette.1)?.draw(in: NSRect(origin: .zero, size: size), angle: -72 + CGFloat(index % 5) * 9)

        palette.2.withAlphaComponent(0.72).setFill()
        NSBezierPath(ovalIn: NSRect(x: 760 - CGFloat(index % 4) * 65, y: 470, width: 250, height: 250)).fill()

        palette.1.withAlphaComponent(0.72).setFill()
        let ridge = NSBezierPath()
        ridge.move(to: NSPoint(x: 0, y: 220))
        ridge.line(to: NSPoint(x: 250, y: 390 + CGFloat(index % 3) * 35))
        ridge.line(to: NSPoint(x: 470, y: 250))
        ridge.line(to: NSPoint(x: 730, y: 430 - CGFloat(index % 4) * 28))
        ridge.line(to: NSPoint(x: 1200, y: 190))
        ridge.line(to: NSPoint(x: 1200, y: 0))
        ridge.line(to: NSPoint(x: 0, y: 0))
        ridge.close()
        ridge.fill()

        NSColor.white.withAlphaComponent(0.20).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 165, width: 1200, height: 75)).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.86]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return jpeg
    }
}
