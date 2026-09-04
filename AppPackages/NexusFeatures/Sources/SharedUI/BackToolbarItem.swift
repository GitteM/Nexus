import Design
import SwiftUI

/// Consistent back button for pushed screens.
///
/// Consumers hide the system back button
/// (`.navigationBarBackButtonHidden(true)`) and place this in
/// `.topBarLeading`; the action typically calls
/// `router.navigateBack()`.
public struct BackToolbarItem: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: Icons.back)
                .font(.body.weight(.semibold))
        }
        .accessibilityLabel(Strings.Navigation.back)
    }
}

#Preview("In toolbar") {
    NavigationStack {
        Text("Card detail")
            .navigationTitle("Card")
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BackToolbarItem {}
                }
            }
    }
}
