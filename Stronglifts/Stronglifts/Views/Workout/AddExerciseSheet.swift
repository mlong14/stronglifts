import SwiftUI
import SwiftData

struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    let onAdd: (String, Int, Int, Double) -> Void

    @State private var name = ""
    @State private var selectedSets = 3
    @State private var selectedReps = 5
    @State private var selectedWeight = 45.0
    @State private var showWeightPicker = false

    private struct ExerciseSummary: Identifiable {
        let id = UUID()
        let name: String
        let sets: Int
        let reps: Int
        let weight: Double
    }

    private var recentExercises: [ExerciseSummary] {
        var seen = Set<String>()
        var result: [ExerciseSummary] = []
        for session in sessions {
            for log in session.sortedLogs {
                guard seen.insert(log.exerciseName).inserted else { continue }
                let repsVal = log.sortedSets.first?.targetReps ?? 5
                result.append(ExerciseSummary(
                    name: log.exerciseName,
                    sets: log.setLogs.count,
                    reps: repsVal,
                    weight: log.effectiveWeight
                ))
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if !recentExercises.isEmpty {
                    Section("Recent") {
                        ForEach(recentExercises) { exercise in
                            Button {
                                name = exercise.name
                                selectedSets = exercise.sets
                                selectedReps = exercise.reps
                                let snapped = (exercise.weight / 5).rounded() * 5
                                let options = Array(stride(from: 0.0, through: 500.0, by: 5.0))
                                selectedWeight = options.contains(snapped) ? snapped : 45.0
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exercise.name)
                                            .foregroundStyle(.primary)
                                        Text("\(exercise.sets)×\(exercise.reps) @ \(formattedWeight(exercise.weight)) lbs")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if name == exercise.name {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                            .font(.caption.weight(.semibold))
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Exercise") {
                    TextField("Name (e.g. Pull-ups)", text: $name)
                }

                Section("Sets & Reps") {
                    HStack {
                        Text("Sets")
                        Spacer()
                        Picker("Sets", selection: $selectedSets) {
                            ForEach(1...10, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                    HStack {
                        Text("Reps")
                        Spacer()
                        Picker("Reps", selection: $selectedReps) {
                            ForEach(1...20, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Weight") {
                    HStack {
                        Text("Starting weight")
                        Spacer()
                        Button {
                            showWeightPicker = true
                        } label: {
                            Text("\(formattedWeight(selectedWeight)) lbs")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(
                            name.trimmingCharacters(in: .whitespaces),
                            selectedSets,
                            selectedReps,
                            selectedWeight
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showWeightPicker) {
                WeightEditSheet(
                    currentWeight: selectedWeight,
                    exerciseWeight: -1,  // no "exercise default" concept here
                    hasOverride: false
                ) { newWeight in
                    if let w = newWeight { selectedWeight = w }
                }
                .presentationDetents([.height(220)])
            }
        }
    }

    private func formattedWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
    }
}
