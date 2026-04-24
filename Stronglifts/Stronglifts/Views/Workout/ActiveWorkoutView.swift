import SwiftUI
import SwiftData
import Combine
import AudioToolbox

struct PlateCalcRequest: Identifiable {
    let id = UUID()
    let weight: Double
}

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    let template: WorkoutTemplate?
    let onFinish: () -> Void
    let onCancel: () -> Void

    @ObservedObject private var heartRate = HeartRateService.shared
    @Environment(\.scenePhase) private var scenePhase

    // Rest timer state
    @State private var restSecondsRemaining: Int = 0
    @State private var restEndDate: Date? = nil
    @State private var isResting = false
    @State private var nextSetAfterRest: SetLog?
    @State private var timerCancellable: AnyCancellable?

    // Sheets
    @State private var plateCalcRequest: PlateCalcRequest? = nil
    @State private var showAddExercise = false
    @State private var showFinishConfirm = false
    @State private var repEntryForFailed: SetLog? = nil

    // Warmup navigation
    @State private var warmupTarget: WarmupTarget? = nil

    static let defaultRestSeconds = 90

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Rest timer banner
                        if isResting {
                            RestTimerBanner(
                                secondsRemaining: restSecondsRemaining,
                                onSkip: { endRest(proxy: proxy) }
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Exercise sections
                        let firstIncompleteSet = session.sortedLogs.lazy
                            .flatMap { $0.sortedSets }
                            .first { !$0.isCompleted }
                        ForEach(session.sortedLogs) { log in
                            ExerciseSectionView(
                                log: log,
                                activeSet: isResting ? nextSetAfterRest : firstIncompleteSet,
                                onSetTapped: { set in handleSetTapped(set, proxy: proxy) },
                                onFailSet: failSet(_:),
                                onUndoSet: undoSet(_:),
                                onDeleteSet: deleteSet(_:),
                                onAddSet: { addSet(to: log) },
                                onDeleteExercise: WarmupCalculator.isCore(log.exerciseName) ? nil : { deleteExercise(log) },
                                onPlateCalc: { weight in
                                    plateCalcRequest = PlateCalcRequest(weight: weight)
                                },
                                onWarmup: WarmupCalculator.isCore(log.exerciseName) ? {
                                    warmupTarget = WarmupTarget(
                                        exerciseName: log.exerciseName,
                                        workingWeight: log.targetWeight,
                                        logID: log.persistentModelID
                                    )
                                } : nil
                            )
                            .id(log.id)
                        }

                        // Add exercise button
                        Button {
                            showAddExercise = true
                        } label: {
                            Label("Add Exercise", systemImage: "plus.circle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        syncRestTimerIfNeeded(proxy: proxy)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Workout \(session.templateName)")
                            .font(.headline)
                        HStack(spacing: 8) {
                            TimelineView(.periodic(from: session.date, by: 1)) { context in
                                Text(elapsedString(from: session.date, to: context.date))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            if let bpm = heartRate.currentBPM {
                                HStack(spacing: 2) {
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(.red)
                                    Text("\(bpm)")
                                        .monospacedDigit()
                                        .frame(minWidth: 28, alignment: .leading)
                                }
                                .font(.caption)
                            } else if heartRate.isScanning {
                                HStack(spacing: 2) {
                                    Image(systemName: "heart")
                                        .foregroundStyle(.secondary)
                                    Text("Searching…")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { showFinishConfirm = true }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .destructive) {
                        cancelWorkout()
                    }
                }
            }
            .sheet(item: $plateCalcRequest) { request in
                PlateCalculatorView(initialWeight: request.weight)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showAddExercise) {
                AddExerciseSheet { name, sets, reps, weight in
                    addExercise(name: name, sets: sets, reps: reps, weight: weight)
                }
                .presentationDetents([.medium, .large])
            }
            .confirmationDialog("Finish workout?", isPresented: $showFinishConfirm, titleVisibility: .visible) {
                Button("Finish & Save") { onFinish() }
                Button("Cancel", role: .cancel) {}
            } message: {
                let incomplete = session.exerciseLogs.flatMap { $0.setLogs }.filter { !$0.isCompleted }.count
                if incomplete > 0 {
                    Text("\(incomplete) set(s) not yet completed.")
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isResting)
            .sheet(item: $repEntryForFailed) { set in
                FailedRepsSheet(set: set)
                    .presentationDetents([.height(220)])
            }
            .navigationDestination(item: $warmupTarget) { target in
                if let log = session.exerciseLogs.first(where: { $0.persistentModelID == target.logID }) {
                    ExerciseWarmupView(target: target, log: log)
                }
            }
        }
    }

    // MARK: - Set handling

    private func handleSetTapped(_ set: SetLog, proxy: ScrollViewProxy) {
        guard !set.isCompleted else { return }

        set.isCompleted = true
        set.completedReps = set.targetReps
        try? modelContext.save()

        // Find the next incomplete set across all exercises
        let allSets = session.sortedLogs.flatMap { $0.sortedSets }
        let nextSet = allSets.first { !$0.isCompleted }

        startRest(nextSet: nextSet, proxy: proxy)
    }

    private func undoSet(_ set: SetLog) {
        set.isCompleted = false
        set.failed = false
        set.completedReps = 0
        try? modelContext.save()
    }

    private func failSet(_ set: SetLog) {
        guard !set.isCompleted else { return }
        set.isCompleted = true
        set.failed = true
        set.completedReps = 0
        try? modelContext.save()
        repEntryForFailed = set
    }

    private func startRest(nextSet: SetLog?, proxy: ScrollViewProxy) {
        nextSetAfterRest = nextSet
        let endDate = Date().addingTimeInterval(Double(Self.defaultRestSeconds))
        restEndDate = endDate
        restSecondsRemaining = Self.defaultRestSeconds
        isResting = true

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                let remaining = Int(endDate.timeIntervalSinceNow.rounded(.up))
                if remaining > 0 {
                    restSecondsRemaining = remaining
                } else {
                    endRest(proxy: proxy)
                }
            }
    }

    // Called when returning from background so the timer display snaps to reality.
    private func syncRestTimerIfNeeded(proxy: ScrollViewProxy) {
        guard isResting, let endDate = restEndDate else { return }
        let remaining = Int(endDate.timeIntervalSinceNow.rounded(.up))
        if remaining > 0 {
            restSecondsRemaining = remaining
        } else {
            endRest(proxy: proxy)
        }
    }

    private func endRest(proxy: ScrollViewProxy) {
        guard isResting else { return }
        timerCancellable?.cancel()
        timerCancellable = nil

        // Haptic + sound notification
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1013) // short chime
        isResting = false

        // Scroll to the log containing the next set
        if let next = nextSetAfterRest,
           let log = session.sortedLogs.first(where: { $0.setLogs.contains(where: { $0.id == next.id }) }) {
            withAnimation { proxy.scrollTo(log.id, anchor: .top) }
        }
        nextSetAfterRest = nil
    }

    // MARK: - Add set to existing exercise

    private func addSet(to log: ExerciseLog) {
        let setNumber = log.setLogs.count + 1
        let targetReps = log.sortedSets.last?.targetReps ?? 5
        log.setLogs.append(SetLog(setNumber: setNumber, targetReps: targetReps))
        try? modelContext.save()
    }

    // MARK: - Add exercise

    private func addExercise(name: String, sets: Int, reps: Int, weight: Double) {
        let order = session.exerciseLogs.count
        let log = ExerciseLog(exerciseName: name, targetWeight: weight, order: order)
        for setNum in 1...sets {
            log.setLogs.append(SetLog(setNumber: setNum, targetReps: reps))
        }
        session.exerciseLogs.append(log)
        try? modelContext.save()
    }

    // MARK: - Delete exercise

    private func deleteExercise(_ log: ExerciseLog) {
        session.exerciseLogs.removeAll { $0.id == log.id }
        modelContext.delete(log)
        try? modelContext.save()
    }

    // MARK: - Delete set

    private func deleteSet(_ set: SetLog) {
        if let log = session.sortedLogs.first(where: { $0.setLogs.contains(where: { $0.id == set.id }) }) {
            log.setLogs.removeAll { $0.id == set.id }
        }
        modelContext.delete(set)
        try? modelContext.save()
    }

    // MARK: - Elapsed timer

    private func elapsedString(from start: Date, to now: Date) -> String {
        let total = max(0, Int(now.timeIntervalSince(start)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }

    // MARK: - Cancel

    private func cancelWorkout() {
        timerCancellable?.cancel()
        HeartRateService.shared.stopRecording()
        modelContext.delete(session)
        try? modelContext.save()
        onCancel()
    }
}

// MARK: - Failed reps entry sheet

private struct FailedRepsSheet: View {
    @Bindable var set: SetLog
    @State private var text = ""
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("How many reps did you complete?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    TextField("0", text: $text)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 52, weight: .bold, design: .monospaced))
                        .frame(maxWidth: 160)
                    Text("reps")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
                Spacer()
            }
            .navigationTitle("Failed Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let v = Int(text) {
                            set.completedReps = v
                            try? modelContext.save()
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
