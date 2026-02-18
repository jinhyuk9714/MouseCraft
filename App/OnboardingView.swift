import SwiftUI

struct OnboardingView: View {
    @ObservedObject var appState: AppState
    @State private var currentStep = 0
    @Environment(\.dismiss) private var dismiss

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Content
            Group {
                switch currentStep {
                case 0: welcomeStep
                case 1: permissionStep
                case 2: featuresStep
                default: doneStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Navigation
            HStack {
                // Step indicator
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { step in
                        Circle()
                            .fill(step == currentStep ? MCStyle.accent : Color.secondary.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }

                Spacer()

                if currentStep > 0 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                    .controlSize(.regular)
                }

                if currentStep < totalSteps - 1 {
                    Button("Continue") {
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MCStyle.accent)
                    .controlSize(.regular)
                } else {
                    Button("Get Started") {
                        appState.completeOnboarding()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MCStyle.accent)
                    .controlSize(.regular)
                }
            }
            .padding(20)
        }
        .frame(width: 520, height: 420)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "computermouse.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(MCStyle.accent)

            Text("MouseCraft")
                .font(.largeTitle.weight(.bold))

            Text("Supercharge your mouse with trackpad-like gestures,\nsmooth scrolling, and button remapping.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Spacer()
        }
        .padding(32)
    }

    private var permissionStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.orange)

            Text("Accessibility Permission")
                .font(.title2.weight(.semibold))

            Text("MouseCraft needs Accessibility access to intercept and\ntransform mouse events. No data leaves your Mac.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Spacer()
                .frame(height: 8)

            PermissionBadge(granted: appState.accessibilityTrusted)

            HStack(spacing: 12) {
                Button("Request Access") {
                    appState.requestAccessibility()
                }
                .controlSize(.regular)

                Button("System Settings...") {
                    appState.openAccessibilitySettings()
                }
                .controlSize(.regular)
            }

            Spacer()
        }
        .padding(32)
    }

    private var featuresStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Features")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 16) {
                featureItem(
                    icon: "arrow.left.arrow.right",
                    color: .purple,
                    title: "Button Remap",
                    description: "Map side buttons to keyboard shortcuts like Back, Forward, Copy, or Paste."
                )

                featureItem(
                    icon: "arrow.up.and.down.circle",
                    color: .blue,
                    title: "Smooth Scroll",
                    description: "Pixel-perfect scrolling with adjustable speed, acceleration, and momentum."
                )

                featureItem(
                    icon: "hand.draw",
                    color: .green,
                    title: "Mouse Gestures",
                    description: "Hold a side button and drag to trigger Mission Control, App Exposé, or Desktop switching."
                )
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding(32)
    }

    private var doneStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.title2.weight(.semibold))

            Text("MouseCraft lives in your menu bar.\nOpen Settings anytime to customize your experience.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Spacer()
        }
        .padding(32)
    }

    // MARK: - Helpers

    private func featureItem(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
    }
}
