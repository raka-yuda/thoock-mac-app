import AppKit
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum AssetPipelineError: LocalizedError {
    case unsupportedImage(String)
    case unreadableImage(String)
    case thumbnailFailed(String)
    case noExportableAssets

    var errorDescription: String? {
        switch self {
        case .unsupportedImage(let name): "\(name) is not a supported image file."
        case .unreadableImage(let name): "Thoock could not inspect \(name)."
        case .thumbnailFailed(let name): "Thoock could not create a thumbnail for \(name)."
        case .noExportableAssets: "Approve images and complete their metadata before exporting."
        }
    }
}

struct AssetImporter {
    let libraryURL: URL

    func importImages(at urls: [URL], briefID: UUID?) throws -> [AssetRecord] {
        try urls.map { try importImage(at: $0, briefID: briefID) }
    }

    private func importImage(at sourceURL: URL, briefID: UUID?) throws -> AssetRecord {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let type = CGImageSourceGetType(source) else {
            throw AssetPipelineError.unsupportedImage(sourceURL.lastPathComponent)
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw AssetPipelineError.unreadableImage(sourceURL.lastPathComponent)
        }

        let id = UUID()
        let fileExtension = preferredExtension(for: type as String, fallback: sourceURL.pathExtension)
        let relativeOriginalPath = "originals/\(id.uuidString).\(fileExtension)"
        let relativeThumbnailPath = "thumbnails/\(id.uuidString).jpg"
        let originalURL = libraryURL.appendingPathComponent(relativeOriginalPath)
        let thumbnailURL = libraryURL.appendingPathComponent(relativeThumbnailPath)

        try FileManager.default.copyItem(at: sourceURL, to: originalURL)
        do {
            try createThumbnail(from: source, at: thumbnailURL)
        } catch {
            try? FileManager.default.removeItem(at: originalURL)
            throw error
        }

        let data = try Data(contentsOf: originalURL, options: .mappedIfSafe)
        let fileSize = Int64(data.count)
        let checksum = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let suggestedTitle = sourceURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        return AssetRecord(
            id: id,
            briefID: briefID,
            originalFilename: sourceURL.lastPathComponent,
            originalRelativePath: relativeOriginalPath,
            thumbnailRelativePath: relativeThumbnailPath,
            width: width,
            height: height,
            fileSize: fileSize,
            format: fileExtension.uppercased(),
            checksum: checksum,
            metadata: AdobeMetadata(title: suggestedTitle, category: "", keywords: [])
        )
    }

    private func createThumbnail(from source: CGImageSource, at destinationURL: URL) throws {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 720
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let destination = CGImageDestinationCreateWithURL(
                destinationURL as CFURL,
                UTType.jpeg.identifier as CFString,
                1,
                nil
              ) else {
            throw AssetPipelineError.thumbnailFailed(destinationURL.lastPathComponent)
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw AssetPipelineError.thumbnailFailed(destinationURL.lastPathComponent)
        }
    }

    private func preferredExtension(for typeIdentifier: String, fallback: String) -> String {
        UTType(typeIdentifier)?.preferredFilenameExtension ?? (fallback.isEmpty ? "img" : fallback.lowercased())
    }
}

struct AdobeExporter {
    let libraryURL: URL

    func export(_ assets: [AssetRecord], to parentURL: URL) throws -> ExportResult {
        let eligibleAssets = assets.filter(\.isExportEligible)
        guard !eligibleAssets.isEmpty else { throw AssetPipelineError.noExportableAssets }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let folderURL = parentURL.appendingPathComponent("Thoock Export \(formatter.string(from: Date()))", isDirectory: true)
        let imagesURL = folderURL.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)

        var csvRows = ["Filename,Title,Keywords,Category"]
        var manifestAssets: [[String: String]] = []

        for (index, asset) in eligibleAssets.enumerated() {
            let filename = String(format: "thoock-%04d.jpg", index + 1)
            let sourceURL = libraryURL.appendingPathComponent(asset.originalRelativePath)
            let outputURL = imagesURL.appendingPathComponent(filename)
            try prepareJPEG(from: sourceURL, to: outputURL)

            csvRows.append([
                filename,
                asset.metadata.title,
                asset.metadata.keywords.joined(separator: ", "),
                asset.metadata.category
            ].map(csvEscape).joined(separator: ","))

            manifestAssets.append([
                "id": asset.id.uuidString,
                "filename": filename,
                "source": asset.originalFilename,
                "checksum": asset.checksum,
                "dimensions": "\(asset.width)x\(asset.height)"
            ])
        }

        let csv = csvRows.joined(separator: "\n") + "\n"
        try csv.write(to: folderURL.appendingPathComponent("adobe-metadata.csv"), atomically: true, encoding: .utf8)

        let manifest: [String: Any] = [
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "assetCount": eligibleAssets.count,
            "assets": manifestAssets
        ]
        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try manifestData.write(to: folderURL.appendingPathComponent("manifest.json"), options: .atomic)

        let report = """
        Thoock Compliance Report
        Generated: \(Date().formatted(date: .long, time: .standard))
        Assets: \(eligibleAssets.count)

        All exported assets were explicitly approved and had complete title, category, and keyword metadata at export time.
        Human review remains responsible for final Adobe Stock compliance.
        """
        try report.write(to: folderURL.appendingPathComponent("compliance-report.txt"), atomically: true, encoding: .utf8)

        return ExportResult(folderURL: folderURL, assetCount: eligibleAssets.count)
    }

    private func prepareJPEG(from sourceURL: URL, to destinationURL: URL) throws {
        guard let image = NSImage(contentsOf: sourceURL),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.94]) else {
            throw AssetPipelineError.unreadableImage(sourceURL.lastPathComponent)
        }
        try jpeg.write(to: destinationURL, options: .atomic)
    }

    private func csvEscape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
