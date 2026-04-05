import SwiftUI

struct ExerciseSectionView: View {
    let log: ExerciseLog
    let activeSet: SetLog?
    let onSetTapped: (SetLog) -> Void
    let onFailSet: (SetLog) -> Void
    let onUndoSet: (SetLog) -> Void
    let onDeleteSet: (SetLog) -> Void
    let onDeleteExercise: (() -> Void)?   // nil = core exercise, not removable
    let onPlateCalc: (Double) -> Void
    let onWarmup: (() -> Void)?   // nil = not a core exercise, no warmup button

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(log.exerciseName)
                        .font(.headline)
                    Text("\(formattedWeight(log.targetWeight)) lbs")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let onWarmup {
                    Button {
                        onWarmup()
                    } label: {
                        Text("Warmup")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                }
                Button {
                    onPlateCalc(log.targetWeight)
                } label: {
                    Image(systemName: "circle.grid.2x2")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contextMenu {
                if let onDeleteExercise {
                    Button(role: .destructive) {
                        onDeleteExercise()
                    } label: {
                        Label("Remove Exercise", systemImage: "trash")
                    }
                }
            }

            Divider()

            // Sets
            ForEach(log.sortedSets) { set in
                SetRowView(
                    setLog: set,
                    exerciseWeight: log.targetWeight,
                    isNextUp: activeSet?.id == set.id,
                    onTap: { onSetTapped(set) },
                    onFail: { onFailSet(set) },
                    onUndo: { onUndoSet(set) }
                )
                .contextMenu {
                    Button(role: .destructive) {
                        onDeleteSet(set)
                    } label: {
                        Label("Remove Set", systemImage: "trash")
                    }
                }
                Divider().padding(.leading)
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private func formattedWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
    }
}
