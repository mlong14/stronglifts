import Foundation

struct WarmupSet: Identifiable {
    let id = UUID()
    let weight: Double
    let reps: Int = 5
    let label: String
}

enum WarmupCalculator {
    static let barWeight: Double = 45

    static let coreExercises: Set<String> = [
        "Squat", "Deadlift", "Bench Press", "Overhead Press", "Barbell Row"
    ]

    static func isCore(_ name: String) -> Bool {
        coreExercises.contains { $0.lowercased() == name.lowercased() }
    }

    /// Returns warmup sets for a given working weight (all 5 reps each).
    /// Returns empty if working weight is at or below bar weight.
    static func sets(for workingWeight: Double) -> [WarmupSet] {
        guard workingWeight > barWeight else { return [] }

        var result: [WarmupSet] = []

        result.append(WarmupSet(weight: barWeight, label: "Bar"))

        let w40 = rounded(workingWeight * 0.40)
        if w40 > barWeight {
            result.append(WarmupSet(weight: w40, label: "40%"))
        }

        let w60 = rounded(workingWeight * 0.60)
        if w60 > w40 {
            result.append(WarmupSet(weight: w60, label: "60%"))
        }

        let w80 = rounded(workingWeight * 0.80)
        if w80 > w60 && w80 < workingWeight {
            result.append(WarmupSet(weight: w80, label: "80%"))
        }

        return result
    }

    private static func rounded(_ weight: Double) -> Double {
        (weight / 5).rounded() * 5
    }
}
