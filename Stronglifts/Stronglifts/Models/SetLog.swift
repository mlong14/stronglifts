import SwiftData
import Foundation

@Model
final class SetLog {
    var setNumber: Int       // 1-based
    var targetReps: Int
    var completedReps: Int
    var failed: Bool
    var isCompleted: Bool
    var weight: Double?      // nil = use exercise's targetWeight
    var exerciseLog: ExerciseLog?

    init(setNumber: Int, targetReps: Int) {
        self.setNumber = setNumber
        self.targetReps = targetReps
        self.completedReps = 0
        self.failed = false
        self.isCompleted = false
        self.weight = nil
    }
}
