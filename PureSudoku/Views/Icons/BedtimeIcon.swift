import SwiftUI

struct BedtimeIcon: View {
    var color: Color = .primary

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .stroke(color, lineWidth: size * 0.1)
                Circle()
                    .fill(color)
                    .scaleEffect(0.8)
                    .offset(x: size * 0.3)
                    .blendMode(.destinationOut)
            }
            .frame(width: size, height: size)
        }
        .compositingGroup()
    }
}
