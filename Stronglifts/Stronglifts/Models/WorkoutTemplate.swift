import SwiftData
import Foundation
import SwiftUI

@Model
final class WorkoutTemplate {
    var name: String
    @Relationship(deleteRule: .cascade)
    var exercises: [ExerciseTemplate] = []

    init(name: String) {
        self.name = name
    }

    var sortedExercises: [ExerciseTemplate] {
        exercises.sorted { $0.order < $1.order }
    }

    /// Stable color derived from the template name — consistent across launches.
    static func color(for name: String) -> Color {
        switch name {
        case "A": return .blue
        case "B": return .orange
        case "C": return .purple
        case "F": return .green
        default:
            let palette: [Color] = [.blue, .orange, .green, .purple, .teal, .pink]
            let value = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
            return palette[value % palette.count]
        }
    }

    var color: Color { WorkoutTemplate.color(for: name) }
}
