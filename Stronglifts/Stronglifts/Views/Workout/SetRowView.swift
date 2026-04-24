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
                Text("× \(setLog.completedReps)")
                    .font(.body)
                    .foregroundStyle(color)
            } else {
                Text("× \(setLog.targetReps)")
                    .font(.body)
                    .foregroundStyle(isNextUp ? .primary : .secondary)
            }

            Spacer()

            // Weight — tappable to override
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
        .onTapGesture {
            if setLog.isCompleted {
                repEditText = String(setLog.completedReps)
                showRepEdit = true
            } else if isNextUp {
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

    // Wheel picker selection — whole lbs + half-lb toggle
    @State private var selectedWhole: Int = 45
    @State private var selectedHalf: Bool = false

    private let wholeRange = Array(stride(from: 0, through: 500, by: 5))

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Picker("Pounds", selection: $selectedWhole) {
                        ForEach(wholeRange, id: \.self) { v in
                            Text("\(v)").tag(v)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Picker("Half", selection: $selectedHalf) {
                        Text(".0").tag(false)
                        Text(".5").tag(true)
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)

                    Text("lbs")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 16)
                }
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
                        let value = Double(selectedWhole) + (selectedHalf ? 0.5 : 0.0)
                        onSave(value)
                        dismiss()
                    }
                }
            }
            .onAppear {
                let current = Double(text) ?? 45.0
                let whole = Int(current / 5) * 5
                selectedWhole = wholeRange.contains(whole) ? whole : 45
                selectedHalf = current.truncatingRemainder(dividingBy: 1) >= 0.5
            }
        }
    }
}
