import SwiftUI

/// Shared view affordances (architecture.md §9.4, tasks.md Day 9).
public extension View {
    /// Makes the whole view the tap target of an action — the standard row
    /// affordance for list items that navigate or toggle.
    func onRowTap(perform action: @escaping () -> Void) -> some View {
        contentShape(Rectangle())
            .onTapGesture(perform: action)
    }

    /// Standard row/card container: continuous rounded surface over the
    /// secondary background, sized by the shared radius.
    func rowContainer() -> some View {
        background(
            RoundedRectangle(cornerRadius: Spacing.lg, style: .continuous)
                .fill(ColorPalette.secondaryBackground),
        )
    }
}
