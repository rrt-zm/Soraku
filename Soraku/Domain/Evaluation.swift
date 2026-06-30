import Foundation

struct StrokeRecord: Hashable {
    let segmentIds: [String]
    let duration: Double
    let inkLength: Double
    let blotted: Bool
    let calm: Bool
    let perfect: Bool
}

struct LevelRunResult: Hashable {
    let levelId: String
    let cleared: Bool
    let strokesUsed: Int
    let requiredStrokes: Int
    let blotCount: Int
    let calmStrokes: Int
    let totalStrokes: Int
    let perfectStrokes: Int
    let stars: Int
    let reward: Int
    let calmRatio: Double
    let crossingGlyph: Bool

    var starsEarnedThisRun: Int { stars }
}

enum StarEvaluator {
    static func evaluate(level: LevelDefinition, records: [StrokeRecord], cleared: Bool) -> LevelRunResult {
        let total = max(1, records.count)
        let blots = records.filter { $0.blotted }.count
        let calm = records.filter { $0.calm }.count
        let perfect = records.filter { $0.perfect }.count
        let ratio = Double(calm) / Double(total)

        var stars = 0
        if cleared {
            stars += 1
            if blots <= level.starThresholds.maxBlots { stars += 1 }
            if ratio >= level.starThresholds.calmBreathRatio { stars += 1 }
        }
        let baseReward = cleared ? level.reward : 0
        let bonus = cleared ? stars * 3 : 0

        return LevelRunResult(
            levelId: level.id,
            cleared: cleared,
            strokesUsed: records.count,
            requiredStrokes: level.requiredStrokes,
            blotCount: blots,
            calmStrokes: calm,
            totalStrokes: records.count,
            perfectStrokes: perfect,
            stars: stars,
            reward: baseReward + bonus,
            calmRatio: ratio,
            crossingGlyph: !level.crossings.isEmpty
        )
    }
}

struct BreathEvaluator {
    let tempo: Double
    let tolerance: Double

    func idealDuration(forLength length: Double) -> Double {
        let baseSpeed = 0.55 / max(0.4, tempo)
        return max(0.18, length / baseSpeed)
    }

    func phase(elapsed: Double) -> Double {
        let cycle = tempo
        let t = (elapsed.truncatingRemainder(dividingBy: cycle)) / cycle
        return 0.5 - 0.5 * cos(t * 2 * Double.pi)
    }

    func isCalm(duration: Double, length: Double) -> Bool {
        guard length > 0.0001 else { return true }
        let ideal = idealDuration(forLength: length)
        let lower = ideal * (1 - tolerance)
        let upper = ideal * (1 + tolerance * 1.6)
        return duration >= lower && duration <= upper
    }

    func richness(duration: Double, length: Double) -> Double {
        guard length > 0.0001 else { return 1 }
        let ideal = idealDuration(forLength: length)
        let ratio = duration / ideal
        if ratio < 1 {
            return max(0.25, ratio)
        } else {
            return max(0.35, 1.0 - (ratio - 1) * 0.5)
        }
    }
}
