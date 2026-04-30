import HealthKit

@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    private let typesToShare: Set<HKSampleType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.activeEnergyBurned),
    ]

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try? await store.requestAuthorization(toShare: typesToShare, read: [])
    }

    // MARK: - Save

    func saveWorkout(_ session: WorkoutSession) async {
        guard HKHealthStore.isHealthDataAvailable(),
              let endTime = session.endTime else { return }

        let start    = session.date
        let end      = endTime
        let duration = end.timeIntervalSince(start)

        // Active energy: ~5 kcal/min for heavy compound lifting
        let energySample = HKQuantitySample(
            type: HKQuantityType(.activeEnergyBurned),
            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: (duration / 60) * 5),
            start: start,
            end: end
        )

        // Total volume: weight × reps across all completed non-failed sets
        let totalVolume = session.exerciseLogs.reduce(0.0) { sum, log in
            let reps = log.setLogs.filter { $0.isCompleted && !$0.failed }
                                  .reduce(0) { $0 + $1.completedReps }
            return sum + log.effectiveWeight * Double(reps)
        }

        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining

        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())

        do {
            try await builder.beginCollection(at: start)

            try await builder.addSamples([energySample])

            let metadata: [String: Any] = [
                HKMetadataKeyWorkoutBrandName: "Stronglifts",
                "SL_WorkoutName": session.templateName,
                "SL_TotalVolumeLbs": totalVolume,
            ]
            try await builder.addMetadata(metadata)

            try await builder.endCollection(at: end)
            try await builder.finishWorkout()
        } catch {
            // HealthKit failure is non-fatal — workout is already saved in SwiftData
        }
    }
}
