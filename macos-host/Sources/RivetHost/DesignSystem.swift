import AppKit
import SwiftUI

// MARK: - Palette

/// PodLens's semantic colors, mirrored 1:1 from the prototype contract
/// (design/prototype/shared.css). Everything the app paints comes from here so
/// light/dark adaptation is decided once, not in each view. Accent foreground/
/// background pairs change together in dark mode.
enum Palette {
    static let accent = dynamic(light: 0xAC4B2D, dark: 0xEBAB8A)
    static let accentDeep = dynamic(light: 0x893A23, dark: 0xF5C1A6)
    static let accentSoft = dynamic(light: 0xF6E8E1, dark: 0x3B2C25)
    static let onAccent = dynamic(light: 0xFFFFFF, dark: 0x281B14)
    /// Back-compat alias: the prototype's accent-soft token.
    static let highlight = accentSoft

    /// Window canvas. A hair warmer than the system background so cards and
    /// the player bar read as separate layers without borders everywhere.
    static let canvas = dynamic(light: 0xFAF7F2, dark: 0x1A1917)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x22211F)
    static let surfaceRaised = dynamic(light: 0xF2EEE8, dark: 0x2B2925)
    static let hairline = dynamic(light: 0xE4DED5, dark: 0x403D37)

    static let ink = dynamic(light: 0x252521, dark: 0xF1EEE8)
    static let inkSecondary = dynamic(light: 0x69675F, dark: 0xB2ADA3)
    static let inkTertiary = Color(nsColor: .tertiaryLabelColor)

    static let positive = dynamic(light: 0x276742, dark: 0x8DD1A3)
    static let warning = dynamic(light: 0xB25E14, dark: 0xE8A25C)
    static let danger = dynamic(light: 0xA52C2C, dark: 0xF4A09A)

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
                  green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                  blue: CGFloat(hex & 0xFF) / 255.0,
                  alpha: 1)
    }
}

// MARK: - Typography

/// A compact type scale. Titles are SF Pro with tight tracking; the reading
/// surface uses New York (the system serif) because long-form bilingual text
/// is the product, not a table of metadata.
enum Typeface {
    static let hero = Font.system(size: 30, weight: .bold).leading(.tight)
    static let display = Font.system(size: 24, weight: .bold).leading(.tight)
    static let title = Font.system(size: 19, weight: .semibold)
    static let headline = Font.system(size: 15, weight: .semibold)
    static let body = Font.system(size: 14)
    static let callout = Font.system(size: 13)
    static let caption = Font.system(size: 12)
    static let micro = Font.system(size: 11)

    static func reading(_ size: CGFloat = 17, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func mono(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Metrics

enum Space {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum Radius {
    static let control: CGFloat = 8
    static let card: CGFloat = 14
    static let artwork: CGFloat = 10
    static let sheet: CGFloat = 18
}

enum Motion {
    static let quick = Animation.easeOut(duration: 0.14)
    static let standard = Animation.spring(response: 0.34, dampingFraction: 0.86)
    static let gentle = Animation.spring(response: 0.5, dampingFraction: 0.9)
}

// MARK: - Surfaces

struct CardSurface: ViewModifier {
    var padding: CGFloat = Space.md
    var radius: CGFloat = Radius.card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(0.045), radius: 14, x: 0, y: 5)
    }
}

extension View {
    func cardSurface(padding: CGFloat = Space.md, radius: CGFloat = Radius.card) -> some View {
        modifier(CardSurface(padding: padding, radius: radius))
    }

    func hairlineTop() -> some View {
        overlay(alignment: .top) {
            Rectangle().fill(Palette.hairline).frame(height: 0.7)
        }
    }
}

// MARK: - Buttons

struct ProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typeface.headline)
            .foregroundStyle(Palette.onAccent)
            .padding(.horizontal, Space.md)
            .padding(.vertical, 7)
            .background(Palette.accent, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

struct QuietButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var promotes = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typeface.callout.weight(.medium))
            .foregroundStyle(promotes ? Palette.accent : Palette.ink)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, 6)
            .background(
                (promotes ? Palette.highlight : Palette.surfaceRaised),
                in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: promotes ? 0 : 0.7)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

struct RoundIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var size: CGFloat = 30

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Palette.inkSecondary)
            .frame(width: size, height: size)
            .background(
                configuration.isPressed ? Palette.hairline : Color.clear,
                in: Circle()
            )
            .contentShape(Circle())
            .opacity(isEnabled ? 1 : 0.35)
    }
}

// MARK: - Small pieces

struct CountBadge: View {
    let count: Int
    var emphasized = false

    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(Typeface.micro.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(emphasized ? Palette.onAccent : Palette.inkSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1.5)
                .background(
                    emphasized ? Palette.accent : Palette.hairline.opacity(0.75),
                    in: Capsule()
                )
                .fixedSize()
                .accessibilityLabel(String(format: L("unplayedCount"), count))
        }
    }
}

struct HoverScale: ViewModifier {
    var scale: CGFloat = 1.012
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? scale : 1)
            .shadow(color: .black.opacity(hovering ? 0.10 : 0.04),
                    radius: hovering ? 16 : 8, x: 0, y: hovering ? 7 : 3)
            .animation(Motion.quick, value: hovering)
            .onHover { hovering = $0 }
    }
}

extension View {
    func hoverLift(scale: CGFloat = 1.012) -> some View {
        modifier(HoverScale(scale: scale))
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Palette.accent.opacity(0.75))
                .padding(.bottom, Space.xxs)
            Text(title)
                .font(Typeface.title)
                .foregroundStyle(Palette.ink)
            Text(message)
                .font(Typeface.body)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 380)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(ProminentButtonStyle())
                    .padding(.top, Space.xs)
            }
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LaneTitle: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Typeface.title)
                .foregroundStyle(Palette.ink)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.plain)
                    .font(Typeface.callout)
                    .foregroundStyle(Palette.accent)
            }
        }
    }
}

/// A quiet line of metadata that never wraps into a second visual hierarchy.
struct MetaLine: View {
    let parts: [String]

    var body: some View {
        Text(parts.filter { !$0.isEmpty }.joined(separator: "  ·  "))
            .font(Typeface.callout)
            .foregroundStyle(Palette.inkSecondary)
            .lineLimit(1)
    }
}

struct StatusDot: View {
    var color: Color = Palette.accent

    var body: some View {
        Circle().fill(color).frame(width: 5, height: 5)
    }
}
