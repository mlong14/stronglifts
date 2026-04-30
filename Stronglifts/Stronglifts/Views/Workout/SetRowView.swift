import SwiftUI

struct SetRowView: View {
    @Bindable var setLog: SetLog
    let exerciseWeight: Double
    let isNextUp: Bool
    let onTap: () -> Void
    let onFail: () -> Void
    let onUndo: () -> Void

    @State private var showWeightEdit = false
    @State private var showRepEdit = false
    @State private var repEditText = ""

    private var displayWeight: Double { setLog.weight ?? exerciseWeight }
    // True override = user explicitly set a different weight than the exercise weight
    private var hasOverride: Bool { setLog.weight != nil && setLog.weight != exerciseWeight }

    var body: some View {
        HStack(spacing: 14) {
            // State badge — number when pending, icon when done
            ZStack {
                Circle()
                    .fill(badgeColor)
                    .frame(width: 30, height: 30)
                if setLog.isCompleted {
                    Image(systemName: setLog.failed ? "xmark" : "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(setLog.setNumber)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(isNextUp ? .white : Color(.label))
                }
            }

            // Rep count
            if setLog.isCompleted {
                let color: Color = setLog.failed ? .red
                    : setLog.completedReps < setLog.targetReps ? .orange
                    : .green
                Button {
                    repEditText = String(setLog.completedReps)
                    showRepEdit = true
                } label: {
                    Text("× \(setLog.completedReps)")
                        .font(.body)
                        .foregroundStyle(color)
                }
                .buttonStyle(.plain)
            } else {
                Text("× \(setLog.targetReps)")
                    .font(.body)
                    .foregroundStyle(isNextUp ? .primary : .secondary)
            }

            Spacer()

            // Weight — tappable to override
            Button {
                showWeightEdit = true
            } label: {
                Text("\(formattedWeight(displayWeight)) lbs")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(hasOverride ? .primary : .secondary)
                    .underline(hasOverride)
            }
            .buttonStyle(.plain)

            // Completed set: undo button
            if setLog.isCompleted {
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            // Action buttons — only on the next pending set
            if !setLog.isCompleted && isNextUp {
                HStack(spacing: 20) {
                    Button(action: onFail) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red.opacity(0.8))
                            .font(.title2)
                    }
                    Button(action: onTap) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.title2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(isNextUp && !setLog.isCompleted ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .sheet(isPresented: $showWeightEdit) {
            WeightEditSheet(
                currentWeight: displayWeight,
                exerciseWeight: exerciseWeight,
                hasOverride: hasOverride
            ) { newWeight in
                setLog.weight = newWeight
            }
            .presentationDetents([.height(220)])
        }
        .sheet(isPresented: $showRepEdit) {
            RepEditSheet(text: $repEditText) { newReps in
                setLog.completedReps = newReps
            }
            .presentationDetents([.height(200)])
        }
    }

    private var badgeColor: Color {
        if setLog.isCompleted {
            if setLog.failed { return .red }
            return setLog.completedReps < setLog.targetReps ? .orange : .green
        }
        return isNextUp ? Color.accentColor : Color(.systemGray4)
    }

    private func formattedWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
    }
}

// MARK: - Rep edit sheet

struct RepEditSheet: View {
    @Binding var text: String
    let onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedReps: Int = 5

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("Reps", selection: $selectedReps) {
                    ForEach(0...30, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Text("reps")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 20)
            }
            .navigationTitle("Edit Reps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(selectedReps)
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedReps = Int(text) ?? 5
            }
        }
    }
}

// MARK: - Weight edit sheet (single wheel, 5 lb steps)

struct WeightEditSheet: View {
    let currentWeight: Double
    let exerciseWeight: Double
    let hasOverride: Bool
    let onSave: (Double?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedWeight: Double = 45

    private let weightOptions = Array(stride(from: 0.0, through: 500.0, by: 5.0))

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("Weight", selection: $selectedWeight) {
                    ForEach(weightOptions, id: \.self) { v in
                        Text(v == 0 ? "0" : "\(Int(v))").tag(v)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Text("lbs")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 20)
            }
            .navigationTitle("Set Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if hasOverride {
                        Button("Reset") {
                            onSave(nil)
                            dismiss()
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Pass nil (clear override) only when value matches exercise default.
                        // exerciseWeight < 0 means "no default" — always save the value.
                        if exerciseWeight >= 0 && selectedWeight == exerciseWeight {
                            onSave(nil)
                        } else {
                            onSave(selectedWeight)
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Snap to nearest 5 lb step
                let snapped = (currentWeight / 5).rounded() * 5
                selectedWeight = weightOptions.contains(snapped) ? snapped : exerciseWeight
            }
        }
    }
}
