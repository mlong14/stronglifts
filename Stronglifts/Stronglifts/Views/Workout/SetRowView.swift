import SwiftUI

struct SetRowView: View {
    @Bindable var setLog: SetLog
    let exerciseWeight: Double
    let isNextUp: Bool
    let onTap: () -> Void
    let onFail: () -> Void
    let onUndo: () -> Void

    @State private var showWeightEdit = false
    @State private var weightEditText = ""
    @State private var showRepEdit = false
    @State private var repEditText = ""

    private var displayWeight: Double { setLog.weight ?? exerciseWeight }

    var body: some View {
        HStack(spacing: 12) {
            Text("Set \(setLog.setNumber)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)

            // Show actual completed reps (colored) when done, target reps when pending
            if setLog.isCompleted {
                let color: Color = setLog.failed ? .red
                    : setLog.completedReps < setLog.targetReps ? .orange
                    : .green
                Text("× \(setLog.completedReps)")
                    .font(.body)
                    .foregroundStyle(color)
            } else {
                Text("× \(setLog.targetReps)")
                    .font(.body)
            }

            Spacer()

            Button {
                weightEditText = formattedWeight(displayWeight)
                showWeightEdit = true
            } label: {
                Text("\(formattedWeight(displayWeight)) lbs")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(setLog.weight != nil ? .primary : .secondary)
                    .underline(setLog.weight != nil)
            }
            .buttonStyle(.plain)

            if setLog.isCompleted {
                // Static indicator — undo is via context menu, reps edit via row tap
                Image(systemName: setLog.failed ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(setLog.failed ? .red : .green)
                    .font(.title3)
                    .padding(.leading, 4)
            } else {
                HStack(spacing: 12) {
                    Button(action: onFail) {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.red.opacity(0.7))
                            .font(.title3)
                    }
                    Button(action: onTap) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(isNextUp ? Color.accentColor : Color.secondary)
                            .font(.title3)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(isNextUp && !setLog.isCompleted ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if setLog.isCompleted {
                // Tap a completed row to edit the actual rep count
                repEditText = String(setLog.completedReps)
                showRepEdit = true
            } else {
                onTap()
            }
        }
        .sheet(isPresented: $showWeightEdit) {
            WeightEditSheet(text: $weightEditText, hasOverride: setLog.weight != nil) { newWeight in
                setLog.weight = newWeight
            }
            .presentationDetents([.height(200)])
        }
        .sheet(isPresented: $showRepEdit) {
            RepEditSheet(text: $repEditText) { newReps in
                setLog.completedReps = newReps
            }
            .presentationDetents([.height(200)])
        }
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    TextField("Reps", text: $text)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 52, weight: .bold, design: .monospaced))
                        .frame(maxWidth: 160)
                    Text("reps")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)
                Spacer()
            }
            .navigationTitle("Edit Reps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let v = Int(text) { onSave(v) }
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Weight edit sheet

struct WeightEditSheet: View {
    @Binding var text: String
    let hasOverride: Bool
    let onSave: (Double?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    TextField("Weight", text: $text)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 52, weight: .bold, design: .monospaced))
                        .frame(maxWidth: 160)
                    Text("lbs")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)
                Spacer()
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
                        if let v = Double(text) { onSave(v) }
                        dismiss()
                    }
                }
            }
        }
    }
}
