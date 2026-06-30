import Foundation
import CoreGraphics
import Observation

struct InkedStroke: Identifiable, Hashable {
    let id: Int
    var nodeSequence: [String]
    var color: InkColorKind
    var richness: Double
    var blotted: Bool
}

struct Blot: Identifiable, Hashable {
    let id: Int
    let position: CGPoint
    let size: Double
    let seed: UInt64
}

enum LevelStatus: Equatable {
    case playing
    case cleared
    case failed
}

@MainActor
@Observable
final class LevelEngine {
    let level: LevelDefinition
    @ObservationIgnored let graph: GlyphGraph
    @ObservationIgnored private let breath: BreathEvaluator
    @ObservationIgnored private let solution: StrokeSolution

    private(set) var inkedSegments: Set<String> = []
    private(set) var committedStrokes: [InkedStroke] = []
    private(set) var liveStroke: InkedStroke?
    private(set) var strokeRecords: [StrokeRecord] = []
    private(set) var blots: [Blot] = []
    private(set) var status: LevelStatus = .playing
    private(set) var currentNode: String?
    private(set) var fingerPoint: CGPoint?
    private(set) var hintSegment: String?
    private(set) var result: LevelRunResult?

    var activeInk: InkColorKind = .black
    @ObservationIgnored private var tiltReveal: Double = 0
    @ObservationIgnored private var strokeStart: Date = Date()
    @ObservationIgnored private var lastNodeTime: Date = Date()
    @ObservationIgnored private var strokeLength: Double = 0
    @ObservationIgnored private var strokeBlotted = false
    @ObservationIgnored private var nextStrokeId = 0
    @ObservationIgnored private var nextBlotId = 0
    @ObservationIgnored private var hintTask: Task<Void, Never>?

    let snapRadius: Double = 0.062
    var onBrush: (() -> Void)?
    var onBlot: (() -> Void)?
    var onTraverse: (() -> Void)?

    var requiredStrokes: Int { level.requiredStrokes }
    var strokesUsed: Int { strokeRecords.count }
    var strokesRemaining: Int { max(0, level.requiredStrokes - strokeRecords.count) }
    var totalSegments: Int { level.segments.count }
    var inkedCount: Int { inkedSegments.count }
    var hasColorMechanic: Bool { level.segments.contains { $0.color != .black } }
    var hasTiltMechanic: Bool { level.segments.contains { $0.tiltRevealed } }

    init(level: LevelDefinition, resume: InProgressLevel? = nil) {
        self.level = level
        self.graph = GlyphGraph(level: level)
        self.breath = BreathEvaluator(tempo: level.breath.tempo, tolerance: level.breath.tolerance)
        self.solution = GlyphSolver.solve(graph)
        if let resume, resume.levelId == level.id {
            restore(resume)
        }
    }

    private func restore(_ p: InProgressLevel) {
        for rec in p.strokeRecords {
            let stroke = strokeFromRecord(rec.record)
            committedStrokes.append(stroke)
            strokeRecords.append(rec.record)
            for s in rec.segmentIds { inkedSegments.insert(s) }
            if rec.blotted, let node = stroke.nodeSequence.last {
                addBlot(at: graph.position(node))
            }
        }
    }

    private func strokeFromRecord(_ rec: StrokeRecord) -> InkedStroke {
        var nodes: [String] = []
        for segId in rec.segmentIds {
            guard let seg = graph.segment(segId) else { continue }
            if nodes.isEmpty {
                nodes.append(seg.a); nodes.append(seg.b)
            } else if nodes.last == seg.a {
                nodes.append(seg.b)
            } else if nodes.last == seg.b {
                nodes.append(seg.a)
            } else {
                nodes.append(seg.a); nodes.append(seg.b)
            }
        }
        let color = rec.segmentIds.compactMap { graph.segment($0)?.color }.first ?? .black
        let id = nextStrokeId; nextStrokeId += 1
        return InkedStroke(id: id, nodeSequence: nodes, color: color, richness: breath.richness(duration: rec.duration, length: rec.inkLength), blotted: rec.blotted)
    }


    func updateTilt(_ value: Double) { tiltReveal = value }
    func isTiltRevealed(_ segment: GlyphSegment) -> Bool {
        guard segment.tiltRevealed else { return true }
        return tiltReveal >= 0.45
    }
    var tiltLevel: Double { tiltReveal }

    func begin(at point: CGPoint) {
        guard status == .playing else { return }
        guard let node = nearestStartNode(to: point) else { return }
        currentNode = node
        fingerPoint = point
        strokeStart = Date()
        lastNodeTime = strokeStart
        strokeLength = 0
        strokeBlotted = false
        let id = nextStrokeId; nextStrokeId += 1
        liveStroke = InkedStroke(id: id, nodeSequence: [node], color: activeInk, richness: 1, blotted: false)
        clearHint()
    }

    func move(to point: CGPoint) {
        guard status == .playing, currentNode != nil else { return }
        fingerPoint = point
        var advanced = true
        var guardCount = 0
        while advanced, guardCount < 12 {
            advanced = false
            guardCount += 1
            guard let node = currentNode else { break }
            guard let target = bestTraceableNeighbor(from: node, toward: point) else { break }
            traverse(from: node, to: target.neighbor, segment: target.segment)
            advanced = true
            if strokeBlotted { break }
        }
    }

    func end() {
        guard status == .playing else { return }
        finalizeStroke()
    }

    private func traverse(from node: String, to neighbor: String, segment: GlyphSegment) {
        let now = Date()
        let length = distance(graph.position(node), graph.position(neighbor))
        let dt = max(0.0001, now.timeIntervalSince(lastNodeTime))
        let speed = length / dt
        let tearSpeed = max(3.0, (0.55 / max(0.4, level.breath.tempo)) * 7.0)

        inkedSegments.insert(segment.id)
        liveStroke?.nodeSequence.append(neighbor)
        if liveStroke?.color != segment.color, segment.color != .black {
            liveStroke?.color = segment.color
        }
        currentNode = neighbor
        strokeLength += length
        lastNodeTime = now
        onTraverse?()
        onBrush?()

        if speed > tearSpeed {
            strokeBlotted = true
            addBlot(at: graph.position(neighbor))
            onBlot?()
            finalizeStroke()
        }
    }

    private func finalizeStroke() {
        guard var stroke = liveStroke else {
            currentNode = nil
            fingerPoint = nil
            return
        }
        let segmentIds = segmentIdsForSequence(stroke.nodeSequence)
        guard !segmentIds.isEmpty else {
            liveStroke = nil
            currentNode = nil
            fingerPoint = nil
            return
        }
        let duration = Date().timeIntervalSince(strokeStart)
        let calm = !strokeBlotted && breath.isCalm(duration: duration, length: strokeLength)
        let perfect = calm && !strokeBlotted
        stroke.richness = breath.richness(duration: duration, length: strokeLength)
        stroke.blotted = strokeBlotted
        committedStrokes.append(stroke)
        let record = StrokeRecord(segmentIds: segmentIds, duration: duration, inkLength: strokeLength, blotted: strokeBlotted, calm: calm, perfect: perfect)
        strokeRecords.append(record)

        liveStroke = nil
        currentNode = nil
        fingerPoint = nil

        evaluateOutcome()
    }

    private func evaluateOutcome() {
        if inkedSegments.count == level.segments.count {
            status = .cleared
            result = StarEvaluator.evaluate(level: level, records: strokeRecords, cleared: true)
        } else if strokeRecords.count >= level.requiredStrokes {
            status = .failed
            result = StarEvaluator.evaluate(level: level, records: strokeRecords, cleared: false)
        }
    }


    func undo() {
        guard status == .playing, let last = committedStrokes.popLast() else { return }
        let record = strokeRecords.popLast()
        if let ids = record?.segmentIds {
            for id in ids { inkedSegments.remove(id) }
        }
        if last.blotted, !blots.isEmpty { blots.removeLast() }
        clearHint()
    }

    func reset() {
        inkedSegments.removeAll()
        committedStrokes.removeAll()
        strokeRecords.removeAll()
        blots.removeAll()
        liveStroke = nil
        currentNode = nil
        fingerPoint = nil
        status = .playing
        result = nil
        clearHint()
    }

    func revealHint() {
        guard status == .playing else { return }
        guard let suggestion = nextSolutionSegment() else { return }
        hintSegment = suggestion
        hintTask?.cancel()
        hintTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            self.hintSegment = nil
        }
    }

    private func clearHint() {
        hintTask?.cancel()
        hintSegment = nil
    }


    private func nearestStartNode(to point: CGPoint) -> String? {
        var best: String?
        var bestDist = snapRadius
        for (node, pos) in graph.nodePositions {
            let incident = graph.adjacency[node]?.contains { !inkedSegments.contains($0.segment) } ?? false
            guard incident else { continue }
            let d = distance(pos, point)
            if d < bestDist { bestDist = d; best = node }
        }
        return best
    }

    private struct NeighborChoice { let neighbor: String; let segment: GlyphSegment }

    private func bestTraceableNeighbor(from node: String, toward point: CGPoint) -> NeighborChoice? {
        var best: NeighborChoice?
        var bestDist = Double.greatestFiniteMagnitude
        for edge in graph.adjacency[node] ?? [] {
            guard !inkedSegments.contains(edge.segment) else { continue }
            guard let seg = graph.segment(edge.segment) else { continue }
            if seg.color != .black && activeInk != seg.color { continue }
            if !isTiltRevealed(seg) { continue }
            let pos = graph.position(edge.neighbor)
            let d = distance(pos, point)
            if d <= snapRadius * 1.15 && d < bestDist {
                bestDist = d
                best = NeighborChoice(neighbor: edge.neighbor, segment: seg)
            }
        }
        return best
    }

    private func segmentIdsForSequence(_ sequence: [String]) -> [String] {
        guard sequence.count >= 2 else { return [] }
        var ids: [String] = []
        for i in 0..<(sequence.count - 1) {
            let a = sequence[i], b = sequence[i + 1]
            if let edge = graph.adjacency[a]?.first(where: { $0.neighbor == b }) {
                ids.append(edge.segment)
            }
        }
        return ids
    }

    private func nextSolutionSegment() -> String? {
        for stroke in solution.strokes {
            for segId in stroke where !inkedSegments.contains(segId) {
                return segId
            }
        }
        return level.segments.first { !inkedSegments.contains($0.id) }?.id
    }

    private func addBlot(at point: CGPoint) {
        let id = nextBlotId; nextBlotId += 1
        var rng = SeededGenerator(seed: UInt64(0xB10 &+ UInt64(id) &* 2654435761))
        blots.append(Blot(id: id, position: point, size: 0.03 + rng.unit() * 0.025, seed: rng.next()))
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        let dx = a.x - b.x, dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }

    func snapshotInProgress() -> InProgressLevel? {
        guard status == .playing, !strokeRecords.isEmpty else { return nil }
        return InProgressLevel(
            levelId: level.id,
            inkedSegments: Array(inkedSegments),
            strokeRecords: strokeRecords.map(SavedStrokeRecord.init)
        )
    }

    func breathPhase(elapsed: Double) -> Double { breath.phase(elapsed: elapsed) }

    func solutionNodeSequences() -> [[String]] {
        solution.strokes.map { ids in
            var nodes: [String] = []
            for segId in ids {
                guard let seg = graph.segment(segId) else { continue }
                if nodes.isEmpty {
                    nodes = [seg.a, seg.b]
                } else if nodes.last == seg.a {
                    nodes.append(seg.b)
                } else if nodes.last == seg.b {
                    nodes.append(seg.a)
                } else {
                    nodes.append(contentsOf: [seg.a, seg.b])
                }
            }
            return nodes
        }
    }

    func autoSolveForDemo() async {
        updateTilt(1)
        for sequence in solutionNodeSequences() {
            guard let first = sequence.first else { continue }
            applyInkForEdge(from: first, to: sequence.dropFirst().first)
            begin(at: graph.position(first))
            for node in sequence.dropFirst() {
                try? await Task.sleep(nanoseconds: 820_000_000)
                applyInkForEdge(from: currentNode ?? first, to: node)
                updateTilt(1)
                move(to: graph.position(node))
            }
            end()
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    private func applyInkForEdge(from: String, to: String?) {
        guard let to, let edge = graph.adjacency[from]?.first(where: { $0.neighbor == to }),
              let seg = graph.segment(edge.segment), seg.color != .black else { return }
        activeInk = seg.color
    }
}
