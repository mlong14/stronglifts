import Foundation

/// Calculates plate combinations for a given barbell weight.
/// Fixed plate inventory: 2×45, 2×35, 2×25, 2×10, 2×5, 2×2.5 (1 of each per side).
enum PlateCalculator {
    static let availablePlates: [Double] = [45, 35, 25, 10, 5, 2.5]
    static let barOptions: [Double] = [45, 35, 25]

    struct PlateCombo {
        let plates: [(weight: Double, count: Int)]  // per side
        let isExact: Bool
    }

    /// Returns the plate combination per side for the given total weight.
    /// Uses a greedy algorithm; returns nil if weight is below bar weight.
    static func calculate(totalWeight: Double, barWeight: Double = 45) -> PlateCombo? {
        guard totalWeight >= barWeight else { return nil }

        var remaining = (totalWeight - barWeight) / 2
        var plates: [(Double, Int)] = []

        for plate in availablePlates {
            guard remaining > 0 else { break }
            // Max 1 of each plate per side (we own 2 total = 1 per side)
            if remaining >= plate {
                plates.append((plate, 1))
                remaining -= plate
            }
        }

        let isExact = remaining < 0.01
        return PlateCombo(plates: plates, isExact: isExact)
    }

    /// Formatted description of plates per side, e.g. "1×45 + 1×10"
    static func description(totalWeight: Double, barWeight: Double = 45) -> String {
        guard let combo = calculate(totalWeight: totalWeight, barWeight: barWeight) else {
            return "Below bar weight"
        }
        if combo.plates.isEmpty {
            return "Bar only"
        }
        let parts = combo.plates.map { "\($0.count)×\(formattedWeight($0.weight))" }
        let result = parts.joined(separator: " + ")
        return combo.isExact ? result : "\(result) (⚠️ can't make exact weight)"
    }

    static func formattedWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
    }
}
