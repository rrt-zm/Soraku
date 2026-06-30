import SwiftUI

struct SettingsView: View {
    @Environment(GameStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.palette) private var palette
    @State private var showResetConfirm = false
    @State private var showPrivacy = false

    var body: some View {
        ZStack {
            AppBackground(palette: palette, reducedMotion: store.settings.reducedMotion)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    ScreenHeader(title: "Settings", subtitle: nil, palette: palette, onBack: { router.pop() }, trailing: nil)
                        .padding(.top, Spacing.m)

                    section("Sound & Feel") {
                        toggleRow("Brush & chimes", "speaker.wave.2", isOn: store.settings.soundEnabled) { v in store.updateSettings { $0.soundEnabled = v } }
                        toggleRow("Ambience", "wind", isOn: store.settings.ambienceEnabled) { v in store.updateSettings { $0.ambienceEnabled = v } }
                        toggleRow("Music", "music.note", isOn: store.settings.musicEnabled) { v in store.updateSettings { $0.musicEnabled = v } }
                        toggleRow("Haptics", "hand.tap", isOn: store.settings.hapticsEnabled) { v in store.updateSettings { $0.hapticsEnabled = v } }
                    }

                    section("Motion & Display") {
                        toggleRow("Reduced motion", "tortoise", isOn: store.settings.reducedMotion) { v in store.updateSettings { $0.reducedMotion = v } }
                        sliderRow("Brush tilt sensitivity", value: store.settings.brushTiltSensitivity) { v in store.updateSettings { $0.brushTiltSensitivity = v } }
                        themeRow
                    }

                    section("Journey") {
                        actionRow("Replay tutorial", "book", tint: palette.textPrimary) {
                            store.resetTutorial()
                            router.popToRoot()
                        }
                        actionRow("Reset all progress", "trash", tint: palette.error) {
                            showResetConfirm = true
                        }
                    }

                    section("Legal") {
                        actionRow("Privacy Policy", "hand.raised", tint: palette.textPrimary) {
                            showPrivacy = true
                        }
                    }

                    section("About") {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            Text("Soraku").font(.display(20)).foregroundStyle(palette.textPrimary)
                            Text("A meditation on the single brushstroke. Trace each glyph in one breath, stay within the rhythm, and let the ink settle.")
                                .font(.body(13)).foregroundStyle(palette.textSecondary)
                            Text("\(store.content.validationReport.solvableLevels) glyphs, all solvable.")
                                .font(.label(12)).foregroundStyle(palette.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.xxl)
            }
            if showResetConfirm {
                ConfirmDialog(
                    title: "Reset everything?",
                    message: "All stars, ink, unlocks, and quests will return to the first morning. This cannot be undone.",
                    confirmTitle: "Reset",
                    palette: palette,
                    onConfirm: {
                        store.resetProgress()
                        showResetConfirm = false
                        router.popToRoot()
                    },
                    onCancel: { showResetConfirm = false }
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPrivacy) {
            PrivacyPolicyView()
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title).font(.title(16)).foregroundStyle(palette.accent)
            InkPanel(palette: palette) {
                VStack(spacing: Spacing.m) { content() }
            }
        }
    }

    private func toggleRow(_ title: String, _ icon: String, isOn: Bool, action: @escaping (Bool) -> Void) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(palette.textSecondary).frame(width: 24)
            Text(title).font(.body(15)).foregroundStyle(palette.textPrimary)
            Spacer()
            SorakuToggle(isOn: isOn, palette: palette, action: action)
        }
    }

    private func sliderRow(_ title: String, value: Double, action: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Image(systemName: "rotate.3d").foregroundStyle(palette.textSecondary).frame(width: 24)
                Text(title).font(.body(15)).foregroundStyle(palette.textPrimary)
            }
            Slider(value: Binding(get: { value }, set: { action($0) }), in: 0...1)
                .tint(palette.accent)
        }
    }

    private var themeRow: some View {
        HStack {
            Image(systemName: "circle.lefthalf.filled").foregroundStyle(palette.textSecondary).frame(width: 24)
            Text("Theme").font(.body(15)).foregroundStyle(palette.textPrimary)
            Spacer()
            HStack(spacing: 6) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Button {
                        store.updateSettings { $0.theme = theme }
                    } label: {
                        Text(theme.title)
                            .font(.label(12))
                            .foregroundStyle(store.settings.theme == theme ? (palette.isDark ? Color(hex: "120F0A") : Color(hex: "F6EFDE")) : palette.textSecondary)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(store.settings.theme == theme ? palette.accent : palette.ink.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func actionRow(_ title: String, _ icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).foregroundStyle(tint).frame(width: 24)
                Text(title).font(.body(15)).foregroundStyle(tint)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(palette.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SorakuToggle: View {
    var isOn: Bool
    var palette: Palette
    var action: (Bool) -> Void
    var body: some View {
        Button { action(!isOn) } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? palette.accent : palette.ink.opacity(0.18)).frame(width: 46, height: 28)
                Circle().fill(palette.paper).frame(width: 22, height: 22).padding(3)
                    .shadow(color: palette.ink.opacity(0.2), radius: 2)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
    }
}

struct ConfirmDialog: View {
    let title: String
    let message: String
    let confirmTitle: String
    var palette: Palette
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().onTapGesture(perform: onCancel)
            InkPanel(palette: palette) {
                VStack(spacing: Spacing.m) {
                    Text(title).font(.display(22)).foregroundStyle(palette.textPrimary)
                    Text(message).font(.body(14)).foregroundStyle(palette.textSecondary).multilineTextAlignment(.center)
                    HStack(spacing: Spacing.s) {
                        SorakuButton(title: "Cancel", kind: .secondary, palette: palette, action: onCancel)
                        SorakuButton(title: confirmTitle, kind: .primary, palette: palette, action: onConfirm)
                    }
                }
                .frame(maxWidth: 320)
            }
            .padding(Spacing.l)
        }
    }
}
