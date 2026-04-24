import SwiftUI
import SwiftData

struct WarmupTarget: Identifiable, Hashable {
    let id = UUID()
    let exerciseName: String
    let workingWeight: Double
    let logID: PersistentIdentifier

    static func == (lhs: WarmupTarget, rhs: WarmupTarget) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ExerciseWarmupView: View {
    let target: WarmupTarget
    @Bindable var log: ExerciseLog
    @Environment(\.dismiss) private var dismiss

    private var warmupSets: [WarmupSet] {
        WarmupCalculator.sets(for: target.workingWeight)
    }

    private var allDone: Bool {
        !warmupSets.isEmpty && log.warmupCompletedCount >= warmupSets.count
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
                    Text("\(log.warmupCompletedCount)/\(warmupSets.count)")
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
                    ForEach(Array(warmupSets.enumerated()), id: \.offset) { index, warmupSet in
                        let done = index < log.warmupCompletedCount
                        let isNext = index == log.warmupCompletedCount

                        HStack(spacing: 12) {
                            Text(warmupSet.label)
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)

                            Text("\(formattedWeight(warmupSet.weight)) lbs")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(done ? .secondary : .primary)

                            Text("× \(warmupSet.reps)")
                                .font(.body)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                log.warmupCompletedCount = index + 1
                                if log.warmupCompletedCount >= warmupSets.count {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        dismiss()
                                    }
                                }
                            } label: {
                                Image(systemName: done ? "checkmark.circle.fill" : (isNext ? "checkmark.circle" : "circle"))
                                    .foregroundStyle(done ? .green : (isNext ? Color.accentColor : Color.secondary))
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                            .disabled(done || !isNext)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 14)
                        .background(isNext && !done ? Color.accentColor.opacity(0.07) : Color.clear)
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
    }

    private func formattedWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
    }
}
