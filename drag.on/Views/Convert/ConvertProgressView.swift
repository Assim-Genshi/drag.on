//
//  ConvertProgressView.swift
//  drag.on
//
//  Created by assim on 2026-5-30.
//

import SwiftUI

struct ConvertProgressView: View {
    let progress: ConversionProgress
    let converter: ImageConverter

    private var primaryTextColor: Color {
        Color("content-100")
    }

    private var secondaryTextColor: Color {
        Color("content-200")
    }

    private var accentColor: Color {
        Color(red: 0.0, green: 0.55, blue: 1.0)
    }

    private var cardBackground: Color {
        Color("Secondary-surfece")
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Circular progress ring
            ZStack {
                Circle()
                    .stroke(accentColor.opacity(0.15), lineWidth: 4)
                    .frame(width: 52, height: 52)

                Circle()
                    .trim(from: 0, to: progress.fractionComplete)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress.fractionComplete)

                Text("\(Int(progress.fractionComplete * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
            }

            VStack(spacing: 4) {
                Text(progress.phase.rawValue)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(primaryTextColor)

                Text(progress.currentFileName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 24)

                Text("\(progress.currentIndex + 1) of \(progress.totalCount)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(secondaryTextColor.opacity(0.7))
            }

            Spacer()

            Button(action: {
                converter.cancelConversion()
            }) {
                Text("Cancel")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(secondaryTextColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(cardBackground))
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .padding(.bottom, 16)
        }
    }
}
