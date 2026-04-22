import Testing
import SwiftData
import Foundation
@testable import Stronglifts

// MARK: - Helpers

/// In-memory SwiftData container for model tests.
@MainActor
func makeContainer() throws -> ModelContainer {
    let schema = Schema([
        WorkoutTemplate.self, ExerciseTemplate.self,
        WorkoutSession.self, ExerciseLog.self, SetLog.self,
    ])
    return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
}

// MARK: - DeloadCalculator

@Suite("DeloadCalculator") struct DeloadCalculatorTests {

    @Test("No deload within normal gap (0 days)") func zeroDays() {
        #expect(DeloadCalculator.adjustedWeight(currentWeight: 135, increment: 5, daysSinceLastWorkout: 0) == 135)
    }

    @Test("No deload within normal gap (7 days)") func sevenDays() {
        #expect(DeloadCalculator.adjustedWeight(currentWeight: 135, increment: 5, daysSinceLastWorkout: 7) == 135)
    }

    @Test("No deload at boundary (11 days)") func elevenDays() {
        #expect(DeloadCalculator.adjustedWeight(currentWeight: 135, increment: 5, daysSinceLastWorkout: 11) == 135)
    }

    @Test("1-step deload at boundary (12 days)") func twelveDays() {
        // currentWeight=135, increment=5 → planned was 130, repeat it
        #expect(DeloadCalculator.adjustedWeight(currentWeight: 135, increment: 5, daysSinceLastWorkout: 12) == 130)
    }

    @Test("1-step deload mid-range (15 days)") func fifteenDays() {
        #expect(DeloadCalculator.adjustedWeight(currentWeight: 135, increment: 5, daysSinceLastWorkout: 15) == 130)
    }

    @Test("1-step deload at upper boundary (19 days)") func nineteenDays() {
        #expect(DeloadCalculator.adjustedWeight(currentWeight: 135, increment: 5, daysSinceLastWorkout: 19) == 130)
    }

    @Test("2-step deload at boundary (20 days)") func twentyDays() {
        #expect(DeloadCalculator.adjustedWeight(currentWeight: 135, increment: 5, daysSinceLastWorkout: 20) == 125)
    }

    @Test("2-step deload at upper boundary (27 days)") func twentySevenDays() {
        #expect(DeloadCalculator.adjustedWeight(currentWeight: 135, increment: 5, daysSinceLastWorkout: 27) == 125)
    }

    @Test("3-step deload at boundary (28 days)") func twentyEightDays() {
        #expect(DeloadCalculator.adjustedWeight(currentWeight: 135, increment: 5, daysSinceLastWorkout: 28) == 120)
    }

    @Test("3-step deload for very long gap (90 days)") func ninetyDays() {
        #expect(DeloadCalculator.adjustedWeight(currentWeight: 135, increment: 5, daysSinceLastWorkout: 90) == 120)
    }

    @Test("Larger increment (10 lbs, squat)") func largerIncrement() {
        // currentWeight=200, increment=10, 20+ days → 2 steps → 200 - 20 = 180
        #expect(DeloadCalculator.adjustedWeight(currentWeight: 200, increment: 10, daysSinceLastWorkout: 20) == 180)
    }

    // MARK: Barbell floor (core lifts)

    @Test("Barbell: floor at 45 lbs, never below bar") func barbellFloor() {
        // currentWeight=55, increment=10, very long gap → 55 - 30 = 25, floored to 45
        #expect(DeloadCalculator.adjustedWeight(currentWeight: 55, increment: 10, daysSinceLastWorkout: 60, isBarbell: true) == 45)
    }

    @Test("Barbell: 135 lbs with long gap deloads normally") func barbellNormalDeload() {
        // 135 - 3*10 = 105, above bar floor
        #expect(DeloadCalculator.adjustedWeight(currentWeight: 135, increment: 10, daysSinceLastWorkout: 60, isBarbell: true) == 105)
    }

    @Test("Barbell: at bar weight stays at bar weight") func barbellAtBar() {
        // currentWeight=45 (just the bar), long gap → 45 - 30 = 15, floored to 45
        #expect(DeloadCalculator.adjustedWeight(currentWeight: 45, increment: 10, daysSinceLastWorkout: 60, isBarbell: true) == 45)
    }

    // MARK: Non-barbell floor (added-weight / bodyweight exercises)

    @Test("Bodyweight exercise (0 lbs) stays at 0 after long gap") func bodyweightZero() {
        // Pull-ups with no added weight: 0 - 3*5 = -15, floored to 0
        #expect(DeloadCalculator.adjustedWeight(currentWeight: 0, increment: 5, daysSinceLastWorkout: 60, isBarbell: false) == 0)
    }

    @Test("Added-weight exercise (curls 40 lbs) deloads correctly") func addedWeightCurls() {
        // 40 - 1*5 = 35 after ~2 weeks
        #expect(DeloadCalculator.adjustedWeight(currentWeight: 40, increment: 5, daysSinceLastWorkout: 15, isBarbell: false) == 35)
    }

    @Test("Added-weight exercise floors at 0, not increment") func addedWeightFloor() {
        // currentWeight=5, increment=5, long gap → 5 - 15 = -10, floored to 0 (not 5)
        #expect(DeloadCalculator.adjustedWeight(currentWeight: 5, increment: 5, daysSinceLastWorkout: 60, isBarbell: false) == 0)
    }

    @Test("No-increment bodyweight exercise unchanged") func noIncrement() {
        // Pull-ups tracked as bodyweight, increment=0 → deload has no effect
        #expect(DeloadCalculator.adjustedWeight(currentWeight: 0, increment: 0, daysSinceLastWorkout: 60, isBarbell: false) == 0)
    }
}

// MARK: - ExerciseLog.effectiveWeight

@Suite("ExerciseLog effectiveWeight") struct EffectiveWeightTests {

    @Test("No completed sets returns targetWeight") @MainActor func noCompletedSets() throws {
        let container = try makeContainer()
        let log = ExerciseLog(exerciseName: "Squat", targetWeight: 135, order: 0)
        container.mainContext.insert(log)
        log.setLogs = [
            SetLog(setNumber: 1, targetReps: 5),
            SetLog(setNumber: 2, targetReps: 5),
        ]
        // Nothing completed — effectiveWeight should fall back to targetWeight
        #expect(log.effectiveWeight == 135)
    }

    @Test("All sets completed at target weight") @MainActor func allAtTarget() throws {
        let container = try makeContainer()
        let log = ExerciseLog(exerciseName: "Squat", targetWeight: 135, order: 0)
        container.mainContext.insert(log)
        for i in 1...5 {
            let set = SetLog(setNumber: i, targetReps: 5)
            set.isCompleted = true
            // weight nil → uses targetWeight
            log.setLogs.append(set)
        }
        #expect(log.effectiveWeight == 135)
    }

    @Test("One set at lower weight returns that weight") @MainActor func oneSetLower() throws {
        let container = try makeContainer()
        let log = ExerciseLog(exerciseName: "Squat", targetWeight: 135, order: 0)
        container.mainContext.insert(log)
        let set1 = SetLog(setNumber: 1, targetReps: 5)
        set1.isCompleted = true
        set1.weight = 135

        let set2 = SetLog(setNumber: 2, targetReps: 5)
        set2.isCompleted = true
        set2.weight = 115  // dropped weight on second set

        log.setLogs = [set1, set2]
        #expect(log.effectiveWeight == 115)
    }

    @Test("Failed set with nil weight still counts as targetWeight") @MainActor func failedSet() throws {
        let container = try makeContainer()
        let log = ExerciseLog(exerciseName: "Bench Press", targetWeight: 135, order: 0)
        container.mainContext.insert(log)
        let set = SetLog(setNumber: 1, targetReps: 5)
        set.isCompleted = true
        set.failed = true
        // weight nil → counts as targetWeight in effectiveWeight
        log.setLogs = [set]
        #expect(log.effectiveWeight == 135)
    }

    @Test("Mixed: some sets with custom weight, some nil") @MainActor func mixedWeights() throws {
        let container = try makeContainer()
        let log = ExerciseLog(exerciseName: "Squat", targetWeight: 135, order: 0)
        container.mainContext.insert(log)
        let set1 = SetLog(setNumber: 1, targetReps: 5)
        set1.isCompleted = true
        set1.weight = nil  // 135

        let set2 = SetLog(setNumber: 2, targetReps: 5)
        set2.isCompleted = true
        set2.weight = 125  // dropped

        log.setLogs = [set1, set2]
        // effectiveWeight = min(135, 125) = 125
        #expect(log.effectiveWeight == 125)
    }
}

// MARK: - ExerciseLog.wasSuccessful

@Suite("ExerciseLog wasSuccessful") struct WasSuccessfulTests {

    @Test("Empty set logs → false") @MainActor func emptyLogs() throws {
        let container = try makeContainer()
        let log = ExerciseLog(exerciseName: "Squat", targetWeight: 135, order: 0)
        container.mainContext.insert(log)
        #expect(log.wasSuccessful == false)
    }

    @Test("All completed, none failed → true") @MainActor func allSuccess() throws {
        let container = try makeContainer()
        let log = ExerciseLog(exerciseName: "Squat", targetWeight: 135, order: 0)
        container.mainContext.insert(log)
        for i in 1...5 {
            let set = SetLog(setNumber: i, targetReps: 5)
            set.isCompleted = true
            set.failed = false
            log.setLogs.append(set)
        }
        #expect(log.wasSuccessful == true)
    }

    @Test("One failed set → false") @MainActor func oneFailed() throws {
        let container = try makeContainer()
        let log = ExerciseLog(exerciseName: "Squat", targetWeight: 135, order: 0)
        container.mainContext.insert(log)
        let set1 = SetLog(setNumber: 1, targetReps: 5)
        set1.isCompleted = true
        set1.failed = false

        let set2 = SetLog(setNumber: 2, targetReps: 5)
        set2.isCompleted = true
        set2.failed = true

        log.setLogs = [set1, set2]
        #expect(log.wasSuccessful == false)
    }

    @Test("Incomplete set → false") @MainActor func incompleteSet() throws {
        let container = try makeContainer()
        let log = ExerciseLog(exerciseName: "Squat", targetWeight: 135, order: 0)
        container.mainContext.insert(log)
        let set1 = SetLog(setNumber: 1, targetReps: 5)
        set1.isCompleted = true

        let set2 = SetLog(setNumber: 2, targetReps: 5)
        set2.isCompleted = false  // not done yet

        log.setLogs = [set1, set2]
        #expect(log.wasSuccessful == false)
    }
}

// MARK: - WarmupCalculator

@Suite("WarmupCalculator") struct WarmupCalculatorTests {

    @Test("Working weight at bar → no warmup sets") func atBarWeight() {
        #expect(WarmupCalculator.sets(for: 45).isEmpty)
    }

    @Test("Working weight below bar → no warmup sets") func belowBar() {
        #expect(WarmupCalculator.sets(for: 25).isEmpty)
    }

    @Test("Working weight just above bar includes bar set") func justAboveBar() {
        let sets = WarmupCalculator.sets(for: 50)
        #expect(sets.first?.weight == 45)
        #expect(sets.first?.label == "Bar")
    }

    @Test("135 lbs produces correct warmup progression") func squat135() {
        // 40% = 54 → 55, 60% = 81 → 80, 80% = 108 → 110
        let sets = WarmupCalculator.sets(for: 135)
        let weights = sets.map(\.weight)
        #expect(weights.contains(45))   // bar
        #expect(weights.contains(55))   // 40%
        #expect(weights.contains(80))   // 60%
        #expect(weights.contains(110))  // 80%
    }

    @Test("All warmup weights are multiples of 5") func multiplesOf5() {
        for workingWeight in stride(from: 50.0, through: 300.0, by: 5.0) {
            let sets = WarmupCalculator.sets(for: workingWeight)
            for set in sets {
                #expect(set.weight.truncatingRemainder(dividingBy: 5) == 0,
                        "Weight \(set.weight) for working weight \(workingWeight) is not a multiple of 5")
            }
        }
    }

    @Test("All warmup weights are below working weight") func belowWorking() {
        for workingWeight in stride(from: 50.0, through: 300.0, by: 5.0) {
            let sets = WarmupCalculator.sets(for: workingWeight)
            for set in sets {
                #expect(set.weight < workingWeight,
                        "Warmup weight \(set.weight) >= working weight \(workingWeight)")
            }
        }
    }

    @Test("All warmup weights are at least bar weight") func atLeastBar() {
        for workingWeight in stride(from: 50.0, through: 300.0, by: 5.0) {
            let sets = WarmupCalculator.sets(for: workingWeight)
            for set in sets {
                #expect(set.weight >= WarmupCalculator.barWeight,
                        "Warmup weight \(set.weight) is below bar weight for working weight \(workingWeight)")
            }
        }
    }

    @Test("isCore matches expected exercises") func coreExercises() {
        #expect(WarmupCalculator.isCore("Squat"))
        #expect(WarmupCalculator.isCore("Deadlift"))
        #expect(WarmupCalculator.isCore("Bench Press"))
        #expect(WarmupCalculator.isCore("Overhead Press"))
        #expect(WarmupCalculator.isCore("Barbell Row"))
        #expect(!WarmupCalculator.isCore("Pull-ups"))
        #expect(!WarmupCalculator.isCore("Dips"))
    }

    @Test("isCore is case-insensitive") func coreCaseInsensitive() {
        #expect(WarmupCalculator.isCore("squat"))
        #expect(WarmupCalculator.isCore("DEADLIFT"))
        #expect(WarmupCalculator.isCore("bench press"))
    }
}

// MARK: - PlateCalculator

@Suite("PlateCalculator") struct PlateCalculatorTests {

    @Test("Below bar weight returns nil") func belowBar() {
        #expect(PlateCalculator.calculate(totalWeight: 20) == nil)
    }

    @Test("Exactly bar weight returns empty plates") func exactlyBar() {
        let result = PlateCalculator.calculate(totalWeight: 45)
        #expect(result != nil)
        #expect(result?.plates.isEmpty == true)
        #expect(result?.isExact == true)
    }

    @Test("95 lbs = bar + 1×25 per side") func ninetyFive() {
        let result = PlateCalculator.calculate(totalWeight: 95)
        #expect(result?.isExact == true)
        let plates = result?.plates.map(\.weight) ?? []
        #expect(plates == [25])
    }

    @Test("135 lbs = bar + 1×45 per side") func oneThirtyFive() {
        let result = PlateCalculator.calculate(totalWeight: 135)
        #expect(result?.isExact == true)
        let plates = result?.plates.map(\.weight) ?? []
        #expect(plates == [45])
    }

    @Test("185 lbs = bar + 1×45 + 1×25 per side") func oneEightyFive() {
        // (185 - 45) / 2 = 70 per side → 45 + 25
        let result = PlateCalculator.calculate(totalWeight: 185)
        #expect(result?.isExact == true)
        let plates = result?.plates.map(\.weight) ?? []
        #expect(plates == [45, 25])
    }

    @Test("225 lbs = bar + 1×45 + 1×35 + 1×10 per side") func twoTwentyFive() {
        // (225 - 45) / 2 = 90 per side → 45 + 35 + 10
        let result = PlateCalculator.calculate(totalWeight: 225)
        #expect(result?.isExact == true)
        let plates = result?.plates.map(\.weight) ?? []
        #expect(plates == [45, 35, 10])
    }

    @Test("Unachievable weight is flagged as inexact") func inexact() {
        // 100 lbs: (100-45)/2 = 27.5 per side → 25 + 2.5 = 27.5 exact actually
        // Try something that can't be made: 86 lbs → (86-45)/2 = 20.5 per side
        // 10 + 5 + 2.5 = 17.5, not 20.5
        let result = PlateCalculator.calculate(totalWeight: 86)
        #expect(result?.isExact == false)
    }

    @Test("description returns 'Bar only' for bar weight") func descriptionBarOnly() {
        #expect(PlateCalculator.description(totalWeight: 45) == "Bar only")
    }

    @Test("description returns 'Below bar weight' for light weights") func descriptionBelowBar() {
        #expect(PlateCalculator.description(totalWeight: 20) == "Below bar weight")
    }
}
