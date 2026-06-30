import SwiftUI

struct InkPanel<Content: View>: View {
    var palette: Palette
    var padding: CGFloat = Spacing.l
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                    .fill(palette.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                            .strokeBorder(palette.panelEdge.opacity(0.7), lineWidth: 1)
                    )
            )
            .shadow(color: palette.ink.opacity(palette.isDark ? 0.4 : 0.12), radius: 16, x: 0, y: 10)
    }
}

struct SorakuButton: View {
    enum Kind { case primary, secondary, ghost }
    var title: String
    var icon: String?
    var kind: Kind = .primary
    var palette: Palette
    var enabled: Bool = true
    var action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: Spacing.s) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .semibold)) }
                Text(title).font(.label(16))
            }
            .foregroundStyle(foreground)
            .padding(.vertical, 13)
            .padding(.horizontal, Spacing.l)
            .frame(maxWidth: kind == .ghost ? nil : .infinity)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Radius.pill, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .scaleEffect(pressed ? 0.96 : 1)
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeOut(duration: 0.12)) { pressed = true } }
                .onEnded { _ in withAnimation(.easeOut(duration: 0.18)) { pressed = false } }
        )
    }

    private var foreground: Color {
        switch kind {
        case .primary: return palette.isDark ? Color(hex: "120F0A") : Color(hex: "F6EFDE")
        case .secondary: return palette.textPrimary
        case .ghost: return palette.accent
        }
    }
    private var background: some View {
        Group {
            switch kind {
            case .primary: palette.accent
            case .secondary: palette.panel
            case .ghost: Color.clear
            }
        }
    }
    private var borderColor: Color {
        switch kind {
        case .primary: return palette.accent.opacity(0.4)
        case .secondary: return palette.panelEdge
        case .ghost: return palette.accent.opacity(0.35)
        }
    }
}

struct IconButton: View {
    var icon: String
    var palette: Palette
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
                .frame(width: 46, height: 46)
                .background(Circle().fill(palette.panel))
                .overlay(Circle().strokeBorder(palette.panelEdge.opacity(0.6), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct StarRow: View {
    var count: Int
    var total: Int = 3
    var size: CGFloat = 16
    var palette: Palette
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { i in
                Image(systemName: i < count ? "seal.fill" : "seal")
                    .font(.system(size: size))
                    .foregroundStyle(i < count ? palette.star : palette.textSecondary.opacity(0.4))
            }
        }
    }
}

struct CurrencyPill: View {
    var amount: Int
    var palette: Palette
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "drop.fill").font(.system(size: 12))
                .foregroundStyle(palette.accent)
            Text("\(amount)").font(.numeric(15)).foregroundStyle(palette.textPrimary)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(palette.panel))
        .overlay(Capsule().strokeBorder(palette.panelEdge.opacity(0.6), lineWidth: 1))
    }
}

struct ScreenHeader: View {
    var title: String
    var subtitle: String?
    var palette: Palette
    var onBack: (() -> Void)?
    var trailing: AnyView?

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            if let onBack {
                IconButton(icon: "chevron.left", palette: palette, action: onBack)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.display(24)).foregroundStyle(palette.textPrimary)
                if let subtitle {
                    Text(subtitle).font(.body(13)).foregroundStyle(palette.textSecondary)
                }
            }
            Spacer()
            if let trailing { trailing }
        }
    }
}

struct ProgressBead: View {
    var fraction: Double
    var palette: Palette
    var tint: Color?
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.ink.opacity(0.12))
                Capsule()
                    .fill(tint ?? palette.accent)
                    .frame(width: max(6, geo.size.width * fraction))
            }
        }
        .frame(height: 8)
    }
}

struct Tag: View {
    var text: String
    var palette: Palette
    var filled: Bool = false
    var body: some View {
        Text(text)
            .font(.label(12))
            .foregroundStyle(filled ? (palette.isDark ? Color(hex: "120F0A") : Color(hex: "F6EFDE")) : palette.textSecondary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                Capsule().fill(filled ? palette.accent : palette.ink.opacity(0.08))
            )
    }
}

struct EmptyStateView: View {
    var icon: String
    var title: String
    var message: String
    var palette: Palette
    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(palette.textSecondary.opacity(0.6))
            Text(title).font(.title(19)).foregroundStyle(palette.textPrimary)
            Text(message).font(.body(14)).foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 280)
        .padding(Spacing.xl)
    }
}

struct SorakuLoader: View {
    var palette: Palette
    @State private var phase: CGFloat = 0
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) * 0.36
                var path = Path()
                let steps = 60
                for i in 0...steps {
                    let frac = Double(i) / Double(steps)
                    let sweep = (sin(t) * 0.5 + 0.5)
                    guard frac <= sweep else { break }
                    let angle = frac * 2 * .pi - .pi / 2
                    let p = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                    if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                ctx.stroke(path, with: .color(palette.ink), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
        }
        .frame(width: 64, height: 64)
    }
}

struct ToastView: View {
    var text: String
    var icon: String
    var palette: Palette
    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: icon).foregroundStyle(palette.accent)
            Text(text).font(.label(14)).foregroundStyle(palette.textPrimary)
        }
        .padding(.horizontal, Spacing.l).padding(.vertical, Spacing.m)
        .background(Capsule().fill(palette.panel))
        .overlay(Capsule().strokeBorder(palette.panelEdge, lineWidth: 1))
        .shadow(color: palette.ink.opacity(0.2), radius: 12, y: 6)
    }
}
