import SwiftData
import Foundation

@Model
final class ExerciseTemplate {
    var name: String
    var sets: Int
    var reps: Int
    var increment: Double  // lbs added after a successful session
    var currentWeight: Double
    var order: Int
    var workoutTemplate: WorkoutTemplate?

    init(name: String, sets: Int, reps: Int, increment: Double, order: Int) {
        self.name = name
        self.sets = sets
        self.reps = reps
        self.increment = increment
        self.currentWeight = 0
        self.order = order
    }
}
