//
//  GhostCardView.swift
//  drag.on
//
//  Created by assim on 2026-5-30.
//

import SwiftUI

// MARK: - Ghost Card View

struct GhostCardView: View {
    let url: URL
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            AsyncThumbnailView(url: url, size: CGSize(width: 108, height: 108))
                .aspectRatio(contentMode: .fit)
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.15), radius: 1.5, y: 1)
            Text(url.lastPathComponent)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.85) : Color.black.opacity(0.65))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 72)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.06), lineWidth: 0.5))
    }
}
