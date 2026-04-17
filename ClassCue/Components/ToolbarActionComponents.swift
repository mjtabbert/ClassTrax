import SwiftUI

struct ToolbarMenuLabel: View {
    let title: String
    let systemImage: String
    var expanded: Bool = true

    var body: some View {
        if expanded {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.accentColor.opacity(0.10))
                )
        } else {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.10))
                    .frame(width: 32, height: 32)

                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}

struct ToolbarPrimaryActionLabel: View {
    let title: String
    let systemImage: String
    var colors: [Color] = [Color(red: 0.18, green: 0.42, blue: 0.72), Color(red: 0.23, green: 0.52, blue: 0.62)]

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: Color.black.opacity(0.14), radius: 10, y: 4)
    }
}
