import SwiftUI

@MainActor
public final class OnboardingManager {
    public static let shared = OnboardingManager()
    
    private let tour = TourKitWindowController()
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    private init() {}

    /// Shows the onboarding tour if the user has not completed it yet.
    public func showTourIfNeeded() {
        let hasCompleted = UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
        if !hasCompleted {
            showTour()
        }
    }

    /// Forces the onboarding tour to present.
    public func showTour() {
        let pages = [
            TourPage(
                imageName: "tour-slide-1",
                title: "Welcome to Drag.on",
                description: "Your personal drop shelf. Drag any file and shake your mouse to summon the Lair — a floating shelf that holds your files right where you need them."
            ),
            TourPage(
                imageName: "tour-slide-2",
                title: "Your Lair, Your Files",
                description: "Drop files onto the Lair to stage them. Drag them out to any app — Finder, Photoshop, Slack, or anywhere else. The Lair keeps everything within reach."
            ),
            TourPage(
                imageName: "tour-slide-3",
                title: "Convert Images Instantly",
                description: "Drop images and convert them to WebP, PNG, JPEG, ICNS, ICO, or PDF in one click. Converted files land right back on the shelf, ready to go."
            ),
            TourPage(
                imageName: "tour-slide-4",
                title: "Shortcuts at Your Fingertips",
                description: "Use ⌥⌘L to toggle the Lair, ⌥⌘V to open from clipboard, and ⌥⌘P to restore your previous shelf. All customizable in Settings."
            ),
            TourPage(
                imageName: "tour-slide-5",
                title: "Make It Yours",
                description: "Adjust shake sensitivity, choose your preferred terminal, pick a theme, and configure conversion defaults. Find it all in the menu bar under Settings."
            )
        ]

        tour.present(
            pages: pages,
            width: 600,
            continueButtonTitle: "Continue",
            finishButtonTitle: "Get Started",
            onFinish: { [weak self] in
                self?.markOnboardingCompleted()
            },
            onClose: { [weak self] in
                self?.markOnboardingCompleted()
            }
        )
    }

    private func markOnboardingCompleted() {
        UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
    }
    
    /// Resets the onboarding state so the tour shows again on next launch (or for testing).
    public func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: hasCompletedOnboardingKey)
    }
}
