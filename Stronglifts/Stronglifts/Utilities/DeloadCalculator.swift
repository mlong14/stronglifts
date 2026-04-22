import Foundation

enum DeloadCalculator {
    /// Returns the weight to use for a given exercise, adjusted downward based on
    /// how many days have passed since the exercise was last performed.
    ///
    /// `currentWeight` is the planned progressive weight (last successful weight + increment).
    /// `isBarbell` affects the floor: barbell lifts can't go below bar weight (45 lbs);
    /// bodyweight/dumbbell exercises floor at 0 so a 0-lb exercise stays at 0.
    static func adjustedWeight(
        currentWeight: Double,
        increment: Double,
        daysSinceLastWorkout: Int,
        isBarbell: Bool = false
    ) -> Double {
        let steps: Int
        switch daysSinceLastWorkout {
        case ..<12:  steps = 0  // normal gap — use planned weight
        case 12..<20: steps = 1 // ~missed a week — repeat last weight
        case 20..<28: steps = 2 // ~missed two weeks — back off one step
        default:     steps = 3  // month+ — back off two steps
        }
        let floor = isBarbell ? WarmupCalculator.barWeight : 0.0
        return max(currentWeight - Double(steps) * increment, floor)
    }
}
