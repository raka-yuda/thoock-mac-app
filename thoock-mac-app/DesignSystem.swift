import SwiftUI

#if os(macOS)
import AppKit
#endif

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum ThoockTheme {
    static let accent = adaptive(
        light: NSColor(red: 0.04, green: 0.49, blue: 0.35, alpha: 1),
        dark: NSColor(red: 0.20, green: 0.70, blue: 0.51, alpha: 1)
    )
    static let accentDark = adaptive(
        light: NSColor(red: 0.02, green: 0.35, blue: 0.25, alpha: 1),
        dark: NSColor(red: 0.41, green: 0.86, blue: 0.66, alpha: 1)
    )
    static let accentSoft = adaptive(
        light: NSColor(red: 0.90, green: 0.96, blue: 0.93, alpha: 1),
        dark: NSColor(red: 0.08, green: 0.19, blue: 0.14, alpha: 1)
    )
    static let accentWash = adaptive(
        light: NSColor(red: 0.955, green: 0.975, blue: 0.965, alpha: 1),
        dark: NSColor(red: 0.085, green: 0.115, blue: 0.10, alpha: 1)
    )
    static let canvas = adaptive(
        light: NSColor(red: 0.955, green: 0.965, blue: 0.958, alpha: 1),
        dark: NSColor(red: 0.065, green: 0.075, blue: 0.070, alpha: 1)
    )
    static let sidebar = adaptive(
        light: NSColor(red: 0.975, green: 0.980, blue: 0.976, alpha: 1),
        dark: NSColor(red: 0.080, green: 0.090, blue: 0.085, alpha: 1)
    )
    static let surface = adaptive(
        light: NSColor(red: 0.975, green: 0.982, blue: 0.977, alpha: 1),
        dark: NSColor(red: 0.105, green: 0.116, blue: 0.110, alpha: 1)
    )
    static let surfaceRaised = adaptive(
        light: .white,
        dark: NSColor(red: 0.145, green: 0.155, blue: 0.150, alpha: 1)
    )
    static let ink = adaptive(
        light: NSColor(red: 0.055, green: 0.075, blue: 0.065, alpha: 1),
        dark: NSColor(red: 0.92, green: 0.94, blue: 0.925, alpha: 1)
    )
    static let muted = adaptive(
        light: NSColor(red: 0.36, green: 0.41, blue: 0.385, alpha: 1),
        dark: NSColor(red: 0.61, green: 0.65, blue: 0.625, alpha: 1)
    )
    static let border = adaptive(
        light: NSColor(red: 0.74, green: 0.78, blue: 0.755, alpha: 1),
        dark: NSColor(red: 0.25, green: 0.285, blue: 0.265, alpha: 1)
    )
    static let borderSoft = adaptive(
        light: NSColor(red: 0.84, green: 0.86, blue: 0.845, alpha: 1),
        dark: NSColor(red: 0.18, green: 0.205, blue: 0.19, alpha: 1)
    )
    static let primaryButton = adaptive(
        light: NSColor(red: 0.12, green: 0.17, blue: 0.145, alpha: 1),
        dark: NSColor(red: 0.10, green: 0.32, blue: 0.23, alpha: 1)
    )
    static let warning = adaptive(light: .systemOrange, dark: NSColor(red: 1, green: 0.68, blue: 0.26, alpha: 1))
    static let warningSoft = adaptive(
        light: NSColor(red: 1.00, green: 0.97, blue: 0.86, alpha: 1),
        dark: NSColor(red: 0.22, green: 0.16, blue: 0.07, alpha: 1)
    )
    static let danger = adaptive(light: .systemRed, dark: NSColor(red: 1, green: 0.38, blue: 0.36, alpha: 1))
    static let dangerSoft = adaptive(
        light: NSColor(red: 1.00, green: 0.92, blue: 0.92, alpha: 1),
        dark: NSColor(red: 0.23, green: 0.09, blue: 0.09, alpha: 1)
    )

    static let panelRadius: CGFloat = 14
    static let controlRadius: CGFloat = 10

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

struct ThoockPanelModifier: ViewModifier {
    var radius: CGFloat = ThoockTheme.panelRadius
    var raised = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                ThoockTheme.surfaceRaised.opacity(raised ? 0.98 : 0.90),
                                (raised ? ThoockTheme.surfaceRaised : ThoockTheme.surface).opacity(0.97)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [ThoockTheme.surfaceRaised.opacity(0.92), ThoockTheme.border],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .inset(by: 1)
                    .stroke(Color.white.opacity(raised ? 0.50 : 0.30), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(raised ? 0.075 : 0.045), radius: raised ? 8 : 5, y: raised ? 4 : 2)
            .shadow(color: ThoockTheme.accentDark.opacity(0.025), radius: 14, y: 7)
    }
}

struct ThoockControlModifier: ViewModifier {
    var fill = ThoockTheme.surface

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .frame(minHeight: 38)
            .background {
                RoundedRectangle(cornerRadius: ThoockTheme.controlRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [fill.opacity(0.80), ThoockTheme.surfaceRaised.opacity(0.96)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: ThoockTheme.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ThoockTheme.controlRadius, style: .continuous)
                    .stroke(ThoockTheme.border, lineWidth: 1)
            }
            .overlay(alignment: .top) {
                Rectangle().fill(Color.black.opacity(0.025)).frame(height: 1).padding(.horizontal, 9)
            }
            .shadow(color: Color.white.opacity(0.75), radius: 0, y: 1)
    }
}

struct ThoockPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ThoockButtonSurface(label: configuration.label, isPressed: configuration.isPressed, kind: .primary)
    }
}

struct ThoockSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ThoockButtonSurface(label: configuration.label, isPressed: configuration.isPressed, kind: .secondary)
    }
}

struct ThoockIconButtonStyle: ButtonStyle {
    var tint = ThoockTheme.ink

    func makeBody(configuration: Configuration) -> some View {
        ThoockButtonSurface(
            label: configuration.label,
            isPressed: configuration.isPressed,
            kind: .icon,
            tint: tint
        )
    }
}

private enum ThoockButtonKind {
    case primary
    case secondary
    case icon
}

private struct ThoockButtonSurface<Label: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    let label: Label
    let isPressed: Bool
    let kind: ThoockButtonKind
    var tint = ThoockTheme.ink

    private var radius: CGFloat { kind == .icon ? 9 : ThoockTheme.controlRadius }

    private var surfaceColors: [Color] {
        switch kind {
        case .primary:
            return isHovering
                ? [ThoockTheme.accent.opacity(0.92), ThoockTheme.accentDark]
                : [ThoockTheme.accent.opacity(0.80), ThoockTheme.accentDark.opacity(0.96)]
        case .secondary, .icon:
            return isHovering
                ? [ThoockTheme.surfaceRaised, ThoockTheme.accentSoft]
                : [ThoockTheme.surfaceRaised.opacity(0.98), ThoockTheme.surface]
        }
    }

    var body: some View {
        Group {
            if kind == .icon {
                label.frame(width: 36, height: 34)
            } else {
                label
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 38)
            }
        }
        .foregroundStyle(kind == .primary ? Color.white : tint)
        .background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: surfaceColors, startPoint: .top, endPoint: .bottom))
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(kind == .primary ? ThoockTheme.accentDark.opacity(0.78) : ThoockTheme.border, lineWidth: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .inset(by: 1)
                .stroke(Color.white.opacity(kind == .primary ? 0.34 : 0.72), lineWidth: 1)
        }
        .shadow(
            color: kind == .primary
                ? ThoockTheme.accentDark.opacity(isPressed ? 0.08 : 0.24)
                : Color.black.opacity(isPressed ? 0.035 : 0.10),
            radius: isPressed ? 1 : 3,
            y: isPressed ? 1 : 2
        )
        .offset(y: isPressed ? 1 : 0)
        .opacity(isEnabled ? 1 : 0.48)
        .animation(.easeOut(duration: 0.14), value: isPressed)
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

struct ThoockIconTile: View {
    let icon: String
    var tint = ThoockTheme.accent
    var background = ThoockTheme.accentSoft
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background {
                RoundedRectangle(cornerRadius: max(8, size * 0.24), style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ThoockTheme.surfaceRaised.opacity(0.84), background],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: max(8, size * 0.24), style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: max(8, size * 0.24), style: .continuous)
                    .stroke(ThoockTheme.border, lineWidth: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: max(8, size * 0.24), style: .continuous)
                    .inset(by: 1)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.07), radius: 3, y: 2)
    }
}

struct ThoockEmptyState<Actions: View>: View {
    let icon: String
    let title: String
    let message: String
    @ViewBuilder let actions: Actions

    init(
        icon: String,
        title: String,
        message: String,
        @ViewBuilder actions: () -> Actions
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 13) {
            ThoockIconTile(icon: icon, size: 48)
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(ThoockTheme.ink)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(ThoockTheme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            actions.padding(.top, 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(36)
    }
}

extension ThoockEmptyState where Actions == EmptyView {
    init(icon: String, title: String, message: String) {
        self.init(icon: icon, title: title, message: message) { EmptyView() }
    }
}

struct PaginationBar: View {
    let totalItems: Int
    let pageSize: Int
    @Binding var currentPage: Int

    private var totalPages: Int { max(1, Int(ceil(Double(totalItems) / Double(pageSize)))) }
    private var firstItem: Int { totalItems == 0 ? 0 : (currentPage - 1) * pageSize + 1 }
    private var lastItem: Int { min(totalItems, currentPage * pageSize) }

    private var visiblePages: [Int] {
        let start = max(1, min(currentPage - 2, totalPages - 4))
        let end = min(totalPages, start + 4)
        return Array(start...max(start, end))
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("Showing \(firstItem)–\(lastItem) of \(totalItems)")
                .font(.system(size: 11))
                .foregroundStyle(ThoockTheme.muted)
                .monospacedDigit()
            Spacer()
            Button { currentPage -= 1 } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(ThoockIconButtonStyle())
            .disabled(currentPage <= 1)

            ForEach(visiblePages, id: \.self) { page in
                Button(page.formatted()) { currentPage = page }
                    .buttonStyle(ThoockPageButtonStyle(isSelected: page == currentPage))
            }

            Button { currentPage += 1 } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(ThoockIconButtonStyle())
            .disabled(currentPage >= totalPages)
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .onChange(of: totalItems) { _, _ in
            currentPage = min(max(1, currentPage), totalPages)
        }
    }
}

private struct ThoockPageButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(isSelected ? Color.white : ThoockTheme.ink)
            .frame(width: 31, height: 31)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isSelected
                                ? [ThoockTheme.accent.opacity(0.82), ThoockTheme.accentDark]
                                : [ThoockTheme.surfaceRaised, ThoockTheme.surface],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? ThoockTheme.accentDark.opacity(0.75) : ThoockTheme.border)
            }
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.02 : 0.07), radius: 2, y: 1)
            .offset(y: configuration.isPressed ? 1 : 0)
    }
}

extension Array {
    func page(_ page: Int, pageSize: Int) -> [Element] {
        guard !isEmpty else { return [] }
        let start = Swift.min(Swift.max(0, (page - 1) * pageSize), count)
        let end = Swift.min(start + pageSize, count)
        return Array(self[start..<end])
    }
}

extension View {
    func thoockPanel(radius: CGFloat = ThoockTheme.panelRadius, raised: Bool = false) -> some View {
        modifier(ThoockPanelModifier(radius: radius, raised: raised))
    }

    func thoockControl(fill: Color = ThoockTheme.surface) -> some View {
        modifier(ThoockControlModifier(fill: fill))
    }
}
