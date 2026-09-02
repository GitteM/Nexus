import Entities
import Foundation
import ServiceProtocols
import Testing

@Suite("JSONDecoder AppError extension")
struct JSONDecoderAppErrorExtensionTests {
    private let decoder = JSONDecoder()

    /// Runs one decode and returns the `AppError` it threw; records an issue
    /// when the decode does not throw an `AppError`.
    private func thrownError(
        _ data: Data,
        logger: RecordingLogger = RecordingLogger(),
    ) -> AppError? {
        do {
            _ = try decoder.decode(CardState.self, from: data, logger: logger, context: "test payload")
            Issue.record("decode should have thrown an AppError")
            return nil
        } catch let error as AppError {
            return error
        } catch {
            Issue.record("decode threw \(error), not an AppError")
            return nil
        }
    }

    @Test func `valid payloads decode and return the value`() throws {
        let logger = RecordingLogger()
        let data = try JSONEncoder().encode(CardState(cardId: "card-credit-001", status: .active))
        let state = try decoder.decode(CardState.self, from: data, logger: logger, context: "test payload")
        #expect(state == .mockActiveState)
        #expect(logger.records.isEmpty)
    }

    @Test func `data corruption maps to deserializationError`() {
        let logger = RecordingLogger()
        let error = thrownError(Data("not json at all".utf8), logger: logger)
        guard case let .deserializationError(type, details)? = error else {
            Issue.record("expected deserializationError, got \(String(describing: error))")
            return
        }
        #expect(type == "CardState")
        #expect(details?.contains("test payload") == true)
        #expect(error?.category == .data)
        #expect(logger.errorRecords.count == 1)
    }

    @Test func `missing key maps to deserializationError`() {
        let logger = RecordingLogger()
        let data = Data(#"{"status":"frozen"}"#.utf8)
        let error = thrownError(data, logger: logger)
        guard case let .deserializationError(type, details)? = error else {
            Issue.record("expected deserializationError, got \(String(describing: error))")
            return
        }
        #expect(type == "CardState")
        #expect(details?.contains("cardId") == true)
        #expect(logger.errorRecords.count == 1)
    }

    @Test func `type mismatch maps to deserializationError`() {
        let logger = RecordingLogger()
        let data = Data(#"{"cardId":42,"status":"frozen"}"#.utf8)
        let error = thrownError(data, logger: logger)
        guard case let .deserializationError(type, details)? = error else {
            Issue.record("expected deserializationError, got \(String(describing: error))")
            return
        }
        #expect(type == "CardState")
        #expect(details?.contains("cardId") == true)
        #expect(logger.errorRecords.count == 1)
    }

    @Test func `null for a non-optional value maps to deserializationError`() {
        let logger = RecordingLogger()
        let data = Data(#"{"cardId":null,"status":"frozen"}"#.utf8)
        let error = thrownError(data, logger: logger)
        guard case let .deserializationError(type, _)? = error else {
            Issue.record("expected deserializationError, got \(String(describing: error))")
            return
        }
        #expect(type == "CardState")
        #expect(logger.errorRecords.count == 1)
    }
}
