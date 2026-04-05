import SwiftUI

struct PlateCalculatorView: View {
    @Environment(\.dismiss) private var dismiss

    @State var initialWeight: Double
    @State private var weightText: String
    @State private var barWeight: Double = 45

    init(initialWeight: Double = 135) {
        self.initialWeight = initialWeight
        self._weightText = State(initialValue: formattedWeight(initialWeight))
    }

    private var targetWeight: Double {
        Double(weightText) ?? 0
    }

    private var combo: PlateCalculator.PlateCombo? {
        PlateCalculator.calculate(totalWeight: targetWeight, barWeight: barWeight)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                // Weight input
                VStack(spacing: 8) {
                    Text("Total Weight")
                        .font(.caption)
                                .textCase(.uppercase)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        TextField("135", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .frame(maxWidth: 160)

                        Text("lbs")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Bar weight picker
                VStack(spacing: 8) {
                    Text("Bar Weight")
                        .font(.caption)
                                .textCase(.uppercase)
                        .foregroundStyle(.secondary)

                    Picker("Bar", selection: $barWeight) {
                        ForEach(PlateCalculator.barOptions, id: \.self) { w in
                            Text("\(Int(w)) lbs").tag(w)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                }

                Divider()

                // Plate result
                VStack(spacing: 12) {
                    Text("Per Side")
                        .font(.caption)
                                .textCase(.uppercase)
                        .foregroundStyle(.secondary)

                    if let combo = combo {
                        if combo.plates.isEmpty {
                            Text("Bar only")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(combo.plates, id: \.weight) { plate in
                                    HStack {
                                        Circle()
                                            .fill(plateColor(plate.weight))
                                            .frame(width: 12, height: 12)
                                        Text("\(plate.count) × \(formattedWeight(plate.weight)) lbs")
                                            .font(.title3.monospacedDigit())
                                        Spacer()
                                    }
                                    .padding(.horizontal, 40)
                                }

                                if !combo.isExact {
                                    Label("Can't make exact weight with available plates", systemImage: "exclamationmark.triangle")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .padding(.top, 4)
                                }
                            }
                        }
                    } else {
                        Text("Weight must be ≥ bar weight")
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func plateColor(_ weight: Double) -> Color {
        switch weight {
        case 45: return .red
        case 35: return .blue
        case 25: return .green
        case 10: return .gray
        case 5:  return .orange
        default: return .white
        }
    }
}

private func formattedWeight(_ w: Double) -> String {
    w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
}
