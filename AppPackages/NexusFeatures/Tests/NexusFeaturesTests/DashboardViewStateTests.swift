import Dashboard
import Entities
import Testing

/// `DashboardViewState` semantics: equality across cases/payloads and the
/// `error` projection.
@Suite("Dashboard view state")
struct DashboardViewStateTests {
    @Test func `non error states carry no error`() {
        let states: [DashboardViewState] = [.loading, .loaded, .empty]

        for state in states {
            #expect(state.error == nil)
        }
    }

    @Test func `error carries its AppError through the projection`() {
        let expected = AppError.cardNotFound(cardId: "card-1")
        let state = DashboardViewState.error(expected)

        #expect(state.error == expected)
    }

    @Test func `equality follows the case and the payload`() {
        #expect(DashboardViewState.loading == .loading)
        #expect(DashboardViewState.empty == .empty)
        #expect(DashboardViewState.loading != .empty)
        #expect(DashboardViewState.error(.cardNotFound(cardId: "card-a"))
            == .error(.cardNotFound(cardId: "card-a")))
        #expect(DashboardViewState.error(.cardNotFound(cardId: "card-a"))
            != .error(.cardNotFound(cardId: "card-b")))
        #expect(DashboardViewState.error(.cardNotFound(cardId: "card-a"))
            != .loaded)
    }
}
