import Dashboard
import Entities
import Testing

/// `DashboardViewState` semantics: equality across cases/payloads and the
/// error projections the view uses.
@Suite("Dashboard view state")
struct DashboardViewStateTests {
    @Test func `non error states carry no error surfaces`() {
        let states: [DashboardViewState] = [.loading, .loaded, .empty]

        for state in states {
            #expect(state.error == nil)
            #expect(state.errorMessage == nil)
            #expect(state.recoverySuggestion == nil)
        }
    }

    @Test func `error carries its AppError through every projection`() {
        let expected = AppError.cardNotFound(cardId: "card-1")
        let state = DashboardViewState.error(expected)

        #expect(state.error == expected)
        #expect(state.errorMessage == expected.errorDescription)
        #expect(state.recoverySuggestion == expected.recoverySuggestion)
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
