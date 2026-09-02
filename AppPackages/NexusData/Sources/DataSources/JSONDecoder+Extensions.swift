import Entities
import Foundation
import ServiceProtocols

/// The `JSONDecoder` AppError extension (architecture.md §6.4).
///
/// Every decode in the Data layer goes through `decode(_:from:logger:context:)`
/// so that no `DecodingError` (and no raw `Error`) ever crosses the data
/// source boundary: each kind is logged with the operation context and
/// rethrown as `AppError.deserializationError(type:details:)`. This is the
/// mechanism behind the Day 6 verify note "every decode error is an AppError".
///
/// It lives in `DataSources` — the consumers of wire JSON — and is reused by
/// `Repositories` (REST DTO decoding, tasks.md Day 7) and the demo mocks,
/// which both depend on this target.
public extension JSONDecoder {
    /// Decodes `data` as `T`, logging failures and rethrowing them as
    /// `AppError.deserializationError`.
    ///
    /// - Parameters:
    ///   - type: The decodable type to produce.
    ///   - data: The raw wire bytes.
    ///   - logger: Receives a `.error` message with the context and reason.
    ///   - context: Human-readable description of the decode site (e.g.
    ///     "CardState from card.events payload") — must stay display-safe
    ///     (architecture.md §7.2: no full card numbers, CVV, or tokens).
    func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        logger: any LoggerProtocol,
        context: String,
    ) throws -> T {
        do {
            return try decode(type, from: data)
        } catch {
            let reason = Self.describe(error)
            logger.log(
                "Deserialization failed — \(context): \(reason)",
                level: .error,
            )
            throw AppError.deserializationError(
                type: "\(T.self)",
                details: "\(context): \(reason)",
            )
        }
    }

    /// Builds a readable reason for a decoding failure. `DecodingError` kinds
    /// map to their coding path and description; anything else (defensive
    /// fallback) keeps its own description.
    private static func describe(_ error: Error) -> String {
        switch error {
        case let DecodingError.dataCorrupted(context):
            path(context) + "Data corrupted: \(context.debugDescription)"
        case let DecodingError.keyNotFound(key, context):
            path(context) + "Key '\(key.stringValue)' not found: \(context.debugDescription)"
        case let DecodingError.typeMismatch(type, context):
            path(context) + "Type '\(type)' mismatch: \(context.debugDescription)"
        case let DecodingError.valueNotFound(type, context):
            path(context) + "Value of type '\(type)' not found: \(context.debugDescription)"
        default:
            error.localizedDescription
        }
    }

    /// Coding path of a decode failure as a readable prefix, e.g.
    /// "card.events payload → offers[1].id: " (empty for the top level).
    private static func path(_ context: DecodingError.Context) -> String {
        guard !context.codingPath.isEmpty else {
            return ""
        }
        let path = context.codingPath
            .map { $0.intValue.map { "\($0)" } ?? $0.stringValue }
            .joined(separator: ".")
        return "At '\(path)': "
    }
}
