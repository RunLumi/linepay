import Foundation
import Testing
import UIKit

@testable import LinePay

@MainActor
struct BrandAssetTests {
    @Test("The shared in-app logo is bundled as a square raster image")
    func logoIsBundled() throws {
        let image = try #require(
            UIImage(named: "LinePaycheckLogo", in: Bundle.main, compatibleWith: nil)
        )
        #expect(image.size.width > 0)
        #expect(image.size.width == image.size.height)
        #expect(image.renderingMode != .alwaysTemplate)
    }
}
