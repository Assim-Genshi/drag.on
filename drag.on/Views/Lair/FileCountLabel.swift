import SwiftUI

/// A label showing the count of files currently on the Lair shelf.
struct FileCountLabel: View {
    let items: [FileItem]

    var body: some View {
        HStack(spacing: 4) {
            Text(countText)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color("content-100"))
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color("content-100"))
        }
        .frame(height: 32)
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .fill(Color("Secondary-surfece").opacity(LairConstants.Lair.buttonBackgroundOpacity))
                .background(Capsule().fill(.ultraThinMaterial))
        )
        .overlay(
            Capsule()
                .stroke(Color("border-color").opacity(LairConstants.Lair.buttonBorderOpacity), lineWidth: 1.0)
        )
    }

    private var countText: String {
        let count = items.count
        if count == 1 {
            return "1 File"
        }
        let allImages = items.allSatisfy { SupportedImageExtensions.isImage(fileName: $0.fileName) }
        return allImages ? "\(count) Images" : "\(count) Files"
    }
}
