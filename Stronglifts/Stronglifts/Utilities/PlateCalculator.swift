import Foundation

/// Calculates plate combinations for a given barbell weight.
/// Plate inventory per side: 1×45, 1×35, 1×25, 1×10, 2×5, 1×2.5
enum PlateCalculator {
    // (weight, maxPerSide)
    static let inventory: [(weight: Double, maxPerSide: Int)] = [
        (45, 1), (35, 1), (25, 1), (10, 1), (5, 2), (2.5, 1)
    ]
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

        for (plate, maxCount) in inventory {
            guard remaining > 0 else { break }
            let count = min(maxCount, Int(remaining / plate))
            if count > 0 {
                plates.append((plate, count))
                remaining -= plate * Double(count)
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
