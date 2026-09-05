import SwiftUI
import UIKit
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    let onScan: (Data) -> Void
    let onCancel: () -> Void
    let onError: (Error) -> Void

    static var isSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(
        _ uiViewController: VNDocumentCameraViewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: DocumentScannerView

        init(parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.onError(error)
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            parent.onScan(Self.pdfData(from: scan))
        }

        private static func pdfData(from scan: VNDocumentCameraScan) -> Data {
            let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
            let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

            return renderer.pdfData { context in
                for index in 0..<scan.pageCount {
                    context.beginPage()
                    let image = scan.imageOfPage(at: index)
                    let target = aspectFitRect(for: image.size, inside: pageBounds.insetBy(dx: 24, dy: 24))
                    image.draw(in: target)
                }
            }
        }

        private static func aspectFitRect(for size: CGSize, inside bounds: CGRect) -> CGRect {
            guard size.width > 0, size.height > 0 else { return bounds }
            let scale = min(bounds.width / size.width, bounds.height / size.height)
            let fittedSize = CGSize(width: size.width * scale, height: size.height * scale)
            return CGRect(
                x: bounds.midX - fittedSize.width / 2,
                y: bounds.midY - fittedSize.height / 2,
                width: fittedSize.width,
                height: fittedSize.height
            )
        }
    }
}
