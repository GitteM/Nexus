import Foundation
import Observation

/// Owns the navigation stack as plain state (architecture.md §8, tasks.md
/// Day 9).
///
/// The router has no knowledge of views: it holds a stack of `Route` values
/// that the app target binds to a `NavigationStack` path, and exposes the
/// push/pop actions views call. Screens reach it through
/// `@Environment(Router.self)`; detail views that must stay router-agnostic
/// take an `onNavigate: (Route) -> Void` closure instead (§8, §9.3).
///
/// Main-actor isolated like every `@Observable` model (§9.1): the stack is
/// UI state read and written from SwiftUI, so Observation access stays on
/// the main actor.
@MainActor
@Observable
public final class Router {
    /// The current navigation path, root first. Bind to a `NavigationStack`
    /// path in the app target (§11.3).
    public var routes: [Route]

    public init(routes: [Route] = []) {
        self.routes = routes
    }

    /// Pushes a destination onto the stack.
    public func navigateTo(_ route: Route) {
        routes.append(route)
    }

    /// Pops the top destination. No-op when the stack is empty (the root is
    /// not represented in `routes`, so "pop from root" is a no-op by design).
    public func navigateBack() {
        guard !routes.isEmpty else { return }
        routes.removeLast()
    }

    /// Pops every destination, returning to the root.
    public func popToRoot() {
        routes.removeAll()
    }

    /// Pops to the most recent occurrence of `route`, removing every
    /// destination pushed above it. No-op when `route` is not on the stack.
    public func popTo(_ route: Route) {
        guard let index = routes.lastIndex(of: route) else { return }
        routes.removeLast(routes.count - index - 1)
    }
}
