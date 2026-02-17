import SwiftUI

// MARK: - Design Tokens

enum MCStyle {
    static let accent = Color.indigo

    // Spacing
    static let popoverPadding: CGFloat = 14
    static let sectionSpacing: CGFloat = 16
    static let itemSpacing: CGFloat = 8
    static let groupCornerRadius: CGFloat = 10
    static let groupPadding: CGFloat = 12
}

// MARK: - SectionBox

struct SectionBox<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(MCStyle.groupPadding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: MCStyle.groupCornerRadius))
    }
}

// MARK: - SectionHeader

struct SectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

// MARK: - FeatureRow

struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var isOn: Bool
    var disabled: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(disabled ? Color.gray : iconColor)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(iconColor.opacity(disabled ? 0.05 : 0.12))
                )

            Text(title)
                .font(.body)

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(disabled)
                .tint(MCStyle.accent)
        }
    }
}

// MARK: - PowerToggle

struct PowerToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .bold))
                Text(isOn ? "On" : "Off")
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isOn ? MCStyle.accent : Color.secondary.opacity(0.15))
            )
            .foregroundStyle(isOn ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PermissionBadge

struct PermissionBadge: View {
    let granted: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: granted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(granted ? .green : .orange)
            Text(granted ? "Accessibility: Granted" : "Accessibility: Required")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
