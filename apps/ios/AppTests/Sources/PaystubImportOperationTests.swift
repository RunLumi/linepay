import Foundation
import Testing

@testable import LinePay

@Suite("Paystub import ownership")
struct PaystubImportOperationTests {
    @Test func loadingLocksOutASecondImportBeforeAnyBytesAreSaved() throws {
        var operation = PaystubImportOperation()
        let tokenResult = operation.begin()
        let token = try #require(tokenResult)
        #expect(operation.isProcessing)
        #expect(operation.phase == .loading)
        #expect(operation.message.contains("Not saved yet"))
        let concurrent = operation.begin()
        #expect(concurrent == nil)
        operation.didSaveOriginal(token)
        #expect(operation.phase == .readingSavedOriginal)
        #expect(operation.message.contains("Original saved"))
        operation.finish(token)
        #expect(operation.phase == .idle)
    }

    @Test func cancelledReadCannotClaimOrFinishANewerImport() throws {
        var operation = PaystubImportOperation()
        let oldResult = operation.begin()
        let old = try #require(oldResult)
        operation.cancel()
        let currentResult = operation.begin()
        let current = try #require(currentResult)
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
