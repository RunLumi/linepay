import Foundation
import PDFKit
import QuickLook
import SwiftUI
import UIKit

struct SourceEvidenceView: View {
    let url: URL
    let region: SourceRegion?
    var sourceText: String? = nil
    @State private var crop: Data?
    @State private var cropError = false
    var body: some View {
        Group {
            if let region {
                List {
                    Section("Original source, page \(region.page + 1)") {
                        if let crop, let image = UIImage(data: crop) {
                            Image(uiImage: image).resizable().scaledToFit()
                                .accessibilityLabel(
                                    "Paystub field crop. \(sourceText ?? "Read the original to confirm the value.")"
                                )
                        } else if cropError {
                            Text(
                                "This source crop could not be loaded. Open the complete original below."
                            )
                        } else {
                            ProgressView("Loading source")
                        }
                        if let sourceText {
                            Text(sourceText).font(.body.monospaced()).textSelection(.enabled)
                        }
                        NavigationLink("Open complete original") {
                            OriginalPreview(url: url).ignoresSafeArea(edges: .bottom)
                        }
                    }
                }
                .task(id: url) {
                    do { crop = try await SourceCrop.load(url: url, region: region) } catch {
                        cropError = true
                    }
                }
            } else {
                OriginalPreview(url: url).ignoresSafeArea(edges: .bottom)
            }
        }
        .navigationTitle("Paystub evidence").navigationBarTitleDisplayMode(.inline)
    }
}

private enum SourceCrop {
    static func load(url: URL, region: SourceRegion) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            guard (0..<8).contains(region.page),
                [region.x, region.y, region.width, region.height].allSatisfy({
                    $0.isFinite && (0...1).contains($0)
                })
            else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let data = try Data(contentsOf: url)
            guard data.count <= 25 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
            let image: UIImage
            if data.starts(with: Data("%PDF".utf8)) {
                guard let page = PDFDocument(data: data)?.page(at: region.page) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                image = page.thumbnail(of: CGSize(width: 1400, height: 1900), for: .mediaBox)
            } else {
                guard let loaded = UIImage(data: data) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                let format = UIGraphicsImageRendererFormat()
                format.scale = 1
                let scale = min(1, 2400 / max(loaded.size.width, loaded.size.height))
                let size = CGSize(
                    width: loaded.size.width * scale, height: loaded.size.height * scale)
                image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                    loaded.draw(in: CGRect(origin: .zero, size: size))
                }
            }
            guard let full = image.cgImage else { throw CocoaError(.fileReadCorruptFile) }
            let width = Double(full.width)
            let height = Double(full.height)
            let bounds = CGRect(
                x: max(0, region.x * width - 16),
                y: max(0, (1 - region.y - region.height) * height - 16),
                width: min(width, region.width * width + 32),
                height: min(height, region.height * height + 32)
            )
            .intersection(
                CGRect(x: 0, y: 0, width: CGFloat(full.width), height: CGFloat(full.height)))
            guard let clipped = full.cropping(to: bounds),
                let png = UIImage(cgImage: clipped).pngData()
            else { throw CocoaError(.fileReadCorruptFile) }
            return png
        }.value
    }
}

private struct OriginalPreview: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let view = QLPreviewController()
        view.dataSource = context.coordinator
        return view
    }
    func updateUIViewController(_ view: QLPreviewController, context: Context) {}
    final class Coordinator: NSObject, @MainActor QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int)
            -> QLPreviewItem
        { url as NSURL }
    }
}
