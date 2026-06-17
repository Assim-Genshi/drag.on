//
//  SelectorInputLabel.swift
//  drag.on
//
//  Created by assim on 2026-06-06.
//

import SwiftUI

/// A helper view to represent styled SF Symbol icons inside the SelectorInputLabel.
struct SelectorIcon: View {
    let systemImage: String
    let color: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 12))
            .foregroundStyle(color)
    }
}

/// A helper view that loads and displays the native macOS system icon preview for a given folder URL.
struct FolderIconPreviewView: View {
    let url: URL?

    var body: some View {
        let nsImage: NSImage = {
            if let url = url, FileManager.default.fileExists(atPath: url.path) {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
            return NSWorkspace.shared.icon(for: .folder)
        }()

        Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 14, height: 14)
    }
}

/// A reusable dropdown-style input label designed for premium, theme-consistent UI.
/// Supports centering the title with flexible start/end contents.
struct SelectorInputLabel<StartContent: View>: View {
    let title: String
    let showChevron: Bool
    let hasShadow: Bool
    let accentColor: Color
    let startContent: StartContent

    @Environment(\.colorScheme) private var colorScheme

    init(
        _ title: String,
        showChevron: Bool = true,
        hasShadow: Bool = false,
        accentColor: Color = Color.mainAccent,
        @ViewBuilder startContent: () -> StartContent
    ) {
        self.title = title
        self.showChevron = showChevron
        self.hasShadow = hasShadow
        self.accentColor = accentColor
        self.startContent = startContent()
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left content: start content aligned to the leading edge
            HStack {
                startContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Center content: title text mathematically centered
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color("content-100"))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 8)
            
            // Right content: optional chevron icon aligned to the trailing edge
            HStack {
                if showChevron {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(Color("content-200"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: LairConstants.Convert.inputHeight)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.thinMaterial)
        )
        .topHighlightBorder()
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color("border-color"), lineWidth: LairConstants.Convert.inputBorderWidth)
        )
        .shadow(
            color: (colorScheme == .light && hasShadow) ? Color.black.opacity(0.02) : .clear,
            radius: 2,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Convenience Initializers

extension SelectorInputLabel where StartContent == SelectorIcon {
    /// Convenience initializer when the start content is a simple SF Symbol icon.
    init(
        _ title: String,
        systemImage: String,
        showChevron: Bool = true,
        hasShadow: Bool = false,
        accentColor: Color = Color.mainAccent
    ) {
        self.title = title
        self.showChevron = showChevron
        self.hasShadow = hasShadow
        self.accentColor = accentColor
        self.startContent = SelectorIcon(systemImage: systemImage, color: accentColor)
    }
}

extension SelectorInputLabel where StartContent == EmptyView {
    /// Convenience initializer when there is no start content.
    init(
        _ title: String,
        showChevron: Bool = true,
        hasShadow: Bool = false,
        accentColor: Color = Color.mainAccent
    ) {
        self.title = title
        self.showChevron = showChevron
        self.hasShadow = hasShadow
        self.accentColor = accentColor
        self.startContent = EmptyView()
    }
}
