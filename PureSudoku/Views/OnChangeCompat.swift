import SwiftUI

extension View {
    /// `onChange` passing the new value. iOS 17 replaced the one-value form; iOS 16 still needs it.
    @ViewBuilder
    func onChangeOf<V: Equatable>(_ value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17, *) {
            onChange(of: value) { _, newValue in action(newValue) }
        } else {
            onChange(of: value, perform: action)
        }
    }
}
