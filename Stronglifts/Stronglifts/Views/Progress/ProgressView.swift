import SwiftUI
import SwiftData
import Charts

struct WorkoutProgressView: View {
    @Query private var sessions: [WorkoutSession]

    @State private var selectedExercise: String = ""
    @State private var selectedDate: Date? = nil

    private var allExerciseNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for session in sessions {
            for log in session.sortedLogs {
                if seen.insert(log.exerciseName).inserted {
                    result.append(log.exerciseName)
                }
            }
        }
        return result
    }

    private var chartData: [(date: Date, weight: Double)] {
        sessions
            .sorted { $0.date < $1.date }
            .compactMap { session -> (Date, Double)? in
                guard let log = session.exerciseLogs.first(where: { $0.exerciseName == selectedExercise }) else { return nil }
                return (session.date, log.targetWeight)
            }
    }

    private var selectedPoint: (date: Date, weight: Double)? {
        guard let selectedDate else { return nil }
        return chartData.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
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
                    .padding(.vertical, 12)

                    if chartData.count < 2 {
                        ContentUnavailableView(
                            "Not enough data",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("Log at least 2 workouts with \(selectedExercise) to see a chart.")
                        )
                    } else {
                        Chart(chartData, id: \.date) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Weight", point.weight)
                            )
                            .foregroundStyle(Color.accentColor)
                            .interpolationMethod(.linear)

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Weight", point.weight)
                            )
                            .foregroundStyle(Color.accentColor)
                            .symbolSize(selectedPoint?.date == point.date ? 120 : 50)

                            if let sp = selectedPoint, sp.date == point.date {
                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("Weight", point.weight)
                                )
                                .foregroundStyle(Color.primary)
                                .annotation(position: .top, spacing: 6) {
                                    VStack(spacing: 2) {
                                        Text("\(Int(point.weight)) lbs")
                                            .font(.caption.bold())
                                        Text(point.date.formatted(.dateTime.month(.abbreviated).day().year()))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
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
                                        Text("\(Int(v)) lbs")
                                    }
                                }
                                AxisGridLine()
                            }
                        }
                        .frame(height: 280)
                        .padding()

                        if let last = chartData.last, let first = chartData.first {
                            HStack(spacing: 32) {
                                statView(label: "Start", value: "\(Int(first.weight)) lbs")
                                statView(label: "Current", value: "\(Int(last.weight)) lbs")
                                statView(label: "Gain", value: "+\(Int(last.weight - first.weight)) lbs")
                            }
                            .padding()
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
        }
    }

    private func statView(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
