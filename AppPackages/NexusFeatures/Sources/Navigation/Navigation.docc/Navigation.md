# ``Navigation``

Declarative navigation state for the Nexus app. `Router` owns the navigation stack as plain `Route` values that an app-side `NavigationStack` path binds to, and exposes the push/pop actions views call; `Route` is the set of Hashable destinations that carry the data each screen needs. The module has no view knowledge — the route-to-view mapping lives in the app target.

## Topics

### Navigation State

- ``Router``

### Destinations

- ``Route``
