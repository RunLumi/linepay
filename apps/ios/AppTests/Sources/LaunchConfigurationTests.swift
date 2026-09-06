import Foundation
import Testing

@testable import LinePay

@Suite("Launch configuration")
struct LaunchConfigurationTests {
    @Test func nativeLaunchScreenIsDeclared() throws {
        let launch = try #require(Bundle.main.object(forInfoDictionaryKey: "UILaunchScreen"))
        #expect(launch is [String: Any], "A launch dictionary prevents legacy screen-size fallback")
    }
}
