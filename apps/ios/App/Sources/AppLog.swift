import Foundation
import OSLog

enum LinePayLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.streamentry.linepay"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let calculation = Logger(subsystem: subsystem, category: "calculation")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let ocr = Logger(subsystem: subsystem, category: "ocr")
    static let storeKit = Logger(subsystem: subsystem, category: "storekit")
}
