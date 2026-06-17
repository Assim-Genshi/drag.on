//
//  ConvertFailureView.swift
//  drag.on
//
//  Created by assim on 2026-5-30.
//

import SwiftUI

struct ConvertFailureView: View {
    let message: String
    let partialResults: [ConversionResult]
    let onDismiss: () -> Void

    @State private var isHoveringDismiss = false

    private var primaryTextColor: Color {
        Color("content-100")
    }

    private var secondaryTextColor: Color {
        Color("content-200")
    }

    private var accentColor: Color { mainAccent }

    @AppAccent(.main) private var mainAccent

    private var cardBackground: Color {
        Color("Secondary-surfece")
    }

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color(red: 0.95, green: 0.4, blue: 0.1))
            Text("Conversion Failed")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(primaryTextColor)
            Text(message)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .padding(.horizontal, 24)

            if !partialResults.isEmpty {
                Text("\(partialResults.count) file\(partialResults.count == 1 ? "" : "s") succeeded")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accentColor)
            }

            Spacer()
            Button(action: onDismiss) {
                Text("Dismiss")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(secondaryTextColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(cardBackground))
                    .scaleEffect(isHoveringDismiss ? 1.03 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.easeOut(duration: 0.15)) { isHoveringDismiss = h }
            }
            .pointerCursor()
            .padding(.bottom, 16)
        }
    }
}
