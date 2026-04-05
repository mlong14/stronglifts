import SwiftUI

struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (String, Int, Int, Double) -> Void

    @State private var name = ""
    @State private var sets = "3"
    @State private var reps = "5"
    @State private var weight = ""

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(sets) != nil && Int(reps) != nil &&
        Double(weight) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
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
}
