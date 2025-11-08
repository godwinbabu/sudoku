import SwiftUI

struct SleepDimmingOverlay: View {
    let opacity: Double

    var body: some View {
        Color.black
            .opacity(opacity)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.2), value: opacity)
    }
}
