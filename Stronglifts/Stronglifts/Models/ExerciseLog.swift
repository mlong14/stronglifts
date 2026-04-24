import SwiftData
import Foundation

@Model
final class ExerciseLog {
    var exerciseName: String
    var targetWeight: Double
    var order: Int
    var warmupCompletedCount: Int = 0
    var session: WorkoutSession?
    @Relationship(deleteRule: .cascade)
    var setLogs: [SetLog] = []

    init(exerciseName: String, targetWeight: Double, order: Int) {
        self.exerciseName = exerciseName
        self.targetWeight = targetWeight
        self.order = order
    }

    var sortedSets: [SetLog] {
        setLogs.sorted { $0.setNumber < $1.setNumber }
    }

    /// The lowest actual weight performed across all completed sets.
    /// Falls back to targetWeight if no sets were completed.
    var effectiveWeight: Double {
        let completedWeights = setLogs.compactMap { set -> Double? in
            guard set.isCompleted else { return nil }
            return set.weight ?? targetWeight
        }
        return completedWeights.min() ?? targetWeight
    }

    /// True if all sets were completed and none were failed.
    var wasSuccessful: Bool {
        !setLogs.isEmpty && setLogs.allSatisfy { $0.isCompleted && !$0.failed }
    }
}
