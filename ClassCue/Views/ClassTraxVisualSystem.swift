import SwiftUI

enum ClassTraxSemanticColor {
    static let primaryAction = Color(red: 0.03, green: 0.45, blue: 0.98)
    static let secondaryAction = Color(red: 0.00, green: 0.78, blue: 0.82)
    static let reviewWarning = Color(red: 1.00, green: 0.50, blue: 0.00)
    static let success = Color(red: 0.00, green: 0.76, blue: 0.30)
    static let attendance = Color(red: 0.52, green: 0.14, blue: 1.00)
    static let neutral = Color.secondary
}

struct ClassTraxCardBackground: View {
    let accent: Color
    var cornerRadius: CGFloat = 18

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.26),
                        Color(.secondarySystemBackground).opacity(0.95),
                        accent.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(accent.opacity(0.34), lineWidth: 1.15)
            )
            .shadow(color: accent.opacity(0.10), radius: 12, y: 5)
    }
}

private struct ClassTraxOverviewCardModifier: ViewModifier {
    let accent: Color

    func body(content: Content) -> some View {
        content
            .background(ClassTraxCardBackground(accent: accent, cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 0.8)
            )
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color.white.opacity(0.28), Color.white.opacity(0.02), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .allowsHitTesting(false)
            }
    }
}

private struct ClassTraxInputSurfaceModifier: ViewModifier {
    let accent: Color
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(accent.opacity(0.18), lineWidth: 1)
            )
    }
}

extension View {
    func classTraxCardChrome(accent: Color, cornerRadius: CGFloat = 18) -> some View {
        background(ClassTraxCardBackground(accent: accent, cornerRadius: cornerRadius))
    }

    // Shared top-card finish used for overview cards on non-Today screens.
    func classTraxOverviewCardChrome(accent: Color) -> some View {
        modifier(ClassTraxOverviewCardModifier(accent: accent))
    }

    // Neutral input surface used for data-entry fields that should avoid tinted fills.
    func classTraxInputSurface(accent: Color = .secondary, cornerRadius: CGFloat = 12) -> some View {
        modifier(ClassTraxInputSurfaceModifier(accent: accent, cornerRadius: cornerRadius))
    }
}
