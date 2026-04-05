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

    private var displayWeight: Double { setLog.weight ?? exerciseWeight }

    var body: some View {
        HStack(spacing: 12) {
            Text("Set \(setLog.setNumber)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)

            Text("× \(setLog.targetReps)")
                .font(.body)

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
                Button(action: onUndo) {
                    Image(systemName: setLog.failed ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(setLog.failed ? .red : .green)
                        .font(.title3)
                        .padding(.leading, 4)
                }
                .buttonStyle(.plain)
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
            if !setLog.isCompleted { onTap() }
        }
        .sheet(isPresented: $showWeightEdit) {
            WeightEditSheet(text: $weightEditText, hasOverride: setLog.weight != nil) { newWeight in
                setLog.weight = newWeight
            }
            .presentationDetents([.height(200)])
        }
    }

    private func formattedWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
    }
}

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
