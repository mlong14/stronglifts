import SwiftUI

struct WorkoutSummaryView: View {
    let session: WorkoutSession
    let onDone: () -> Void

    @State private var appeared = false
    @State private var copied = false

    private var duration: String {
        guard let end = session.endTime else { return "" }
        let total = max(0, Int(end.timeIntervalSince(session.date)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    private var totalVolume: Int {
        session.exerciseLogs.reduce(0) { total, log in
            total + log.setLogs
                .filter { $0.isCompleted && !$0.failed }
                .reduce(0) { $0 + Int(Double($1.completedReps) * ($1.weight ?? log.targetWeight)) }
        }
    }

    private var completedSets: Int {
        session.exerciseLogs.flatMap(\.setLogs).filter { $0.isCompleted && !$0.failed }.count
    }

    private var totalSets: Int {
        session.exerciseLogs.flatMap(\.setLogs).count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {

                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.green)
                    }
                    .scaleEffect(appeared ? 1 : 0.3)
                    .opacity(appeared ? 1 : 0)

                    VStack(spacing: 4) {
                        Text("Workout \(session.templateName) Complete!")
                            .font(.title2.bold())
                        Text(session.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                }
                .padding(.top, 48)

                // Stats row
                HStack(spacing: 12) {
                    StatTile(value: duration, label: "Duration", icon: "clock")
                    StatTile(value: "\(completedSets)/\(totalSets)", label: "Sets", icon: "checkmark.circle")
                    if totalVolume > 0 {
                        StatTile(
                            value: totalVolume >= 1000
                                ? String(format: "%.1fk", Double(totalVolume) / 1000)
                                : "\(totalVolume)",
                            label: "Lbs Lifted",
                            icon: "scalemass"
                        )
                    }
                    if let bpm = session.averageHeartRate, bpm > 0 {
                        StatTile(value: "\(Int(bpm))", label: "Avg BPM", icon: "heart.fill", iconColor: .red)
                    }
                }
                .padding(.horizontal)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                // Exercise breakdown
                VStack(spacing: 0) {
                    ForEach(session.sortedLogs) { log in
                        ExerciseResultRow(log: log)
                        if log.id != session.sortedLogs.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                // Action row: copy for WHOOP + done
                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = session.clipboardText()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { copied = false }
                    } label: {
                        Label(copied ? "Copied!" : "Copy Workout", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundStyle(copied ? .green : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button(action: onDone) {
                        Text("Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
        }
    }
}

// MARK: - Stat tile

private struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    var iconColor: Color = .accentColor

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Exercise result row

private struct ExerciseResultRow: View {
    let log: ExerciseLog

    private var completedCount: Int { log.setLogs.filter { $0.isCompleted && !$0.failed }.count }
    private var totalCount: Int { log.setLogs.count }
    private var allSuccessful: Bool { log.wasSuccessful }

    private func formattedWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: allSuccessful ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(allSuccessful ? .green : .orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(log.exerciseName)
                    .font(.subheadline.bold())
                HStack(spacing: 4) {
                    Text("\(completedCount)/\(totalCount) sets")
                    Text("·")
                    Text("\(formattedWeight(log.effectiveWeight)) lbs")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Set dots
            HStack(spacing: 3) {
                ForEach(log.sortedSets) { set in
                    Circle()
                        .fill(dotColor(for: set))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func dotColor(for set: SetLog) -> Color {
        guard set.isCompleted else { return Color(.systemGray4) }
        if set.failed { return .red }
        return set.completedReps < set.targetReps ? .orange : .green
    }
}

// MARK: - Clipboard text generation

extension WorkoutSession {
    func clipboardText() -> String {
        var lines: [String] = []
        lines.append("Workout \(templateName) — \(date.formatted(date: .long, time: .omitted))")
        lines.append("")

        for log in sortedLogs {
            lines.append(log.exerciseName)

            // Warmup sets (barbell core exercises only)
            if WarmupCalculator.isCore(log.exerciseName) && log.warmupCompletedCount > 0 {
                let warmupSets = WarmupCalculator.sets(for: log.effectiveWeight)
                let done = warmupSets.prefix(log.warmupCompletedCount)
                if !done.isEmpty {
                    let str = done.map { ws in
                        "\(fmt(ws.weight)) lbs × \(ws.reps)"
                    }.joined(separator: ", ")
                    lines.append("  Warmup: \(str)")
                }
            }

            // Working sets (only those actually completed)
            let completedSets = log.sortedSets.filter { $0.isCompleted }
            if !completedSets.isEmpty {
                let str = completedSets.map { set in
                    let w = set.weight ?? log.effectiveWeight
                    let reps = set.completedReps > 0 ? set.completedReps : set.targetReps
                    return "\(fmt(w)) lbs × \(reps)\(set.failed ? " (failed)" : "")"
                }.joined(separator: ", ")
                lines.append("  Working: \(str)")
            }

            lines.append("")
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fmt(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
    }
}
