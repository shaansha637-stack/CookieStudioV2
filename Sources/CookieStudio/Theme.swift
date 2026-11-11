import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum Theme {
    static let bgTop = Color(hex: 0x0B0B14)
    static let bgBottom = Color(hex: 0x1A0F33)
    static let amber = Color(hex: 0xFFB347)
    static let coral = Color(hex: 0xFF5E7E)
    static let violet = Color(hex: 0x8B5CF6)
    static let cyan = Color(hex: 0x22D3EE)
    static let green = Color(hex: 0x34D399)
    static let card = Color.white.opacity(0.07)
    static let stroke = Color.white.opacity(0.10)

    static let accentGradient = LinearGradient(
        colors: [amber, coral],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom], startPoint: .top, endPoint: .bottom)
            Circle().fill(Theme.violet.opacity(0.35))
                .frame(width: 320, height: 320).blur(radius: 90).offset(x: 140, y: -260)
            Circle().fill(Theme.coral.opacity(0.22))
                .frame(width: 300, height: 300).blur(radius: 90).offset(x: -150, y: 300)
        }
        .ignoresSafeArea()
    }
}

struct GlassCard: ViewModifier {
    var radius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(radius: CGFloat = 16) -> some View {
        modifier(GlassCard(radius: radius))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Theme.coral.opacity(0.4), radius: 14, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct CircleIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(Theme.accentGradient, in: Circle())
            .shadow(color: Theme.coral.opacity(0.4), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
