import SwiftUI
import SwiftData

@main
struct StrongliftsApp: App {
    let container: ModelContainer

    init() {
        do {
            // To enable iCloud sync: replace ModelConfiguration() with
            // ModelConfiguration(cloudKitDatabase: .automatic)
            // and add iCloud + CloudKit capability in Xcode (Signing & Capabilities).
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            container = try ModelContainer(
                for: Schema([WorkoutTemplate.self, ExerciseTemplate.self,
                             WorkoutSession.self, ExerciseLog.self, SetLog.self]),
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
        
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isReady = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if !isReady {
                ProgressView()
                    .onAppear(perform: setup)
            } else if !hasCompletedOnboarding {
                OnboardingView()
            } else {
                ContentView()
            }
        }
    }

    private func setup() {
        let count = (try? modelContext.fetchCount(FetchDescriptor<WorkoutTemplate>())) ?? 0
        if count == 0 {
            seedDefaultProgram()
        }
        Task { await HealthKitService.shared.requestAuthorization() }
        isReady = true
    }

    private func seedDefaultProgram() {
        let workout = WorkoutTemplate(name: "F")
        workout.exercises = [
            ExerciseTemplate(name: "Squat",          sets: 3, reps: 5, increment: 10, order: 0),
            ExerciseTemplate(name: "Bench Press",    sets: 3, reps: 5, increment: 5,  order: 1),
            ExerciseTemplate(name: "Barbell Row",    sets: 3, reps: 5, increment: 5,  order: 2),
            ExerciseTemplate(name: "Overhead Press", sets: 2, reps: 5, increment: 5,  order: 3),
            ExerciseTemplate(name: "Deadlift",       sets: 1, reps: 5, increment: 10, order: 4),
        ]
        modelContext.insert(workout)
        try? modelContext.save()
    }
}
