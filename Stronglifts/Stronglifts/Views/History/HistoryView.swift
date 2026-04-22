 import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [WorkoutSession]

    @State private var displayedMonth: Date = .now
    @State private var selectedSession: WorkoutSession?

    private var calendar: Calendar { .current }

    private var sessionsByDate: [DateComponents: WorkoutSession] {
        sessions.reduce(into: [:]) { dict, session in
            guard session.isCompleted else { return }
            let comps = calendar.dateComponents([.year, .month, .day], from: session.date)
            dict[comps] = session
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month navigation
                HStack {
                    Button {
                        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    } label: {
                        Image(systemName: "chevron.left")
                    }

                    Spacer()

                    Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.headline)

                    Spacer()

                    Button {
                        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month))
                }
                .padding()

                // Day-of-week headers — use index as ID since "T" and "S" appear twice
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(Array(calendar.veryShortWeekdaySymbols.enumerated()), id: \.offset) { _, day in
                        Text(day)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                // Calendar grid — use index as ID since nil padding days share the same value
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, date in
                        if let date = date {
                            let comps = calendar.dateComponents([.year, .month, .day], from: date)
                            let session = sessionsByDate[comps]
                            CalendarDayCell(
                                date: date,
                                session: session,
                                isSelected: selectedSession?.id == session?.id
                            )
                            .onTapGesture {
                                selectedSession = session
                            }
                        } else {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
                .padding(.horizontal)

                Divider()
                    .padding(.vertical)

                // Selected session detail
                if let session = selectedSession {
                    SessionDetailView(session: session, onDelete: {
                        deleteSession(session)
                    })
                } else {
                    Text("Tap a workout day to see details")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                Spacer()
            }
            .navigationTitle("History")
            .onAppear {
                let todayComps = calendar.dateComponents([.year, .month, .day], from: .now)
                selectedSession = sessionsByDate[todayComps]
            }
        }
    }

    private func deleteSession(_ session: WorkoutSession) {
        selectedSession = nil
        modelContext.delete(session)
        try? modelContext.save()
    }

    private func daysInMonth() -> [Date?] {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstDay = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let offset = firstWeekday - calendar.firstWeekday
        let leadingNils: [Date?] = Array(repeating: nil, count: (offset + 7) % 7)

        let days: [Date?] = range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }

        return leadingNils + days
    }
}

struct CalendarDayCell: View {
    let date: Date
    let session: WorkoutSession?
    let isSelected: Bool

    private var calendar: Calendar { .current }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    session != nil
                        ? (isSelected ? Color.accentColor : Color.accentColor.opacity(0.25))
                        : Color.clear
                )

            if calendar.isDateInToday(date) && session == nil {
                Circle().strokeBorder(Color.secondary, lineWidth: 1)
            }

            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(session != nil ? (isSelected ? .white : .primary) : .primary)

                if let s = session {
                    Text(s.templateName)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .accentColor)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct SessionDetailView: View {
    let session: WorkoutSession
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workout \(session.templateName) · \(session.date.formatted(date: .complete, time: .omitted))")
                        .font(.headline)
                    HStack(spacing: 8) {
                        Text(session.date.formatted(date: .omitted, time: .shortened))
                        if let end = session.endTime {
                            Text("→")
                            Text(end.formatted(date: .omitted, time: .shortened))
                            Text("·")
                            Text(durationString(from: session.date, to: end))
                        }
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal)

            ForEach(session.sortedLogs) { log in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(log.exerciseName).font(.subheadline.bold())
                        Spacer()
                        HStack(spacing: 2) {
                            if log.effectiveWeight < log.targetWeight {
                                Text("\(formattedWeight(log.effectiveWeight))")
                                    .foregroundStyle(.orange)
                                Text("/ \(formattedWeight(log.targetWeight))")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(formattedWeight(log.effectiveWeight))")
                            }
                            Text("lbs")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline.monospacedDigit())
                    }

                    HStack(spacing: 4) {
                        ForEach(log.sortedSets) { set in
                            Image(systemName: setIconName(set, targetWeight: log.targetWeight))
                                .foregroundStyle(setIconColor(set, targetWeight: log.targetWeight))
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .confirmationDialog("Delete this workout?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Workout \(session.templateName) on \(session.date.formatted(date: .abbreviated, time: .omitted)) will be permanently removed.")
        }
    }

    private func durationString(from start: Date, to end: Date) -> String {
        let total = max(0, Int(end.timeIntervalSince(start)))
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private func setIconName(_ set: SetLog, targetWeight: Double) -> String {
        if !set.isCompleted { return "circle" }
        if set.failed { return "xmark.circle.fill" }
        return "checkmark.circle.fill"
    }

    private func setIconColor(_ set: SetLog, targetWeight: Double) -> Color {
        if !set.isCompleted { return .secondary }
        if set.failed { return .red }
        let actual = set.weight ?? targetWeight
        return actual < targetWeight ? .orange : .green
    }

    private func formattedWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
    }
}
