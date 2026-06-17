//
//  ConvertSuccessView.swift
//  drag.on
//
//  Created by assim on 2026-5-30.
//

import SwiftUI
import AppKit

struct ConvertSuccessView: View {
    let results: [ConversionResult]
    let store: LairStore
    let onDismiss: () -> Void

    @State private var isHoveringReveal = false
    @State private var isHoveringClearAdd = false
    @State private var isHoveringAdd = false

    private var primaryTextColor: Color {
        Color("content-100")
    }

    private var secondaryTextColor: Color {
        Color("content-200")
    }

    private var accentColor: Color { mainAccent }

    @AppAccent(.main) private var mainAccent
    @AppAccent(.secondary) private var secondaryAccent

    private var cardBackground: Color {
        Color("Secondary-surfece")
    }

    private var cardBorder: Color {
        Color("border-color")
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Close button at top-left
            LairCircleButton(systemName: "xmark", action: {
                onDismiss()
            })
            .padding(.leading, 14)
            .padding(.top, 14)
            .pointerCursor()

            VStack(spacing: 10) {
                Spacer().frame(height: 18)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(accentColor)
                
                Text("Conversion Complete")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(primaryTextColor)
                
                Text("\(results.count) file\(results.count == 1 ? "" : "s") created")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(secondaryTextColor)
                    .padding(.bottom, 6)

                // List of converted files inside a container card
                VStack(spacing: 0) {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(results, id: \.convertedURL.absoluteString) { result in
                                GhostCardView(url: result.convertedURL)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    }
                    .scrollIndicators(.hidden)
                    
                    Divider()
                    
                    // Reveal in Finder Button Area
                    HStack {
                        Spacer()
                        Button(action: {
                            let urls = results.map(\.convertedURL)
                            NSWorkspace.shared.activateFileViewerSelecting(urls)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 11))
                                Text("Reveal in Finder")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(secondaryTextColor)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color("main-surfece").opacity(0.8))
                            .overlay(Capsule().stroke(cardBorder, lineWidth: 0.5))
                            .scaleEffect(isHoveringReveal ? 1.03 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .onHover { h in
                            withAnimation(.easeOut(duration: 0.15)) { isHoveringReveal = h }
                        }
                        .pointerCursor()
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .background(Color("main-surfece").opacity(0.2))
                }
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(cardBorder, lineWidth: 1.0)
                )
                .padding(.horizontal, 16)

                Spacer()

                // Actions stacked vertically at the bottom
                VStack(spacing: 8) {
                    Button(action: {
                        let urls = results.map(\.convertedURL)
                        store.clearAll()
                        store.addFilesAsync(urls: urls)
                        onDismiss()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.3.trianglepath")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Clear & Add")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(accentColor.opacity(0.12)))
                        .scaleEffect(isHoveringClearAdd ? 1.03 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { h in
                        withAnimation(.easeOut(duration: 0.15)) { isHoveringClearAdd = h }
                    }
                    .pointerCursor()

                    Button(action: {
                        let urls = results.map(\.convertedURL)
                        store.addFilesAsync(urls: urls)
                        onDismiss()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Add to Lair")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        secondaryAccent,
                                        mainAccent,
                                    ]),
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: Color.white.opacity(0.85), location: 0.0),
                                            .init(color: Color(red: 0.1, green: 0.45, blue: 0.8, opacity: 0.45), location: 0.5),
                                            .init(color: Color(red: 0.4, green: 0.75, blue: 0.95, opacity: 0.65), location: 1.0)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .overlay(
                            Capsule()
                                .fill(LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.0)], startPoint: .topTrailing, endPoint: .bottomLeading))
                                .blendMode(.screen)
                                .allowsHitTesting(false)
                        )
                        .shadow(color: Color(red: 0.306, green: 0.639, blue: 1.0).opacity(0.35), radius: 12, x: 0, y: 6)
                        .scaleEffect(isHoveringAdd ? 1.03 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { h in
                        withAnimation(.easeOut(duration: 0.15)) { isHoveringAdd = h }
                    }
                    .pointerCursor()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
}
