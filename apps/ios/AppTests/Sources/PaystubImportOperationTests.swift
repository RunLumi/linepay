import Foundation
import Testing

@testable import LinePay

@Suite("Paystub import ownership")
struct PaystubImportOperationTests {
    @Test func loadingLocksOutASecondImportBeforeAnyBytesAreSaved() throws {
        var operation = PaystubImportOperation()
        let token = try #require(operation.begin())
        #expect(operation.isProcessing)
        #expect(operation.phase == .loading)
        #expect(operation.message.contains("Not saved yet"))
        #expect(operation.begin() == nil)
        operation.didSaveOriginal(token)
        #expect(operation.phase == .readingSavedOriginal)
        #expect(operation.message.contains("Original saved"))
        operation.finish(token)
        #expect(operation.phase == .idle)
    }

    @Test func cancelledReadCannotClaimOrFinishANewerImport() throws {
        var operation = PaystubImportOperation()
        let old = try #require(operation.begin())
        operation.cancel()
        let current = try #require(operation.begin())
        #expect(!operation.owns(old))
        operation.didSaveOriginal(old)
        #expect(operation.phase == .loading)
        operation.finish(old)
        #expect(operation.owns(current))
        #expect(operation.isProcessing)
        operation.finish(current)
        #expect(!operation.isProcessing)
    }
}
