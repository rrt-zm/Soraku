import SwiftUI

struct ZenView: View {
    @Environment(GameStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.palette) private var palette

    @State private var strokes: [ZenStroke] = []
    @State private var current: ZenStroke?
    @State private var activeInk: InkColorKind = .black
    @State private var sessionStart = Date()

    var body: some View {
        ZStack {
            AppBackground(palette: palette, reducedMotion: store.settings.reducedMotion, motes: false)
            VStack(spacing: Spacing.m) {
                HStack(spacing: Spacing.m) {
                    IconButton(icon: "xmark", palette: palette) { router.zenActive = false }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Free Ink").font(.display(20)).foregroundStyle(palette.textPrimary)
                        Text("Breathe and paint.").font(.body(12)).foregroundStyle(palette.textSecondary)
                    }
                    Spacer()
                    IconButton(icon: "trash", palette: palette) {
                        withAnimation(.easeOut(duration: Durations.quick)) { strokes.removeAll() }
                        store.haptics.play(.soft)
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.s)

                GeometryReader { geo in
                    let size = geo.size
                    let inset = min(size.width, size.height) * 0.04
                    ZStack {
                        PaperSheet(palette: palette)
                        Canvas { ctx, canvasSize in
                            let base = min(canvasSize.width, canvasSize.height) * 0.03
                            for stroke in strokes {
                                let pts = stroke.points.map { denorm($0, size: canvasSize, inset: inset) }
                                InkRenderer.drawStroke(&ctx, nodePoints: pts, color: palette.ink(for: stroke.color), richness: 0.9, baseWidth: base, taperEnd: true, bleed: true)
                            }
                            if let current {
                                let pts = current.points.map { denorm($0, size: canvasSize, inset: inset) }
                                InkRenderer.drawStroke(&ctx, nodePoints: pts, color: palette.ink(for: current.color), richness: 0.8, baseWidth: base, taperEnd: false, bleed: true)
                            }
                        }
                        .padding(2)
                    }
                    .frame(width: size.width, height: size.height)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let p = norm(value.location, size: size, inset: inset)
                                if current == nil {
                                    current = ZenStroke(color: activeInk, points: [p])
                                    store.audio.playBrush()
                                } else {
                                    if let last = current?.points.last, hypot(last.x - p.x, last.y - p.y) > 0.004 {
                                        current?.points.append(p)
                                    }
                                }
                            }
                            .onEnded { _ in
                                if let c = current, c.points.count > 1 { strokes.append(c) }
                                current = nil
                            }
                    )
                }
                .padding(.horizontal, Spacing.l)

                HStack(spacing: Spacing.m) {
                    inkDot(.black)
                    inkDot(.vermilion)
                    inkDot(.indigo)
                    Spacer()
                    Text("\(strokes.count) strokes").font(.label(13)).foregroundStyle(palette.textSecondary)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.l)
            }
        }
        .onAppear { sessionStart = Date() }
        .onDisappear { store.addZenSeconds(Int(Date().timeIntervalSince(sessionStart))) }
    }

    private func inkDot(_ kind: InkColorKind) -> some View {
        Button {
            activeInk = kind
            store.haptics.play(.selection)
        } label: {
            Circle().fill(palette.ink(for: kind)).frame(width: 30, height: 30)
                .overlay(Circle().strokeBorder(palette.accent, lineWidth: activeInk == kind ? 3 : 0))
                .overlay(Circle().strokeBorder(palette.panelEdge.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func norm(_ point: CGPoint, size: CGSize, inset: CGFloat) -> CGPoint {
        CGPoint(x: (point.x - inset) / max(1, size.width - inset * 2), y: (point.y - inset) / max(1, size.height - inset * 2))
    }
    private func denorm(_ point: CGPoint, size: CGSize, inset: CGFloat) -> CGPoint {
        CGPoint(x: inset + point.x * (size.width - inset * 2), y: inset + point.y * (size.height - inset * 2))
    }
}

struct ZenStroke: Identifiable, Hashable {
    let id = UUID()
    var color: InkColorKind
    var points: [CGPoint]
}
