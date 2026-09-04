# ``Nexus``

The thin iOS application target that composes NexusDomain, NexusData, and
NexusFeatures into a running banking app. It owns the composition root
(`AppContainer`), the app-level state machine (`AppState`), and the SwiftUI
shell that renders each state.

The app runs in two modes. Live mode builds the real Data-layer graph over
the API session configured by `APIConfig`. Demo mode (`-demoMode`, DEBUG
builds only) wires the same model surfaces to in-memory mock repositories
with simulated network calls, so the full UI runs without a backend.
Models come from the feature packages and never depend on this target.

## Topics

### Composition root

- ``AppContainer``
- ``AppState``
- ``APIConfig``
