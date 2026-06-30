import Foundation
import CoreGraphics

struct GlyphGraph {
    let nodePositions: [String: CGPoint]
    let segments: [GlyphSegment]
    private let segmentById: [String: GlyphSegment]
    let adjacency: [String: [(neighbor: String, segment: String)]]

    init(level: LevelDefinition) {
        var positions: [String: CGPoint] = [:]
        for node in level.nodes { positions[node.id] = node.point }
        nodePositions = positions
        segments = level.segments
        var byId: [String: GlyphSegment] = [:]
        var adj: [String: [(String, String)]] = [:]
        for node in level.nodes { adj[node.id] = [] }
        for seg in level.segments {
            byId[seg.id] = seg
            adj[seg.a, default: []].append((seg.b, seg.id))
            adj[seg.b, default: []].append((seg.a, seg.id))
        }
        segmentById = byId
        adjacency = adj.mapValues { $0.map { (neighbor: $0.0, segment: $0.1) } }
    }

    func segment(_ id: String) -> GlyphSegment? { segmentById[id] }

    func other(of segment: GlyphSegment, than node: String) -> String {
        segment.a == node ? segment.b : segment.a
    }

    func endpoints(of segmentId: String) -> (String, String)? {
        guard let s = segmentById[segmentId] else { return nil }
        return (s.a, s.b)
    }

    func position(_ node: String) -> CGPoint { nodePositions[node] ?? .zero }

    func degree(of node: String) -> Int { adjacency[node]?.count ?? 0 }

    var components: [Set<String>] {
        var seen = Set<String>()
        var result: [Set<String>] = []
        for node in adjacency.keys where degree(of: node) > 0 {
            if seen.contains(node) { continue }
            var comp = Set<String>()
            var stack = [node]
            seen.insert(node)
            comp.insert(node)
            while let v = stack.popLast() {
                for edge in adjacency[v] ?? [] where !seen.contains(edge.neighbor) {
                    seen.insert(edge.neighbor)
                    comp.insert(edge.neighbor)
                    stack.append(edge.neighbor)
                }
            }
            result.append(comp)
        }
        return result
    }

    var minimumStrokes: Int {
        var total = 0
        for comp in components {
            let odd = comp.filter { degree(of: $0) % 2 == 1 }.count
            total += max(1, odd / 2)
        }
        return max(1, total)
    }
}

struct StrokeSolution {
    let strokes: [[String]]
}

enum GlyphSolver {
    private struct HalfEdge { let neighbor: String; let key: Int; let isTemp: Bool; let segmentId: String? }
    private struct EdgeRef { let from: String; let to: String; let isTemp: Bool; let segmentId: String? }

    static func solve(_ graph: GlyphGraph) -> StrokeSolution {
        var allStrokes: [[String]] = []
        for comp in graph.components {
            allStrokes.append(contentsOf: solveComponent(graph, nodes: comp))
        }
        if allStrokes.isEmpty { allStrokes = [[]] }
        return StrokeSolution(strokes: allStrokes)
    }

    private static func solveComponent(_ graph: GlyphGraph, nodes: Set<String>) -> [[String]] {
        var adj: [String: [HalfEdge]] = [:]
        for n in nodes { adj[n] = [] }
        var key = 0
        for seg in graph.segments where nodes.contains(seg.a) && nodes.contains(seg.b) {
            adj[seg.a]?.append(HalfEdge(neighbor: seg.b, key: key, isTemp: false, segmentId: seg.id))
            adj[seg.b]?.append(HalfEdge(neighbor: seg.a, key: key, isTemp: false, segmentId: seg.id))
            key += 1
        }

        let odd = nodes.filter { (adj[$0]?.count ?? 0) % 2 == 1 }.sorted()
        var tempPairs: [(String, String)] = []
        var i = 0
        while i + 1 < odd.count {
            let a = odd[i], b = odd[i + 1]
            adj[a]?.append(HalfEdge(neighbor: b, key: key, isTemp: true, segmentId: nil))
            adj[b]?.append(HalfEdge(neighbor: a, key: key, isTemp: true, segmentId: nil))
            tempPairs.append((a, b))
            key += 1
            i += 2
        }

        let start = odd.first ?? nodes.sorted().first ?? ""
        let circuit = hierholzer(start: start, adjacency: &adj)
        return splitAtTemp(circuit)
    }

    private static func hierholzer(start: String, adjacency adj: inout [String: [HalfEdge]]) -> [EdgeRef] {
        var used = Set<Int>()
        var pointer: [String: Int] = [:]
        for k in adj.keys { pointer[k] = 0 }
        var vertexStack = [start]
        var edgeStack: [EdgeRef] = []
        var result: [EdgeRef] = []

        while let v = vertexStack.last {
            var advanced = false
            var p = pointer[v] ?? 0
            let edges = adj[v] ?? []
            while p < edges.count {
                let h = edges[p]
                p += 1
                if used.contains(h.key) { continue }
                used.insert(h.key)
                pointer[v] = p
                vertexStack.append(h.neighbor)
                edgeStack.append(EdgeRef(from: v, to: h.neighbor, isTemp: h.isTemp, segmentId: h.segmentId))
                advanced = true
                break
            }
            if !advanced {
                pointer[v] = p
                vertexStack.removeLast()
                if let e = edgeStack.popLast() { result.append(e) }
            }
        }
        return result.reversed()
    }

    private static func splitAtTemp(_ circuit: [EdgeRef]) -> [[String]] {
        guard !circuit.isEmpty else { return [] }
        let hasTemp = circuit.contains { $0.isTemp }
        if !hasTemp {
            let ids = circuit.compactMap { $0.segmentId }
            return ids.isEmpty ? [] : [ids]
        }
        var startIndex = 0
        for (idx, e) in circuit.enumerated() where e.isTemp {
            startIndex = (idx + 1) % circuit.count
            break
        }
        var trails: [[String]] = []
        var current: [String] = []
        for offset in 0..<circuit.count {
            let e = circuit[(startIndex + offset) % circuit.count]
            if e.isTemp {
                if !current.isEmpty { trails.append(current); current = [] }
            } else if let id = e.segmentId {
                current.append(id)
            }
        }
        if !current.isEmpty { trails.append(current) }
        return trails
    }
}
