import SwiftUI

/// A reusable wand icon that shows `wand.and.sparkles` on macOS 15+
/// and falls back to `wand.and.rays` on older macOS versions.
struct WandIcon: View {
    var size: CGFloat = 13
    var weight: Font.Weight = .bold

    var body: some View {
        if #available(macOS 15, *) {
            Image(systemName: "wand.and.sparkles")
                .font(.system(size: size, weight: weight))
        } else {
            Image(systemName: "wand.and.rays")
                .font(.system(size: size, weight: weight))
        }
    }
}
