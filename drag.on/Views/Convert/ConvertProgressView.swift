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
    
    @State private var isHoveringCancel = false

    private var primaryTextColor: Color {
        Color("content-100")
    }

    private var secondaryTextColor: Color {
        Color("content-200")
    }

    private var accentColor: Color { mainAccent }

    private var cardBackground: Color {
        Color("Secondary-surfece")
    }

    @AppAccent(.main) private var mainAccent

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
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(primaryTextColor.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().fill(Color.secondarySurfece)
                    )
                    .overlay(
                        Capsule().stroke(Color.border.opacity(0.8), lineWidth: 1.0)
                    )
                    .scaleEffect(isHoveringCancel ? 1.03 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.easeOut(duration: 0.15)) { isHoveringCancel = h }
            }
            .pointerCursor()
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}
