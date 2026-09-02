import Entities
import Foundation
import Testing

@Suite("SessionStatus")
struct SessionStatusTests {
    // MARK: - Cases

    @Test func `cases cover the full lifecycle`() {
        #expect(SessionStatus.allCases == [.connecting, .connected, .disconnected, .error])
    }

    // MARK: - Equality

    @Test func `equality distinguishes states`() {
        #expect(SessionStatus.connected == .connected)
        #expect(SessionStatus.connected != .disconnected)
        #expect(SessionStatus.connecting != .connected)
        #expect(SessionStatus.disconnected != .error)
    }

    // MARK: - Conveniences

    @Test func `every state has a display name and icon`() {
        for status in SessionStatus.allCases {
            #expect(!status.displayName.isEmpty)
            #expect(!status.icon.isEmpty)
        }
    }

    // MARK: - Codable

    @Test func `codable round trip preserves the state`() throws {
        let status = SessionStatus.error
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(SessionStatus.self, from: data)
        #expect(decoded == status)
    }

    @Test func `decodes from wire-style raw values`() throws {
        #expect(try decode("connected") == .connected)
        #expect(try decode("disconnected") == .disconnected)
        #expect(try decode("connecting") == .connecting)
        #expect(try decode("error") == .error)
    }

    private func decode(_ rawValue: String) throws -> SessionStatus {
        try JSONDecoder().decode(SessionStatus.self, from: Data(#""\#(rawValue)""#.utf8))
    }
}
