import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fatalError("Smoke test failed: \(message)")
    }
}

private func createTestPNG(at url: URL) throws {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: 96,
        height: 64,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Could not create test bitmap context")
    }
    context.setFillColor(CGColor(red: 0.05, green: 0.55, blue: 0.37, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 96, height: 64))
    context.setFillColor(CGColor(gray: 1, alpha: 0.8))
    context.fillEllipse(in: CGRect(x: 28, y: 12, width: 40, height: 40))

    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
          ) else {
        fatalError("Could not create test PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    require(CGImageDestinationFinalize(destination), "test PNG was not written")
}

let fileManager = FileManager.default
let root = fileManager.temporaryDirectory.appendingPathComponent("thoock-smoke-\(UUID().uuidString)", isDirectory: true)
defer { try? fileManager.removeItem(at: root) }

try LibraryLayout.prepare(at: root)
for directory in LibraryLayout.managedDirectories {
    require(fileManager.fileExists(atPath: root.appendingPathComponent(directory).path), "missing managed directory \(directory)")
}

let inputURL = root.appendingPathComponent("test-source.png")
try createTestPNG(at: inputURL)

let imported = try AssetImporter(libraryURL: root).importImages(at: [inputURL], briefID: nil)
require(imported.count == 1, "expected one imported asset")
var asset = imported[0]
require(asset.width == 96 && asset.height == 64, "image dimensions were not inspected")
require(asset.checksum.count == 64, "SHA-256 checksum is malformed")
require(fileManager.fileExists(atPath: root.appendingPathComponent(asset.originalRelativePath).path), "original was not copied")
require(fileManager.fileExists(atPath: root.appendingPathComponent(asset.thumbnailRelativePath).path), "thumbnail was not created")

asset.reviewStatus = .approved
asset.metadata = AdobeMetadata(
    title: "Green abstract circle",
    category: "Graphic Resources",
    keywords: ["green", "abstract", "circle"]
)

var workspace = WorkspaceData()
workspace.assets = [asset]
let repository = WorkspaceRepository(libraryURL: root)
try repository.save(workspace)
let reloaded = try repository.load()
require(reloaded.assets.count == 1, "workspace asset count did not survive JSON round-trip")
require(reloaded.assets[0].id == asset.id, "workspace asset identity did not survive JSON round-trip")
require(reloaded.assets[0].metadata == asset.metadata, "workspace metadata did not survive JSON round-trip")
require(reloaded.assets[0].reviewStatus == .approved, "workspace review state did not survive JSON round-trip")

let exportParent = root.appendingPathComponent("exports-test", isDirectory: true)
try fileManager.createDirectory(at: exportParent, withIntermediateDirectories: true)
let result = try AdobeExporter(libraryURL: root).export(reloaded.assets, to: exportParent)
require(result.assetCount == 1, "export count is incorrect")
require(fileManager.fileExists(atPath: result.folderURL.appendingPathComponent("images/thoock-0001.jpg").path), "prepared JPEG is missing")
require(fileManager.fileExists(atPath: result.folderURL.appendingPathComponent("adobe-metadata.csv").path), "Adobe CSV is missing")
require(fileManager.fileExists(atPath: result.folderURL.appendingPathComponent("manifest.json").path), "manifest is missing")
require(fileManager.fileExists(atPath: result.folderURL.appendingPathComponent("compliance-report.txt").path), "compliance report is missing")

let credential = "test-provider-credential-redaction"
let unsafeLog = ProviderLogEntry(
    providerKind: .image,
    providerName: "Smoke Provider",
    model: "image-model",
    operation: "Image generation",
    requestIdentifier: "request-123",
    status: .succeeded,
    requestSummary: "Authorization: Bearer \(credential) {\"api_key\":\"another-secret\"}",
    responseSummary: "https://example.invalid/result?token=response-secret"
)
let logRepository = ProviderLogRepository(libraryURL: root)
let storedLog = try logRepository.append(unsafeLog, secrets: [credential])
require(storedLog.requestSummary?.contains(credential) == false, "known provider credential was not redacted")
require(storedLog.requestSummary?.contains("another-secret") == false, "JSON API key was not redacted")
require(storedLog.responseSummary?.contains("response-secret") == false, "URL token was not redacted")
let reloadedLogs = try logRepository.load()
require(reloadedLogs.count == 1, "provider log did not survive JSON round-trip")
let persistedLogText = try String(
    contentsOf: root.appendingPathComponent("logs/provider-requests.json"),
    encoding: .utf8
)
require(!persistedLogText.contains(credential), "provider credential reached the on-disk log")
require(!persistedLogText.contains("another-secret"), "JSON API key reached the on-disk log")
require(!persistedLogText.contains("response-secret"), "URL token reached the on-disk log")

let logExportURL = root.appendingPathComponent("provider-logs.csv")
try logRepository.exportCSV(reloadedLogs, to: logExportURL)
require(fileManager.fileExists(atPath: logExportURL.path), "provider log CSV is missing")

let demo = try DemoDataFactory.make(libraryURL: root)
require(demo.workspace.opportunities.count == 30, "demo opportunities are incomplete")
require(demo.workspace.briefs.count == 26, "demo briefs are incomplete")
require(demo.workspace.assets.count == 24, "demo assets are incomplete")
require(demo.providerLogs.count == 37, "demo provider logs are incomplete")
guard let firstDemoAsset = demo.workspace.assets.first else {
    fatalError("Smoke test failed: demo asset is missing")
}
require(
    fileManager.fileExists(atPath: root.appendingPathComponent(firstDemoAsset.thumbnailRelativePath).path),
    "demo thumbnail was not written"
)

print("Thoock smoke test passed: import → persistence → export → redacted logs → demo workspace")
