import SwiftUI
import SwiftData
import Charts

struct WorkoutProgressView: View {
    @Query private var sessions: [WorkoutSession]

    @State private var selectedExercise: String = ""
    @State private var selectedDate: Date? = nil
    @State private var chartMode: ChartMode = .weight

    enum ChartMode: String, CaseIterable {
        case weight = "Weight"
        case volume = "Volume"
        case estimatedMax = "Est. 1RM"
    }

    private var completedSessions: [WorkoutSession] {
        sessions.filter { $0.isCompleted }.sorted { $0.date < $1.date }
    }

    private var allExerciseNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for session in completedSessions {
            for log in session.sortedLogs {
                if seen.insert(log.exerciseName).inserted {
                    result.append(log.exerciseName)
                }
            }
        }
        return result
    }

    private var chartData: [(date: Date, value: Double)] {
        completedSessions.compactMap { session -> (Date, Double)? in
            guard let log = session.exerciseLogs.first(where: { $0.exerciseName == selectedExercise }) else { return nil }
            let value: Double
            switch chartMode {
            case .weight:
                value = log.effectiveWeight
            case .volume:
                // total reps × weight across all completed sets
                let vol = log.setLogs
                    .filter { $0.isCompleted && !$0.failed }
                    .reduce(0.0) { $0 + Double($1.completedReps) * ($1.weight ?? log.targetWeight) }
                guard vol > 0 else { return nil }
                value = vol
            case .estimatedMax:
                // Epley: weight × (1 + reps / 30), take best set
                let best = log.setLogs
                    .filter { $0.isCompleted && !$0.failed && $0.completedReps > 0 }
                    .map { set -> Double in
                        let w = set.weight ?? log.targetWeight
                        return w * (1.0 + Double(set.completedReps) / 30.0)
                    }
                    .max()
                guard let best else { return nil }
                value = (best / 2.5).rounded() * 2.5  // round to nearest 2.5
            }
            return (session.date, value)
        }
    }

    private var selectedPoint: (date: Date, value: Double)? {
        guard let selectedDate else { return nil }
        return chartData.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    private var pr: Double? {
        chartData.map(\.value).max()
    }

    private var yAxisLabel: String {
        switch chartMode {
        case .weight: return "lbs"
        case .volume: return "lbs total"
        case .estimatedMax: return "lbs"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if allExerciseNames.isEmpty {
                    ContentUnavailableView(
                        "No workouts yet",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Complete a workout to see your progress.")
                    )
                } else {
                    // Exercise picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(allExerciseNames, id: \.self) { name in
                                Button(name) {
                                    selectedExercise = name
                                    selectedDate = nil
                                }
                                .buttonStyle(.bordered)
                                .tint(selectedExercise == name ? .primary : .secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)

                    // Chart mode picker
                    Picker("Chart", selection: $chartMode) {
                        ForEach(ChartMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    if chartData.count < 2 {
                        ContentUnavailableView(
                            "Not enough data",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("Log at least 2 workouts with \(selectedExercise).")
                        )
                    } else {
                        Chart(chartData, id: \.date) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value(yAxisLabel, point.value)
                            )
                            .foregroundStyle(Color.accentColor)
                            .interpolationMethod(.linear)

                            let isSelected = selectedPoint?.date == point.date
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value(yAxisLabel, point.value)
                            )
                            .foregroundStyle(isSelected ? Color.primary : Color.accentColor)
                            .symbolSize(isSelected ? 120 : 40)
                            .annotation(
                                position: .top,
                                alignment: .center,
                                spacing: 6,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                            ) {
                                if isSelected {
                                    VStack(spacing: 2) {
                                        Text(formattedValue(point.value))
                                            .font(.caption.bold())
                                        Text(point.date.formatted(.dateTime.month(.abbreviated).day().year()))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                        .chartXSelection(value: $selectedDate)
                        .chartXAxis {
                            AxisMarks { value in
                                if let date = value.as(Date.self) {
                                    AxisValueLabel {
                                        Text(date.formatted(.dateTime.month(.abbreviated).day()))
                                            .font(.caption2)
                                    }
                                }
                                AxisGridLine()
                            }
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let v = value.as(Double.self) {
                                        Text("\(Int(v))")
                                    }
                                }
                                AxisGridLine()
                            }
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 240)
                        .padding()

                        // Stats row
                        if let first = chartData.first, let last = chartData.last {
                            HStack(spacing: 12) {
                                statView(label: "Start", value: formattedValue(first.value))
                                statView(label: "Current", value: formattedValue(last.value))
                                statView(label: chartMode == .volume ? "Sessions" : "Gain",
                                         value: chartMode == .volume
                                            ? "\(chartData.count)"
                                            : "+\(Int(last.value - first.value)) lbs")
                                if let pr, chartMode != .volume {
                                    statView(label: "PR", value: formattedValue(pr), highlight: true)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                    }

                    Spacer()
                }
            }
            .navigationTitle("Progress")
            .onAppear {
                if selectedExercise.isEmpty, let first = allExerciseNames.first {
                    selectedExercise = first
                }
            }
            .onChange(of: selectedExercise) { _, _ in selectedDate = nil }
        }
    }

    private func statView(label: String, value: String, highlight: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(highlight ? Color.accentColor : .primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formattedValue(_ v: Double) -> String {
        switch chartMode {
        case .weight, .estimatedMax:
            return v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v)) lbs" : "\(v) lbs"
        case .volume:
            return v >= 1000 ? String(format: "%.1fk lbs", v / 1000) : "\(Int(v)) lbs"
        }
    }
}
