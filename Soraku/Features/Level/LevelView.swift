import SwiftUI

struct LevelView: View {
    let launch: LevelLaunch
    @Environment(GameStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.palette) private var palette

    @State private var engine: LevelEngine?
    @State private var resultHandled = false
    @State private var sessionStart = Date()
    @State private var showResult = false

    private var level: LevelDefinition? { store.content.levelsById[launch.levelId] }

    var body: some View {
        ZStack {
            AppBackground(palette: palette, reducedMotion: store.settings.reducedMotion)
            if let engine, let level {
                content(engine: engine, level: level)
                if engine.status != .playing {
                    resultOverlay(engine: engine, level: level)
                }
            } else {
                SorakuLoader(palette: palette)
            }
        }
        .task { buildEngineIfNeeded() }
        .onAppear {
            sessionStart = Date()
            store.motion.start()
            store.motion.sensitivity = store.settings.brushTiltSensitivity
        }
        .onDisappear {
            store.motion.stop()
            persistProgress()
            store.addTimePlayed(Int(Date().timeIntervalSince(sessionStart)))
        }
    }

    private func buildEngineIfNeeded() {
        guard engine == nil, let level else { return }
        let resume: InProgressLevel?
        if case .campaign = launch.mode { resume = store.inProgress(for: level.id) } else { resume = nil }
        let e = LevelEngine(level: level, resume: resume)
        e.onBrush = { store.audio.playBrush() }
        e.onTraverse = { store.haptics.play(.light) }
        e.onBlot = {
            store.audio.playBlot()
            store.haptics.play(.warning)
        }
        engine = e
        if ProcessInfo.processInfo.environment["SORAKU_AUTOTRACE"] != nil {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                await e.autoSolveForDemo()
            }
        }
    }

    @ViewBuilder
    private func content(engine: LevelEngine, level: LevelDefinition) -> some View {
        VStack(spacing: Spacing.m) {
            topBar(engine: engine, level: level)
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.s)

            goalsRow(engine: engine, level: level)
                .padding(.horizontal, Spacing.l)

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                ZStack {
                    PaperSheet(palette: palette)
                    LevelCanvas(engine: engine, palette: palette, reducedMotion: store.settings.reducedMotion)
                        .padding(2)
                }
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            BreathBar(engine: engine, palette: palette, reducedMotion: store.settings.reducedMotion)
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.l)

            mechanicControls(engine: engine, level: level)
                .padding(.horizontal, Spacing.l)

            controls(engine: engine)
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
        }
        .onChange(of: engine.strokeRecords.count) { _, _ in
            persistProgress()
        }
        .onChange(of: store.motion.tilt) { _, value in
            engine.updateTilt(value)
        }
        .onChange(of: engine.status) { _, status in
            guard status != .playing else { return }
            handleOutcome(engine: engine, level: level)
        }
    }

    private func topBar(engine: LevelEngine, level: LevelDefinition) -> some View {
        HStack(spacing: Spacing.m) {
            IconButton(icon: "xmark", palette: palette) {
                persistProgress()
                router.closeLevel()
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(level.name).font(.display(20)).foregroundStyle(palette.textPrimary)
                Text(modeSubtitle(level)).font(.body(12)).foregroundStyle(palette.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Strokes").font(.label(11)).foregroundStyle(palette.textSecondary)
                StrokeBudgetView(used: engine.strokesUsed, required: engine.requiredStrokes, palette: palette)
            }
        }
    }

    private func modeSubtitle(_ level: LevelDefinition) -> String {
        switch launch.mode {
        case .campaign:
            return store.content.chaptersById[level.chapterId]?.title ?? level.mechanic.title
        case .daily: return "Daily Glyph"
        case .zen: return "Free Ink"
        }
    }

    private func goalsRow(engine: LevelEngine, level: LevelDefinition) -> some View {
        HStack(spacing: Spacing.m) {
            goalChip(icon: "checkmark.seal", text: "\(engine.inkedCount)/\(engine.totalSegments) lines", active: engine.inkedCount == engine.totalSegments)
            goalChip(icon: "drop", text: engine.blots.isEmpty ? "No blots" : "\(engine.blots.count) blot", active: engine.blots.isEmpty)
            goalChip(icon: "wind", text: "Breath", active: true)
            Spacer()
        }
    }

    private func goalChip(icon: String, text: String, active: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 12))
            Text(text).font(.label(12))
        }
        .foregroundStyle(active ? palette.accent : palette.textSecondary)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(palette.ink.opacity(0.06)))
    }

    @ViewBuilder
    private func mechanicControls(engine: LevelEngine, level: LevelDefinition) -> some View {
        HStack(spacing: Spacing.l) {
            if engine.hasColorMechanic {
                HStack(spacing: Spacing.s) {
                    inkDot(.black, engine: engine)
                    inkDot(.vermilion, engine: engine)
                    inkDot(.indigo, engine: engine)
                }
            }
            if engine.hasTiltMechanic {
                tiltControl(engine: engine)
            }
            Spacer()
        }
        .frame(height: engine.hasColorMechanic || engine.hasTiltMechanic ? 44 : 0)
        .opacity(engine.hasColorMechanic || engine.hasTiltMechanic ? 1 : 0)
    }

    private func inkDot(_ kind: InkColorKind, engine: LevelEngine) -> some View {
        Button {
            engine.activeInk = kind
            store.haptics.play(.selection)
        } label: {
            Circle()
                .fill(palette.ink(for: kind))
                .frame(width: 28, height: 28)
                .overlay(Circle().strokeBorder(palette.accent, lineWidth: engine.activeInk == kind ? 3 : 0))
                .overlay(Circle().strokeBorder(palette.panelEdge.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func tiltControl(engine: LevelEngine) -> some View {
        let tilt = store.motion.tilt
        return HStack(spacing: Spacing.s) {
            Image(systemName: "rotate.3d").font(.system(size: 14)).foregroundStyle(palette.textSecondary)
            ProgressBead(fraction: tilt, palette: palette, tint: palette.indigo)
                .frame(width: 70)
            if !store.motion.available {
                Button {
                    store.motion.applySimulatedTilt(tilt > 0.4 ? 0 : 1)
                } label: {
                    Text("Lean").font(.label(12)).foregroundStyle(palette.accent)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(palette.accent.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func controls(engine: LevelEngine) -> some View {
        HStack(spacing: Spacing.m) {
            controlButton(icon: "lightbulb", label: "Hint") { engine.revealHint(); store.haptics.play(.soft) }
            controlButton(icon: "arrow.uturn.backward", label: "Undo") { engine.undo(); store.haptics.play(.soft) }
            controlButton(icon: "arrow.counterclockwise", label: "Reset") { engine.reset(); store.haptics.play(.soft) }
        }
    }

    private func controlButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 18, weight: .medium))
                Text(label).font(.label(11))
            }
            .foregroundStyle(palette.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.m)
            .background(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).fill(palette.panel))
            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(palette.panelEdge.opacity(0.6), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func resultOverlay(engine: LevelEngine, level: LevelDefinition) -> some View {
        if let result = engine.result {
            LevelResultView(
                result: result,
                level: level,
                palette: palette,
                reducedMotion: store.settings.reducedMotion,
                onRetry: {
                    resultHandled = false
                    engine.reset()
                },
                onNext: { advance(from: level) },
                onExit: {
                    persistProgress()
                    router.closeLevel()
                }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    private func handleOutcome(engine: LevelEngine, level: LevelDefinition) {
        guard let result = engine.result, !resultHandled else { return }
        resultHandled = true
        if result.cleared {
            switch launch.mode {
            case .campaign:
                store.completeLevel(result)
            case .daily(let key):
                store.completeLevel(result, isDaily: true, dateKey: key)
            case .zen:
                break
            }
        } else {
            store.haptics.play(.warning)
        }
    }

    private func advance(from level: LevelDefinition) {
        resultHandled = false
        switch launch.mode {
        case .campaign:
            if let chapter = store.content.chaptersById[level.chapterId],
               level.indexInChapter + 1 < chapter.levelIds.count {
                let nextId = chapter.levelIds[level.indexInChapter + 1]
                engine = nil
                router.activeLevel = LevelLaunch(levelId: nextId, mode: .campaign)
            } else {
                router.closeLevel()
            }
        default:
            router.closeLevel()
        }
    }

    private func persistProgress() {
        guard let engine, case .campaign = launch.mode else { return }
        if let snapshot = engine.snapshotInProgress() {
            store.saveInProgress(levelId: snapshot.levelId, inked: snapshot.inkedSegments, records: snapshot.strokeRecords.map { $0.record })
        } else if engine.status != .playing {
            store.clearInProgress()
        }
    }
}
