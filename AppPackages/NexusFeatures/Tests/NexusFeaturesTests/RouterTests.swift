import Navigation
import Testing

/// Router stack behavior.
@Suite("Router navigation stack")
@MainActor
struct RouterTests {
    private let root = Route.cardDetail(cardID: "card-root")

    @Test func `navigate to appends route`() {
        let router = Router(routes: [root])

        router.navigateTo(.cardDetail(cardID: "card-a"))

        #expect(router.routes == [root, .cardDetail(cardID: "card-a")])
    }

    @Test func `navigate back pops top destination`() {
        let router = Router(routes: [root, .cardDetail(cardID: "card-a")])

        router.navigateBack()

        #expect(router.routes == [root])
    }

    @Test func `navigate back on empty stack is no op`() {
        let router = Router()

        router.navigateBack()

        #expect(router.routes.isEmpty)
    }

    @Test func `pop to root clears every destination`() {
        let router = Router(routes: [root, .cardDetail(cardID: "card-a"), .cardDetail(cardID: "card-b")])

        router.popToRoot()

        #expect(router.routes.isEmpty)
    }

    @Test func `pop to removes destinations above route`() {
        let router = Router(routes: [root, .cardDetail(cardID: "card-a"), .cardDetail(cardID: "card-b")])

        router.popTo(root)

        #expect(router.routes == [root])
    }

    @Test func `pop to on top destination is no op`() {
        let destination = Route.cardDetail(cardID: "card-b")
        let router = Router(routes: [root, .cardDetail(cardID: "card-a"), destination])

        router.popTo(destination)

        #expect(router.routes == [root, .cardDetail(cardID: "card-a"), destination])
    }

    @Test func `pop to unknown route is no op`() {
        let router = Router(routes: [root, .cardDetail(cardID: "card-a")])

        router.popTo(.cardDetail(cardID: "card-missing"))

        #expect(router.routes == [root, .cardDetail(cardID: "card-a")])
    }
}

/// `Route` equality semantics.
@Suite("Route value semantics")
@MainActor
struct RouteTests {
    @Test func `equality follows the payload`() {
        #expect(Route.cardDetail(cardID: "card-a") == Route.cardDetail(cardID: "card-a"))
        #expect(Route.cardDetail(cardID: "card-a") != Route.cardDetail(cardID: "card-b"))
    }
}
