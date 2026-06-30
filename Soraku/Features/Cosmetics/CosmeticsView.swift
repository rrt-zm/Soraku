import SwiftUI

struct CosmeticsView: View {
    @Environment(GameStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.palette) private var palette

    @State private var selectedKind: CosmeticKind = .ink
    @State private var toast: String?

    var body: some View {
        ZStack {
            AppBackground(palette: palette, reducedMotion: store.settings.reducedMotion)
            VStack(spacing: Spacing.m) {
                ScreenHeader(title: "The Studio", subtitle: "Earn with ink, not coin", palette: palette, onBack: { router.pop() }, trailing: AnyView(CurrencyPill(amount: store.currency, palette: palette)))
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)

                kindSelector
                    .padding(.horizontal, Spacing.l)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.m), GridItem(.flexible(), spacing: Spacing.m)], spacing: Spacing.m) {
                        ForEach(store.cosmetics(of: selectedKind)) { cosmetic in
                            cosmeticCard(cosmetic)
                        }
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.xxl)
                }
            }
            if let toast {
                VStack {
                    Spacer()
                    ToastView(text: toast, icon: "checkmark.seal.fill", palette: palette)
                        .padding(.bottom, Spacing.xxl)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var kindSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                ForEach(CosmeticKind.allCases, id: \.self) { kind in
                    Button {
                        withAnimation(.easeOut(duration: Durations.quick)) { selectedKind = kind }
                        store.haptics.play(.selection)
                    } label: {
                        Text(kind.title)
                            .font(.label(14))
                            .foregroundStyle(selectedKind == kind ? (palette.isDark ? Color(hex: "120F0A") : Color(hex: "F6EFDE")) : palette.textSecondary)
                            .padding(.horizontal, Spacing.m).padding(.vertical, Spacing.s)
                            .background(Capsule().fill(selectedKind == kind ? palette.accent : palette.ink.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func cosmeticCard(_ cosmetic: CosmeticDefinition) -> some View {
        let owned = store.isUnlocked(cosmetic)
        let equipped = store.isEquipped(cosmetic)
        return Button {
            act(on: cosmetic)
        } label: {
            InkPanel(palette: palette, padding: Spacing.m) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    CosmeticPreview(cosmetic: cosmetic, palette: palette)
                        .frame(height: 64)
                        .frame(maxWidth: .infinity)
                    Text(cosmetic.name).font(.title(16)).foregroundStyle(palette.textPrimary).lineLimit(1)
                    Text(cosmetic.detail).font(.body(12)).foregroundStyle(palette.textSecondary).lineLimit(2).frame(height: 32, alignment: .top)
                    statusLabel(owned: owned, equipped: equipped, cosmetic: cosmetic)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statusLabel(owned: Bool, equipped: Bool, cosmetic: CosmeticDefinition) -> some View {
        if equipped {
            Tag(text: "Equipped", palette: palette, filled: true)
        } else if owned {
            Tag(text: "Equip", palette: palette, filled: false)
        } else {
            HStack(spacing: 5) {
                Image(systemName: "drop.fill").font(.system(size: 11)).foregroundStyle(store.canAfford(cosmetic) ? palette.accent : palette.textSecondary)
                Text("\(cosmetic.cost)").font(.numeric(13)).foregroundStyle(store.canAfford(cosmetic) ? palette.textPrimary : palette.textSecondary)
            }
        }
    }

    private func act(on cosmetic: CosmeticDefinition) {
        if store.isUnlocked(cosmetic) {
            store.equip(cosmetic)
            flash("\(cosmetic.name) equipped")
        } else if store.canAfford(cosmetic) {
            if store.unlock(cosmetic) {
                store.equip(cosmetic)
                flash("\(cosmetic.name) unlocked")
            }
        } else {
            store.haptics.play(.warning)
            flash("Not enough ink yet")
        }
    }

    private func flash(_ message: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.4)) { toast = nil }
        }
    }
}

struct CosmeticPreview: View {
    let cosmetic: CosmeticDefinition
    var palette: Palette

    var body: some View {
        switch cosmetic.type {
        case .ink:
            Circle().fill(Color(hex: cosmetic.swatch ?? "0E0D0B"))
                .overlay(Circle().strokeBorder(palette.panelEdge.opacity(0.5), lineWidth: 1))
                .frame(width: 52, height: 52)
        case .brush:
            BrushPreview(width: CGFloat(cosmetic.tipWidth ?? 1), color: palette.ink)
        case .paper:
            RoundedRectangle(cornerRadius: Radius.s).fill(Color(hex: cosmetic.tone ?? "F2E9D8"))
                .overlay(PaperGrain(color: palette.paperGrain).clipShape(RoundedRectangle(cornerRadius: Radius.s)))
                .overlay(RoundedRectangle(cornerRadius: Radius.s).strokeBorder(palette.panelEdge.opacity(0.5), lineWidth: 1))
                .frame(width: 80, height: 52)
        case .theme:
            HStack(spacing: 0) {
                Color(hex: cosmetic.accent ?? "C8442E")
                palette.paper
            }
            .frame(width: 80, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: Radius.s))
            .overlay(RoundedRectangle(cornerRadius: Radius.s).strokeBorder(palette.panelEdge.opacity(0.5), lineWidth: 1))
        case .sound:
            Image(systemName: "waveform").font(.system(size: 30, weight: .light)).foregroundStyle(palette.accent)
        }
    }
}

struct BrushPreview: View {
    var width: CGFloat
    var color: Color
    var body: some View {
        Canvas { ctx, size in
            let pts = (0...20).map { i -> CGPoint in
                let t = CGFloat(i) / 20
                return CGPoint(x: size.width * (0.1 + 0.8 * t), y: size.height * (0.5 + 0.18 * sin(Double(t) * .pi)))
            }
            InkRenderer.drawStroke(&ctx, nodePoints: pts, color: color, richness: 0.9, baseWidth: 10 * width, taperEnd: true, bleed: true)
        }
        .frame(width: 80, height: 52)
    }
}
