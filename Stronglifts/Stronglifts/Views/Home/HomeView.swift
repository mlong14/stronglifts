import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [WorkoutSession]
    @Query private var templates: [WorkoutTemplate]

    @State private var activeSession: WorkoutSession?
    @State private var stravaError: Error?
    @ObservedObject private var strava = StravaService.shared

    private var sortedSessions: [WorkoutSession] {
        sessions.sorted { $0.date > $1.date }
    }

    private var nextTemplateName: String {
        guard let last = sortedSessions.first(where: { $0.isCompleted }) else { return "A" }
        return last.templateName == "A" ? "B" : "A"
    }

    private var nextTemplate: WorkoutTemplate? {
        templates.first { $0.name == nextTemplateName }
    }

    private var lastSession: WorkoutSession? {
        sortedSessions.first(where: { $0.isCompleted })
    }

    /// Most recent completed session date for each exercise name.
    private var lastSessionDateByExercise: [String: Date] {
        var result: [String: Date] = [:]
        for session in sessions where session.isCompleted {
            for log in session.exerciseLogs {
                if result[log.exerciseName].map({ session.date > $0 }) ?? true {
                    result[log.exerciseName] = session.date
                }
            }
        }
        return result
    }

    /// Adjusted weight accounting for how long it's been since the exercise was last done.
    private func adjustedWeight(for exercise: ExerciseTemplate) -> Double {
        guard let lastDate = lastSessionDateByExercise[exercise.name] else {
            return exercise.currentWeight
        }
        let days = Calendar.current.dateComponents([.day], from: lastDate, to: .now).day ?? 0
        return DeloadCalculator.adjustedWeight(
            currentWeight: exercise.currentWeight,
            increment: exercise.increment,
            daysSinceLastWorkout: days,
            isBarbell: WarmupCalculator.isCore(exercise.name)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Next workout card
                    if let template = nextTemplate {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Next Workout", systemImage: "figure.strengthtraining.traditional")
                                .font(.caption)
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)

                            Text("Workout \(template.name)")
                                .font(.largeTitle.bold())

                            ForEach(template.sortedExercises) { exercise in
                                let suggested = adjustedWeight(for: exercise)
                                let isDeloaded = suggested < exercise.currentWeight
                                let daysAgo = lastSessionDateByExercise[exercise.name].map {
                                    Calendar.current.dateComponents([.day], from: $0, to: .now).day ?? 0
                                }
                                HStack {
                                    Text(exercise.name)
                                        .font(.body)
                                    Spacer()
                                    HStack(spacing: 4) {
                                        if isDeloaded, let days = daysAgo {
                                            Text("\(days)d ago")
                                                .font(.caption2)
                                                .foregroundStyle(.orange.opacity(0.8))
                                            Image(systemName: "arrow.down.circle.fill")
                                                .foregroundStyle(.orange)
                                                .font(.caption)
                                        }
                                        Text("\(exercise.sets)×\(exercise.reps) @ \(formattedWeight(suggested)) lbs")
                                            .font(.body.monospacedDigit())
                                            .foregroundStyle(isDeloaded ? .orange : .secondary)
                                    }
                                }
                            }

                            Button(action: startWorkout) {
                                Text("Start Workout")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.accentColor)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.top, 8)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Last session summary
                    if let last = lastSession {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Last Workout", systemImage: "clock")
                                .font(.caption)
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)

                            Text("Workout \(last.templateName) · \(last.date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.headline)

                            ForEach(last.sortedLogs) { log in
                                HStack {
                                    Text(log.exerciseName)
                                    Spacer()
                                    Text("\(formattedWeight(log.effectiveWeight)) lbs")
                                        .foregroundStyle(
                                            log.effectiveWeight < log.targetWeight ? .orange :
                                            log.wasSuccessful ? .green : .red
                                        )
                                        .font(.body.monospacedDigit())
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
            }
            .navigationTitle("Stronglifts 5×5")
            .fullScreenCover(item: $activeSession) { session in
                ActiveWorkoutView(
                    session: session,
                    template: nextTemplate,
                    onFinish: { finishWorkout(session: session) },
                    onCancel: { activeSession = nil }
                )
            }
            .alert("Strava Error", isPresented: .constant(stravaError != nil), presenting: stravaError) { _ in
                Button("OK") { stravaError = nil }
            } message: { error in
                Text(error.localizedDescription)
            }
        }
    }

    private func startWorkout() {
        guard let template = nextTemplate else { return }
        let session = WorkoutSession(templateName: template.name)

        for (i, exercise) in template.sortedExercises.enumerated() {
            let log = ExerciseLog(
                exerciseName: exercise.name,
                targetWeight: adjustedWeight(for: exercise),
                order: i
            )
            for setNum in 1...exercise.sets {
                log.setLogs.append(SetLog(setNumber: setNum, targetReps: exercise.reps))
            }
            session.exerciseLogs.append(log)
        }

        modelContext.insert(session)
        try? modelContext.save()
        HeartRateService.shared.startRecording()
        activeSession = session
    }

    private func finishWorkout(session: WorkoutSession) {
        let duration = Date.now.timeIntervalSince(session.date)
        session.isCompleted = true
        session.endTime = .now

        let hr = HeartRateService.shared.stopRecording()
        session.averageHeartRate = hr.average
        session.maxHeartRate = hr.max

        // Auto-progress: for each exercise that was fully successful, increment weight
        if templates.first(where: { $0.name == session.templateName }) != nil {
            for log in session.exerciseLogs {
                guard log.wasSuccessful else { continue }
                let effective = log.effectiveWeight
                for t in templates {
                    for ex in t.exercises where ex.name == log.exerciseName {
                        ex.currentWeight = effective + ex.increment
                    }
                }
            }
        }

        try? modelContext.save()
        activeSession = nil

        if strava.isConnected {
            Task {
                do { try await strava.postWorkout(session, duration: duration) }
                catch { stravaError = error }
            }
        }
    }

    private func formattedWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
    }
}
