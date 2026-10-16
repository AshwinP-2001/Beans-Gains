import SwiftUI
import SwiftData

struct CalendarReportView: View {

    @Environment(\.calendar) private var calendar

    @Query(sort: \SupplementLog.logDate)
    private var logs: [SupplementLog]

    @State private var displayedMonth = Calendar.current
        .dateInterval(of: .month, for: .now)?.start ?? .now

    @State private var selectedDate: Date = .now

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 4),
        count: 7
    )

    private var today: Date {
        calendar.startOfDay(for: .now)
    }

    private var loggedDays: Set<Date> {
        Set(logs.map { calendar.startOfDay(for: $0.logDate) })
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var weekdays: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = calendar.firstWeekday - 1

        return Array(symbols[offset...] + symbols[..<offset])
    }

    private var daysInMonth: [Date?] {
        guard let interval = calendar.dateInterval(
            of: .month,
            for: displayedMonth
        ) else {
            return []
        }

        let numberOfDays = calendar.range(
            of: .day,
            in: .month,
            for: displayedMonth
        )?.count ?? 0

        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leadingEmptyDays =
            (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(
            repeating: nil,
            count: leadingEmptyDays
        )

        for day in 0..<numberOfDays {
            if let date = calendar.date(
                byAdding: .day,
                value: day,
                to: interval.start
            ) {
                days.append(date)
            }
        }

        return days
    }

    private var selectedLogs: [SupplementLog] {
        logs.filter {
            calendar.isDate($0.logDate, inSameDayAs: selectedDate)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                // Month navigation
                HStack {
                    Button {
                        changeMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Previous month")

                    Spacer()

                    Text(monthTitle)
                        .font(.title3.bold())

                    Spacer()

                    Button {
                        changeMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .accessibilityLabel("Next month")
                }
                .padding(.horizontal)

                // Weekday headings
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(weekdays.enumerated()), id: \.offset) {
                        _, weekday in

                        Text(weekday)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)

                // Calendar days
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(daysInMonth.enumerated()), id: \.offset) {
                        _, date in

                        if let date {
                            dayCell(date)
                        } else {
                            Color.clear
                                .frame(height: 44)
                        }
                    }
                }
                .padding(.horizontal)

                // Legend
                HStack(spacing: 16) {
                    legend(color: .green, text: "Logged")
                    legend(color: .red, text: "Missed")
                    legend(color: .gray, text: "Future")
                }
                .font(.caption)
                .padding(.top, 4)

                Divider()

                // Selected date details
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(selectedDate.formatted(
                            .dateTime.weekday(.wide).day().month(.wide).year()
                        ))
                        .font(.headline)

                        if selectedLogs.isEmpty {
                            Text(
                                selectedDate > today
                                ? "Future date — nothing logged yet."
                                : calendar.isDate(
                                    selectedDate,
                                    inSameDayAs: today
                                )
                                ? "No check-in logged for today yet."
                                : "No check-in was logged on this date."
                            )
                            .foregroundStyle(.secondary)
                        } else {
                            ForEach(selectedLogs) { log in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Creatine: \(log.dailyCreatine ? "Yes" : "No")")
                                    Text("Zinc: \(log.zincIntake ? "Yes" : "No")")

                                    if !log.workoutRoutine.isEmpty {
                                        Text("Workout: \(log.workoutRoutine)")
                                    }

                                    if !log.dailyFeeling.isEmpty {
                                        Text("Feeling: \(log.dailyFeeling)")
                                    }
                                }
                                .padding()
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                                .background(
                                    Color.secondary.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }

                Spacer(minLength: 0)
            }
            .padding(.top)
            .navigationTitle("Calendar Report")
        }
    }

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let day = calendar.startOfDay(for: date)
        let isLogged = loggedDays.contains(day)
        let isFuture = day > today
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(day, inSameDayAs: today)

        Button {
            selectedDate = day
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline)

                Circle()
                    .fill(
                        isLogged ? Color.green :
                            isFuture ? Color.gray.opacity(0.35) :
                            Color.red
                    )
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.18))
                }
            }
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            date.formatted(date: .complete, time: .omitted)
        )
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(text)
        }
    }

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(
            byAdding: .month,
            value: value,
            to: displayedMonth
        ) else {
            return
        }

        displayedMonth = newMonth
    }
}
