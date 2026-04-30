import Foundation

enum DeloadCalculator {
    /// Returns the weight to use for a given exercise, adjusted downward based on
    /// how many days have passed since the exercise was last performed.
    ///
    /// `currentWeight` is the planned progressive weight (last successful weight + increment).
    /// `isBarbell` affects the floor: barbell lifts can't go below bar weight (45 lbs);
    /// bodyweight/dumbbell exercises floor at 0 so a 0-lb exercise stays at 0.
    /// - `currentWeight`: the planned next weight (already includes one increment after a
    ///   successful session, unchanged after a failure).
    /// - `lastRPE`: how the last *successful* attempt felt. Adjusts the candidate before
    ///   time-decay is applied: easy → extra increment, hard → undo last increment.
    static func adjustedWeight(
        currentWeight: Double,
        increment: Double,
        daysSinceLastWorkout: Int,
        lastRPE: RPEFeedback? = nil,
        isBarbell: Bool = false
    ) -> Double {
        // RPE shifts the candidate weight relative to the already-progressed currentWeight
        let rpeOffset: Double
        switch lastRPE {
        case .easy:        rpeOffset =  increment   // double-jump
        case .good, .none: rpeOffset =  0
        case .hard:        rpeOffset = -increment   // undo last increment, repeat weight
        }

        let candidate = currentWeight + rpeOffset

        let steps: Int
        switch daysSinceLastWorkout {
        case ..<12:   steps = 0  // normal gap
        case 12..<20: steps = 1  // ~missed a week
        case 20..<28: steps = 2  // ~missed two weeks
        default:      steps = 3  // month+
        }

        let floor = isBarbell ? WarmupCalculator.barWeight : 0.0
        return max(candidate - Double(steps) * increment, floor)
    }
}
