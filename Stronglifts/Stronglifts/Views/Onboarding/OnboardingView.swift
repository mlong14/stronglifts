import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var templates: [WorkoutTemplate]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // Unique exercises across both templates (by name), preserving order of first appearance
    private var uniqueExercises: [ExerciseTemplate] {
        var seen = Set<String>()
        var result: [ExerciseTemplate] = []
        for template in templates.sorted(by: { $0.name < $1.name }) {
            for ex in template.sortedExercises {
                if seen.insert(ex.name).inserted {
                    result.append(ex)
                }
            }
        }
        return result
    }

    @State private var weightInputs: [String: String] = [:]
    @State private var currentIndex = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Text("Stronglifts 5×5")
                    .font(.largeTitle.bold())

                Text("Enter your starting weight for each exercise.\nIf you're new, use the bar (45 lbs).")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if !uniqueExercises.isEmpty {
                    let exercise = uniqueExercises[currentIndex]

                    VStack(spacing: 12) {
                        Text(exercise.name)
                            .font(.title2.bold())

                        HStack {
                            TextField("e.g. 45", text: binding(for: exercise.name))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .font(.title)
                                .frame(width: 120)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            Text("lbs")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }

                        Text("\(exercise.sets)×\(exercise.reps) · +\(formattedWeight(exercise.increment)) lbs/session")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()

                    // Progress dots
                    HStack(spacing: 8) {
                        ForEach(uniqueExercises.indices, id: \.self) { i in
                            Circle()
                                .fill(i <= currentIndex ? Color.accentColor : Color(.systemGray5))
                                .frame(width: 8, height: 8)
                        }
                    }
                }

                Spacer()

                Button(action: advance) {
                    Text(currentIndex < uniqueExercises.count - 1 ? "Next" : "Start Training")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(weightInputs[uniqueExercises[safe: currentIndex]?.name ?? ""] == nil)
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }

    private func binding(for name: String) -> Binding<String> {
        Binding(
            get: { weightInputs[name] ?? "" },
            set: { weightInputs[name] = $0 }
        )
    }

    private func advance() {
        guard currentIndex < uniqueExercises.count else { return }
        let exercise = uniqueExercises[currentIndex]
        let weight = Double(weightInputs[exercise.name] ?? "") ?? 45

        // Apply to all templates that contain this exercise name
        for template in templates {
            for ex in template.exercises where ex.name == exercise.name {
                ex.currentWeight = weight
            }
        }
        try? modelContext.save()

        if currentIndex < uniqueExercises.count - 1 {
            currentIndex += 1
        } else {
            hasCompletedOnboarding = true
        }
    }

    private func formattedWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
