# ``Dashboard``

The dashboard screen: a user's managed cards and the offers they can turn into cards. `DashboardModel` orchestrates the card, offers, and card-status repositories, publishes an explicit `DashboardViewState`, and owns the per-card live status subscriptions; `DashboardView` is a thin switch over that state and renders the swipeable card carousel and the offers row once loaded.

## Topics

### Models

- ``DashboardModel``

### Views

- ``DashboardView``

### State & Accessibility

- ``DashboardViewState``
- ``DashboardAccessibility``
