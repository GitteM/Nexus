# ``CardDetail``

The card detail screen for one managed card. `CardDetailModel` loads the card through the card repository, subscribes to its live status channel, and runs the card controls — freeze/unfreeze, report lost or stolen, request replacement, and per-period spending limits. `CardDetailView` switches on `CardDetailViewState` and renders the card art, the control sections, and the limit rows once loaded.

## Topics

### Models

- ``CardDetailModel``

### Views

- ``CardDetailView``

### State & Accessibility

- ``CardDetailViewState``
- ``CardDetailAccessibility``
