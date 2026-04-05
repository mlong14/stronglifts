import SwiftUI

struct WarmupTarget: Identifiable, Hashable {
    let id = UUID()
    let exerciseName: String
    let workingWeight: Double
}

struct ExerciseWarmupView: View {
    let target: WarmupTarget
    @Environment(\.dismiss) private var dismiss

    @State private var warmupSets: [WarmupSet] = []
    @State private var completedIDs: Set<UUID> = []

    private var allDone: Bool {
        !warmupSets.isEmpty && warmupSets.allSatisfy { completedIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Working weight header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Working weight")
                            .font(.caption)
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                        Text("\(formattedWeight(target.workingWeight)) lbs")
                            .font(.title2.bold().monospacedDigit())
                    }
                    Spacer()
                    // Progress
                    Text("\(completedIDs.count)/\(warmupSets.count)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 16)

                // Warmup sets
                VStack(spacing: 0) {
                    ForEach(warmupSets) { warmupSet in
                        let done = completedIDs.contains(warmupSet.id)

                        HStack(spacing: 12) {
                            Text(warmupSet.label)
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)

                            Text("\(formattedWeight(warmupSet.weight)) lbs")
                                .font(.body.monospacedDigit())

                            Text("× \(warmupSet.reps)")
                                .font(.body)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                completedIDs.insert(warmupSet.id)
                            } label: {
                                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(done ? .green : Color.secondary)
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                            .disabled(done)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 14)
                        .background(done ? Color.clear : Color.clear)
                        .contentShape(Rectangle())

                        Divider().padding(.leading)
                    }
                }
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 16)
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("\(target.exerciseName) Warmup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            warmupSets = WarmupCalculator.sets(for: target.workingWeight)
        }
        .onChange(of: completedIDs) {
            if allDone {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }
        }
    }

    private func formattedWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
    }
}
