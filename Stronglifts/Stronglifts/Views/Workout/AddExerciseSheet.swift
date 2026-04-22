import SwiftUI
import SwiftData

struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    // Most-recent sessions first so the first occurrence of each exercise name is the latest.
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    let onAdd: (String, Int, Int, Double) -> Void

    @State private var name = ""
    @State private var sets = "3"
    @State private var reps = "5"
    @State private var weight = ""

    private struct ExerciseSummary: Identifiable {
        let id = UUID()
        let name: String
        let sets: Int
        let reps: Int
        let weight: Double
    }

    /// One entry per unique exercise name, using the most recent session's stats.
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
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(sets) != nil && Int(reps) != nil &&
        Double(weight) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if !recentExercises.isEmpty {
                    Section("Recent") {
                        ForEach(recentExercises) { exercise in
                            Button {
                                name   = exercise.name
                                sets   = String(exercise.sets)
                                reps   = String(exercise.reps)
                                weight = formattedWeight(exercise.weight)
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
                        TextField("3", text: $sets)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    HStack {
                        Text("Reps")
                        Spacer()
                        TextField("5", text: $reps)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }

                Section("Weight") {
                    HStack {
                        TextField("0", text: $weight)
                            .keyboardType(.decimalPad)
                        Text("lbs")
                            .foregroundStyle(.secondary)
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
                            Int(sets) ?? 3,
                            Int(reps) ?? 5,
                            Double(weight) ?? 0
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func formattedWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
    }
}
