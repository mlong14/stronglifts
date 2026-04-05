import SwiftData
import Foundation

@Model
final class WorkoutTemplate {
    var name: String // "A" or "B"
    @Relationship(deleteRule: .cascade)
    var exercises: [ExerciseTemplate] = []

    init(name: String) {
        self.name = name
    }

    var sortedExercises: [ExerciseTemplate] {
        exercises.sorted { $0.order < $1.order }
    }
}
