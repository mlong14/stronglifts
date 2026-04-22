import SwiftData
import Foundation

@Model
final class WorkoutSession {
    var date: Date          // start time
    var endTime: Date?
    var templateName: String  // "A" or "B"
    var isCompleted: Bool
    var averageHeartRate: Double? = nil
    var maxHeartRate: Int? = nil
    @Relationship(deleteRule: .cascade)
    var exerciseLogs: [ExerciseLog] = []

    init(date: Date = .now, templateName: String) {
        self.date = date
        self.templateName = templateName
        self.isCompleted = false
    }

    var sortedLogs: [ExerciseLog] {
        exerciseLogs.sorted { $0.order < $1.order }
    }

    /// True if every set in the session was completed without failure.
    var wasFullySuccessful: Bool {
        exerciseLogs.allSatisfy { $0.wasSuccessful }
    }
}
