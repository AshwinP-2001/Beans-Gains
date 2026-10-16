import SwiftUI
import SwiftData
import Charts

// MARK: - Creator Cloud Sync Models & Client
struct TrainingSessionModel {
    var date: Date
    var bodyWeight: Double
    var focusRegime: String
    var sets: [ExerciseSetModel]
}

struct ExerciseSetModel {
    var exerciseName: String
    var muscleGroup: String
    var weightKg: String
    var repsCount: String
    var durationMins: String = ""
    var setNumber: Int = 0
}

final class CreatorWorkoutClient {
    static let shared = CreatorWorkoutClient()
    private init() {}

    func syncWorkoutSession(session: TrainingSessionModel) async throws {
        // Placeholder sync client - connects to Zoho Creator API v2.1
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd-MMM-yyyy"
        let _ = formatter.string(from: session.date)

        // Simulating network sync task
        try await Task.sleep(nanoseconds: 100_000_000)
    }
}

// MARK: - Exercise Master Struct (Top Level)
struct ExerciseInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let muscleGroup: String
    let split: String // "Push", "Pull", "Legs"
}

// MARK: - Draft Set Struct
// Everything starts empty: nothing is auto-populated.

/// One row of the subform inside an exercise card (one set). The set number is its position in the card.
struct DraftSetRow: Identifiable {
    let id = UUID()
    var weightKg: String = ""
    var repsCount: String = ""
}

/// One exercise card: a single record with its set rows inside.
struct DraftSet: Identifiable {
    let id = UUID()
    var exerciseName: String = ""   // exercise name OR activity name
    var rows: [DraftSetRow] = [DraftSetRow()]
    var durationMins: String = ""   // only used for "Other Activities"
}

// MARK: - Personal Records (PR) Models & Calculation
struct PRRecord: Identifiable {
    let id = UUID()
    let exercise: String
    let muscleGroup: String
    let weightKg: Double
    let reps: Int
    let date: Date
}

enum PRCalculator {
    /// `a` beats `b` if it's heavier, or the same weight for more reps.
    static func beats(_ a: PRRecord, _ b: PRRecord) -> Bool {
        if a.weightKg != b.weightKg { return a.weightKg > b.weightKg }
        return a.reps > b.reps
    }

    /// Groups sets by exercise name (case-insensitive), keeping first-seen order.
    static func grouped(_ records: [PRRecord]) -> [[PRRecord]] {
        var order: [String] = []
        var buckets: [String: [PRRecord]] = [:]
        for record in records {
            let key = record.exercise.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(record)
        }
        return order.compactMap { buckets[$0] }
    }

    /// The record-breaking sets of one exercise, oldest first. Only each day's best set counts,
    /// so warm-up sets on the same day don't show up as PRs. The last item is the current PR.
    static func progression(_ records: [PRRecord], calendar: Calendar) -> [PRRecord] {
        var bestPerDay: [Date: PRRecord] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.date)
            if let existing = bestPerDay[day], !beats(record, existing) { continue }
            bestPerDay[day] = record
        }

        var result: [PRRecord] = []
        var current: PRRecord?
        for day in bestPerDay.keys.sorted() {
            guard let record = bestPerDay[day] else { continue }
            if let best = current, !beats(record, best) { continue }
            current = record
            result.append(record)
        }
        return result
    }
}

// MARK: - PR Banner Card (dumbbell + lightning)
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct PRBannerCard: View {
    let prCount: Int
    let action: () -> Void
    @State private var tapCount = 0

    var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 52, height: 52)
                    Image(systemName: "dumbbell.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .symbolEffect(.bounce, value: tapCount)
                    Image(systemName: "bolt.fill")
                        .font(.caption.bold())
                        .foregroundColor(.yellow)
                        .offset(x: 17, y: -17)
                        .symbolEffect(.pulse, options: .repeating)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Personal Records")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(prCount == 0
                         ? "Log lifts to set your first PR"
                         : "\(prCount) lift\(prCount == 1 ? "" : "s") • tap to view")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.orange, Color(red: 0.95, green: 0.35, blue: 0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topTrailing) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.12))
                    .rotationEffect(.degrees(14))
                    .offset(x: -34, y: -4)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.impact, trigger: tapCount)
    }
}

// MARK: - PR Report Popup
struct PRReportView: View {
    let records: [PRRecord]
    let calendar: Calendar
    let muscleGroups: [String]          // includes "All"
    @Binding var filter: String
    @Environment(\.dismiss) private var dismiss

    private struct ExercisePR: Identifiable {
        let name: String
        let muscleGroup: String
        let progression: [PRRecord]     // oldest -> newest
        let current: PRRecord           // the PR right now
        var id: String { name.lowercased() }
    }

    private var exercisePRs: [ExercisePR] {
        PRCalculator.grouped(records).compactMap { group -> ExercisePR? in
            let progression = PRCalculator.progression(group, calendar: calendar)
            guard let current = progression.last else { return nil }
            return ExercisePR(
                name: current.exercise,
                muscleGroup: current.muscleGroup,
                progression: progression,
                current: current
            )
        }
    }

    private var visible: [ExercisePR] {
        exercisePRs
            .filter { filter == "All" || $0.muscleGroup == filter }
            .sorted { $0.current.weightKg > $1.current.weightKg }
    }

    private var sectionOrder: [String] {
        let base = muscleGroups.filter { $0 != "All" && $0 != "Activity" } + ["General"]
        let extras = Set(visible.map { $0.muscleGroup }).subtracting(base).sorted()
        return base + extras
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroCard

                    HStack {
                        Text("Filter")
                            .font(.subheadline.bold())
                        Spacer()
                        Picker("Filter", selection: $filter) {
                            ForEach(muscleGroups, id: \.self) { group in
                                Text(group).tag(group)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.orange)
                    }
                    .padding(.horizontal, 4)

                    if filter == "Activity" {
                        emptyState("PRs are tracked for weighted lifts. Pick another filter to see them.")
                    } else if visible.isEmpty {
                        emptyState(filter == "All"
                                   ? "Log a lift to set your first PR."
                                   : "No \(filter) lifts logged yet.")
                    } else if filter == "All" {
                        allView
                    } else {
                        filteredView
                    }
                }
                .padding(16)
            }
            .navigationTitle("Personal Records")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: Header
    private var heroCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 56, height: 56)
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                Image(systemName: "bolt.fill")
                    .font(.caption.bold())
                    .foregroundColor(.yellow)
                    .offset(x: 18, y: -18)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Your Best Lifts")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("\(visible.count) lift\(visible.count == 1 ? "" : "s")" + (filter == "All" ? "" : " • \(filter)"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
            }
            Spacer()
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.orange, Color(red: 0.95, green: 0.35, blue: 0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: "All" - every muscle group, each lift's PR
    private var allView: some View {
        VStack(spacing: 16) {
            ForEach(sectionOrder, id: \.self) { group in
                let items = visible.filter { $0.muscleGroup == group }
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.uppercased())
                            .font(.caption.bold())
                            .foregroundColor(.orange)

                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            prRow(item, isTop: index == 0)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private func prRow(_ item: ExercisePR, isTop: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isTop ? "trophy.fill" : "bolt.fill")
                .font(.subheadline)
                .foregroundColor(isTop ? .yellow : .orange)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                Text(item.current.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(prText(item.current))
                .font(.subheadline.bold())
                .foregroundColor(.orange)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Filtered - PR progression per lift, oldest to newest, with dates
    private var filteredView: some View {
        VStack(spacing: 16) {
            ForEach(visible) { item in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(item.name)
                            .font(.headline)
                            .lineLimit(2)
                        Spacer()
                        Label("\(weightString(item.current.weightKg)) kg", systemImage: "trophy.fill")
                            .font(.caption.bold())
                            .foregroundColor(.orange)
                    }

                    ForEach(Array(item.progression.enumerated()), id: \.element.id) { index, record in
                        let isCurrent = index == item.progression.count - 1
                        HStack(spacing: 10) {
                            Circle()
                                .fill(isCurrent ? Color.orange : Color.secondary.opacity(0.4))
                                .frame(width: 8, height: 8)
                            Text(record.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(prText(record))
                                .font(.subheadline.bold())
                                .foregroundColor(isCurrent ? .orange : .primary)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    // MARK: Helpers
    private func emptyState(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .font(.title)
                .foregroundColor(.orange.opacity(0.6))
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func weightString(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(weight))
            : String(format: "%.1f", weight)
    }

    private func prText(_ record: PRRecord) -> String {
        "\(weightString(record.weightKg)) kg × \(record.reps)"
    }
}

// MARK: - Helper to Dismiss Keyboard
#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

// MARK: - Main Workout Tracker View
struct WorkoutTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingSession.date, order: .reverse) private var sessions: [TrainingSession]
    @Query private var personalProfiles: [PersonalInformation]

    // MARK: - Constants
    private static let otherRegime = "Other Activities"
    /// Activities are stored as ExerciseSet rows tagged with this muscle group,
    /// with the duration in minutes kept in `repsCount` and weight = 0.
    private static let activityGroup = "Activity"

    // MARK: - IST (Indian Standard Time) helpers
    private static let istTimeZone: TimeZone =
        TimeZone(identifier: "Asia/Kolkata") ?? TimeZone(secondsFromGMT: 19800) ?? .current

    private static var istCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = WorkoutTrackerView.istTimeZone
        return calendar
    }

    /// Formats dates like 2026-10-15T17:33:00+05:30
    private static let istFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = WorkoutTrackerView.istTimeZone
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        return formatter
    }()

    /// Number of calendar days the AI looks at, counting today.
    private static let analysisWindowDays = 30

    // MARK: - Form State
    @State private var sessionDate = Date()
    /// Becomes true only when you change the date/time yourself. Until then, the real current time is used.
    @State private var sessionDateEdited = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var bodyWeight: String = ""
    @State private var selectedRegime = "Push"

    let regimeOptions = ["Push", "Pull", "Legs", "Other Activities"]

    private var isOtherActivities: Bool { selectedRegime == Self.otherRegime }

    // MARK: - Custom Exercise State
    @State private var customExercises: [ExerciseInfo] = []

    // Used only to look up the muscle group when a typed name matches a known movement.
    private var defaultExercises: [ExerciseInfo] {
        [
            // PUSH
            ExerciseInfo(name: "Flat Barbell Bench Press", muscleGroup: "Chest", split: "Push"),
            ExerciseInfo(name: "Bench Press ( Flat Smith )", muscleGroup: "Chest", split: "Push"),
            ExerciseInfo(name: "Incline Smith Press", muscleGroup: "Chest", split: "Push"),
            ExerciseInfo(name: "Overhead Dumbbell Press", muscleGroup: "Shoulders", split: "Push"),
            ExerciseInfo(name: "Arnold Press", muscleGroup: "Shoulders", split: "Push"),
            ExerciseInfo(name: "Lateral Raises (Dumbbell)", muscleGroup: "Shoulders", split: "Push"),
            ExerciseInfo(name: "Parallel Bar Dips", muscleGroup: "Chest", split: "Push"),
            ExerciseInfo(name: "Triceps Pushdown (Rope)", muscleGroup: "Triceps", split: "Push"),
            ExerciseInfo(name: "Skull Crushers", muscleGroup: "Triceps", split: "Push"),

            // PULL
            ExerciseInfo(name: "Pull Ups", muscleGroup: "Lats", split: "Pull"),
            ExerciseInfo(name: "Front Lat Pulldown", muscleGroup: "Lats", split: "Pull"),
            ExerciseInfo(name: "Cable Rows", muscleGroup: "Lats", split: "Pull"),
            ExerciseInfo(name: "T Bar Delt Rows", muscleGroup: "Shoulders", split: "Pull"),
            ExerciseInfo(name: "Bent Rope Pulls", muscleGroup: "Lats", split: "Pull"),
            ExerciseInfo(name: "Reverse Pec Deck Fly", muscleGroup: "Shoulders", split: "Pull"),
            ExerciseInfo(name: "Face Pulls", muscleGroup: "Shoulders", split: "Pull"),
            ExerciseInfo(name: "Standing Barbell Curls", muscleGroup: "Biceps", split: "Pull"),
            ExerciseInfo(name: "Hammer Curls", muscleGroup: "Biceps", split: "Pull"),

            // LEGS
            ExerciseInfo(name: "Barbell Back Squat", muscleGroup: "Quads", split: "Legs"),
            ExerciseInfo(name: "Leg Press ( Horizontal )", muscleGroup: "Quads", split: "Legs"),
            ExerciseInfo(name: "Barbell Hip Thrust", muscleGroup: "Glutes", split: "Legs"),
            ExerciseInfo(name: "Romanian Deadlift (RDL)", muscleGroup: "Hamstrings", split: "Legs"),
            ExerciseInfo(name: "Leg Extensions", muscleGroup: "Quads", split: "Legs"),
            ExerciseInfo(name: "Lying Leg Curls", muscleGroup: "Hamstrings", split: "Legs"),
            ExerciseInfo(name: "Standing Calf Raises", muscleGroup: "Calves", split: "Legs"),
            ExerciseInfo(name: "Hip Abductors", muscleGroup: "Glutes", split: "Legs")
        ]
    }

    private var allExercises: [ExerciseInfo] { defaultExercises + customExercises }

    @State private var draftSets: [DraftSet] = [DraftSet()]

    // Tracks which exercise-name field is being edited, so suggestions only show for that card.
    @FocusState private var focusedDraftID: UUID?

    // MARK: - Popup & AI State
    @State private var selectedSessionDetail: TrainingSession?
    @State private var showAIReportSheet = false
    @State private var showPRSheet = false
    @State private var aiExpanded = false
    @State private var saveErrorMessage: String?
    @State private var toastMessage: String?
    @State private var isFetchingAI = false
    @State private var aiFeedbackText = ""

    // Each list has its own filter so changing one never changes the others.
    @State private var chartMuscleFilter = "All"      // 7-Day Progression Chart
    @State private var historyMuscleFilter = "All"    // All Logged Exercises History
    @State private var prMuscleFilter = "All"         // Personal Records popup

    let muscleGroups = ["All", "Chest", "Lats", "Shoulders", "Biceps", "Triceps", "Quads", "Hamstrings", "Glutes", "Calves", "Activity"]

    // STRICT CURRENT DAY FILTER for Your Lifts Overview
    private var todaysSessions: [TrainingSession] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDateInToday($0.date) }
    }

    // STRICT 7-DAY FILTER for AI Report Chart (uses the chart's own filter)
    private var last7DaysSets: [ExerciseSet] {
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        return sessions
            .filter { $0.date >= sevenDaysAgo && $0.date <= now }
            .flatMap { $0.workouts }
            .filter { chartMuscleFilter == "All" || $0.muscleGroup == chartMuscleFilter }
    }

    // Chart only plots weighted lifts (activities have no weight).
    private var last7DaysChartSets: [ExerciseSet] {
        last7DaysSets.filter { $0.muscleGroup != Self.activityGroup }
    }

    // ALL HISTORICAL SETS (uses the history list's own filter)
    private var allHistoricalSets: [ExerciseSet] {
        sessions
            .flatMap { $0.workouts }
            .filter { historyMuscleFilter == "All" || $0.muscleGroup == historyMuscleFilter }
    }

    // MARK: - Personal Records data
    /// Every weighted set ever logged, stamped with its session's date.
    private var prRecords: [PRRecord] {
        sessions.flatMap { session -> [PRRecord] in
            session.workouts
                .filter { $0.muscleGroup != Self.activityGroup }
                .map { set in
                    PRRecord(
                        exercise: set.exerciseName,
                        muscleGroup: set.muscleGroup,
                        weightKg: set.weightKg,
                        reps: set.repsCount,
                        date: session.date
                    )
                }
        }
    }

    private var prExerciseCount: Int {
        PRCalculator.grouped(prRecords).count
    }

    /// "16 Oct 2026" or "16 Oct 2026 • Set 2" when the set number was recorded.
    private func dateAndSetText(for set: ExerciseSet) -> String {
        let date = set.date.formatted(date: .abbreviated, time: .omitted)
        return set.setNumber > 0 ? "\(date) • Set \(set.setNumber)" : date
    }

    // Display text for a saved set: "50.0 kg × 8 reps" or "30 mins".
    private func summaryText(for set: ExerciseSet) -> String {
        if set.muscleGroup == Self.activityGroup {
            return "\(set.repsCount) mins"
        }
        return "\(String(format: "%.1f", set.weightKg)) kg × \(set.repsCount) reps"
    }

    /// Keeps the date/time on "now" unless you've set it yourself.
    private func refreshSessionDateIfUntouched() {
        if !sessionDateEdited {
            sessionDate = Date()
        }
    }

    // MARK: - Exercise Name Suggestions
    /// Names matching what you've typed so far, from the built-in list and everything you've logged before.
    /// Names from the current split are ranked first. You can tap one or just keep typing your own.
    private func suggestions(for draft: DraftSet) -> [String] {
        let query = draft.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let lowerQuery = query.lowercased()

        var candidates: [(name: String, split: String)] = []
        if isOtherActivities {
            for session in sessions {
                for set in session.workouts where set.muscleGroup == Self.activityGroup {
                    candidates.append((name: set.exerciseName, split: session.focusRegime))
                }
            }
        } else {
            candidates += allExercises.map { (name: $0.name, split: $0.split) }
            for session in sessions {
                for set in session.workouts where set.muscleGroup != Self.activityGroup {
                    candidates.append((name: set.exerciseName, split: session.focusRegime))
                }
            }
        }

        // Keep one entry per name (case-insensitive), with its best rank.
        var best: [String: (name: String, rank: Int)] = [:]
        for candidate in candidates {
            let name = candidate.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = name.lowercased()
            // Skip empties and names that are already fully typed.
            guard !name.isEmpty, key != lowerQuery, key.contains(lowerQuery) else { continue }
            let rank = (candidate.split == selectedRegime ? 0 : 2) + (key.hasPrefix(lowerQuery) ? 0 : 1)
            if let existing = best[key], existing.rank <= rank { continue }
            best[key] = (name: name, rank: rank)
        }

        return best.values
            .sorted { ($0.rank, $0.name) < ($1.rank, $1.name) }
            .prefix(4)
            .map { $0.name }
    }

    @ViewBuilder
    private func suggestionList(for draft: Binding<DraftSet>) -> some View {
        let matches = focusedDraftID == draft.wrappedValue.id ? suggestions(for: draft.wrappedValue) : []
        if !matches.isEmpty {
            VStack(spacing: 0) {
                ForEach(matches, id: \.self) { name in
                    Button {
                        draft.wrappedValue.exerciseName = name
                    } label: {
                        HStack {
                            Text(name)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if name != matches.last {
                        Divider()
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    /// Muscle group for an exercise: built-in list first, then whatever it was tagged with when you logged it before.
    private func muscleGroup(for name: String) -> String {
        if let known = allExercises.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return known.muscleGroup
        }
        for session in sessions {
            for set in session.workouts
            where set.muscleGroup != Self.activityGroup
                && set.muscleGroup != "General"
                && set.exerciseName.caseInsensitiveCompare(name) == .orderedSame {
                return set.muscleGroup
            }
        }
        return "General"
    }

    // MARK: - Profile Weight Helpers
    /// "82" or "82.5" (no trailing ".0"), always with a "." decimal separator.
    private func weightText(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(weight))
            : String(format: "%.1f", weight)
    }

    /// Fills the body-weight field from Personal Information, but never overwrites what you typed.
    private func prefillBodyWeightFromProfile() {
        guard bodyWeight.trimmingCharacters(in: .whitespaces).isEmpty,
              let profile = personalProfiles.first,
              profile.weightKg > 0 else { return }
        bodyWeight = weightText(profile.weightKg)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: - 1. Log Training Session Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Log Training Session")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 6) {
                            // Starts on the current date and time. Changing it yourself locks in your value.
                            DatePicker(
                                "Date & Time",
                                selection: Binding(
                                    get: { sessionDate },
                                    set: { newValue in
                                        sessionDate = newValue
                                        sessionDateEdited = true
                                    }
                                ),
                                displayedComponents: [.date, .hourAndMinute]
                            )

                            if sessionDateEdited {
                                Button {
                                    sessionDate = Date()
                                    sessionDateEdited = false
                                } label: {
                                    Label("Use current date & time", systemImage: "arrow.counterclockwise")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Body Weight (kg)")
                                    .font(.subheadline)
                                Spacer()
                                TextField("e.g. 82.5", text: $bodyWeight)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            }

                            Text(personalProfiles.isEmpty
                                 ? "Add your Personal Information in Settings to sync this weight."
                                 : "Saving this session also updates your weight in Personal Information.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Training Split / Focus")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)

                            Picker("Focus", selection: $selectedRegime) {
                                ForEach(regimeOptions, id: \.self) { regime in
                                    // Short label so four segments fit; the section below shows the full name.
                                    Text(regime == Self.otherRegime ? "Other" : regime).tag(regime)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: selectedRegime) { oldRegime, newRegime in
                                // Strength sets and activities use different fields, so start fresh
                                // when switching between those two kinds. Push/Pull/Legs keep what you typed.
                                let wasOther = oldRegime == Self.otherRegime
                                let isOther = newRegime == Self.otherRegime
                                if wasOther != isOther {
                                    draftSets = [DraftSet()]
                                }
                            }
                        }

                        Divider().padding(.vertical, 2)

                        Text(isOtherActivities ? "Other Activities" : "\(selectedRegime) Exercises")
                            .font(.subheadline.bold())

                        // MARK: Set / Activity Cards
                        VStack(spacing: 12) {
                            ForEach($draftSets) { $draft in
                                let itemNumber = (draftSets.firstIndex(where: { $0.id == draft.id }) ?? 0) + 1

                                VStack(alignment: .leading, spacing: 12) {

                                    // Header: number + delete
                                    HStack {
                                        Text(isOtherActivities ? "ACTIVITY \(itemNumber)" : "EXERCISE \(itemNumber)")
                                            .font(.caption.bold())
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        if draftSets.count > 1 {
                                            Button(role: .destructive) {
                                                removeDraftSet(id: draft.id)
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.subheadline)
                                                    .foregroundColor(.red.opacity(0.85))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }

                                    if isOtherActivities {
                                        // Activity name + duration (unit lives in the placeholder)
                                        pillField(
                                            placeholder: "Activity name",
                                            text: $draft.exerciseName
                                        )
                                        .focused($focusedDraftID, equals: draft.id)
                                        suggestionList(for: $draft)
                                        pillField(
                                            placeholder: "Duration (mins)",
                                            text: $draft.durationMins,
                                            keyboard: .numberPad
                                        )
                                    } else {
                                        // Free-text exercise name, starts empty.
                                        // Matching names appear below as you type; tap one or keep typing.
                                        pillField(
                                            placeholder: "Enter exercise name",
                                            text: $draft.exerciseName
                                        )
                                        .focused($focusedDraftID, equals: draft.id)
                                        suggestionList(for: $draft)

                                        // Subform: the set rows live inside this exercise.
                                        // Tap "+" to add the next set; the set number fills itself in.
                                        setRowsView(for: $draft)
                                    }
                                }
                                .padding(14)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }

                        Button {
                            withAnimation {
                                draftSets.append(DraftSet())
                            }
                        } label: {
                            Label(isOtherActivities ? "Add Activity" : "Add Exercise", systemImage: "plus.circle.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)

                        Button {
                            hideKeyboard()
                            saveSession()
                        } label: {
                            Text("Save Session")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    // MARK: - 2. Your Lifts Overview Card (Current Day Only)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .foregroundColor(.orange)
                            Text("Your Lifts Overview")
                                .font(.headline)
                            Spacer()
                            Text("\(todaysSessions.count) Today")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .clipShape(Capsule())
                        }

                        if todaysSessions.isEmpty {
                            Text("No training sessions recorded for today yet.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(todaysSessions) { session in
                                    Button {
                                        hideKeyboard()
                                        selectedSessionDetail = session
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(session.focusRegime)
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(.primary)
                                                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            HStack(spacing: 12) {
                                                if session.bodyWeight > 0 {
                                                    Text("\(String(format: "%.1f", session.bodyWeight)) kg BW")
                                                        .font(.caption.bold())
                                                        .foregroundColor(.secondary)
                                                }
                                                Text(session.focusRegime == Self.otherRegime
                                                     ? "\(session.workouts.count) activities"
                                                     : "\(session.workouts.count) sets")
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(.orange)
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(12)
                                        .background(Color(.systemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button {
                                            selectedSessionDetail = session
                                        } label: {
                                            Label("View Details", systemImage: "eye")
                                        }

                                        Button(role: .destructive) {
                                            deleteSession(session)
                                        } label: {
                                            Label("Delete Session", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    // MARK: - 3. AI Lifting Analysis & Report Banner
                    Button {
                        hideKeyboard()
                        // Opening the report does NOT call Gemini; that only happens from the card inside.
                        showAIReportSheet = true
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.2))
                                    .frame(width: 46, height: 46)
                                Image(systemName: "sparkles")
                                    .font(.title3)
                                    .foregroundColor(.orange)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AI Lifting Analysis & Report")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)
                                Text("Charts, history, PRs & on-demand Gemini insights")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.immediately)
            .onTapGesture {
                hideKeyboard()
            }
            .navigationTitle("Workouts")
            // Short "Saved" confirmation
            .overlay(alignment: .top) {
                if let toastMessage {
                    Text(toastMessage)
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            // Explains why a save didn't go through
            .alert("Can't save yet", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage ?? "")
            }
            .onAppear {
                refreshSessionDateIfUntouched()
                prefillBodyWeightFromProfile()
            }
            // Coming back to the app after a while: keep the untouched date/time current.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    refreshSessionDateIfUntouched()
                }
            }
            // If the profile weight changes elsewhere (e.g. Settings) or loads late,
            // refresh the field as long as you haven't typed anything.
            .onChange(of: personalProfiles.first?.weightKg) { _, _ in
                prefillBodyWeightFromProfile()
            }

            // Session Detail Popup Modal Sheet
            .sheet(item: $selectedSessionDetail) { session in
                NavigationStack {
                    List {
                        Section("Session Info") {
                            HStack {
                                Text("Focus / Split")
                                Spacer()
                                Text(session.focusRegime).bold()
                            }
                            HStack {
                                Text("Date")
                                Spacer()
                                Text(session.date.formatted(date: .long, time: .omitted))
                            }
                            HStack {
                                Text("Body Weight")
                                Spacer()
                                Text("\(String(format: "%.1f", session.bodyWeight)) kg")
                            }
                        }

                        Section(session.focusRegime == Self.otherRegime ? "Logged Activities" : "Logged Sets") {
                            ForEach(session.workouts) { set in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(set.exerciseName).bold()
                                        Text(set.setNumber > 0 ? "\(set.muscleGroup) • Set \(set.setNumber)" : set.muscleGroup).font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(summaryText(for: set))
                                        .foregroundColor(.orange)
                                        .bold()
                                }
                            }
                        }
                    }
                    .navigationTitle("Workout Details")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { selectedSessionDetail = nil }
                        }
                    }
                }
            }

            // AI Report Popup Sheet
            .sheet(isPresented: $showAIReportSheet) {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 20) {

                            // AI Feedback Card
                            VStack(alignment: .leading, spacing: 10) {
                                // Collapsed by default. Gemini is only called when you tap this header
                                // for the first time, or tap "Regenerate" below.
                                Button {
                                    handleAITap()
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "brain.head.profile")
                                            .foregroundColor(.orange)

                                        // Title and subtitle are centered between the icon and the chevron.
                                        VStack(spacing: 2) {
                                            Text("Gemini AI Analysis")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            if !aiExpanded {
                                                Text(aiFeedbackText.isEmpty
                                                     ? "Tap to analyze your last 30 days"
                                                     : "Tap to show the last analysis")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity, alignment: .center)

                                        Image(systemName: "chevron.down")
                                            .font(.subheadline.bold())
                                            .foregroundColor(.orange)
                                            .rotationEffect(.degrees(aiExpanded ? 180 : 0))
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if aiExpanded {
                                    if isFetchingAI {
                                        HStack(spacing: 12) {
                                            ProgressView()
                                            Text("Analyzing your last 30 days with Gemini...")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 8)
                                    } else {
                                        Text(aiFeedbackText)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                            .lineSpacing(4)

                                        Button {
                                            generateGeminiAnalysis()
                                        } label: {
                                            Label("Regenerate", systemImage: "arrow.clockwise")
                                                .font(.caption.bold())
                                                .foregroundColor(.orange)
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                            // Strict 7-Day Progression Chart
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("7-Day Progression Chart")
                                        .font(.headline)
                                    Spacer()
                                    Picker("Muscle Filter", selection: $chartMuscleFilter) {
                                        ForEach(muscleGroups, id: \.self) { group in Text(group).tag(group) }
                                    }
                                    .pickerStyle(.menu)
                                }

                                if last7DaysChartSets.isEmpty {
                                    Text("No lifting records found in the last 7 days.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 20)
                                } else {
                                    Chart(last7DaysChartSets) { set in
                                        BarMark(
                                            x: .value("Exercise", set.exerciseName),
                                            y: .value("Max Weight", set.weightKg)
                                        )
                                        .foregroundStyle(by: .value("Date", set.date.formatted(date: .abbreviated, time: .omitted)))
                                    }
                                    .frame(height: 220)
                                }
                            }
                            .padding(16)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                            // FILTERABLE ALL LOGGED EXERCISES HISTORY TABLE (WITH LONG PRESS DELETE)
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("All Logged Exercises History")
                                        .font(.headline)
                                    Spacer()
                                    Picker("Filter", selection: $historyMuscleFilter) {
                                        ForEach(muscleGroups, id: \.self) { group in Text(group).tag(group) }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.orange)
                                }

                                if allHistoricalSets.isEmpty {
                                    Text("No exercise history available for this filter.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(allHistoricalSets) { set in
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(set.exerciseName)
                                                        .font(.subheadline.bold())
                                                        .foregroundColor(.primary)
                                                    HStack(spacing: 6) {
                                                        Text(set.muscleGroup)
                                                            .font(.caption2.bold())
                                                            .foregroundColor(.orange)
                                                        Text("•")
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                        Text(dateAndSetText(for: set))
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                Spacer()
                                                Text(summaryText(for: set))
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(.orange)
                                            }
                                            .padding(12)
                                            .background(Color(.secondarySystemBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            // LONG PRESS CONTEXT MENU (Delete Individual Set)
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    deleteIndividualSet(set)
                                                } label: {
                                                    Label("Delete Set", systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                            // PR card: opens the Personal Records popup
                            PRBannerCard(prCount: prExerciseCount) {
                                showPRSheet = true
                            }
                        }
                        .padding(16)
                    }
                    .navigationTitle("AI Lifting Report")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showAIReportSheet = false }
                        }
                    }
                    .sheet(isPresented: $showPRSheet) {
                        PRReportView(
                            records: prRecords,
                            calendar: Self.istCalendar,
                            muscleGroups: muscleGroups,
                            filter: $prMuscleFilter
                        )
                    }
                }
            }
        }
    }

    // MARK: - Set Rows (subform inside one exercise card)
    /// Columns: Set | Weight | Reps. The set number fills itself in from the row's position.
    /// The "+" on the last row adds the next set; "−" removes the last one.
    private func setRowsView(for draft: Binding<DraftSet>) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("SET")
                    .frame(width: 36)
                Text("WEIGHT (KG)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("REPS")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Color.clear
                    .frame(width: 56, height: 1)
            }
            .font(.caption2.bold())
            .foregroundColor(.secondary)

            ForEach(draft.rows) { $row in
                let number = (draft.wrappedValue.rows.firstIndex(where: { $0.id == row.id }) ?? 0) + 1
                let isLast = number == draft.wrappedValue.rows.count

                HStack(spacing: 8) {
                    Text("\(number)")
                        .font(.subheadline.bold())
                        .foregroundColor(.orange)
                        .frame(width: 36, height: 34)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    TextField("0", text: $row.weightKg)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)

                    TextField("0", text: $row.repsCount)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 6) {
                        if isLast {
                            Button {
                                addSetRow(to: draft)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.orange)
                            }
                            .buttonStyle(.plain)

                            if number > 1 {
                                Button {
                                    removeSetRow(id: row.id, from: draft)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(width: 56, alignment: .trailing)
                }
            }
        }
    }

    private func addSetRow(to draft: Binding<DraftSet>) {
        withAnimation {
            draft.wrappedValue.rows.append(DraftSetRow())
        }
    }

    private func removeSetRow(id: UUID, from draft: Binding<DraftSet>) {
        withAnimation {
            draft.wrappedValue.rows.removeAll { $0.id == id }
        }
    }

    // MARK: - Reusable Pill Text Field (exercise / activity / duration)
    private func pillField(
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        TextField(placeholder, text: text)
            .font(.subheadline.bold())
            .keyboardType(keyboard)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Reusable Input Field (weight / reps)
    private func inputField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions
    private func removeDraftSet(id: UUID) {
        withAnimation {
            draftSets.removeAll { $0.id == id }
        }
    }

    private func deleteSession(_ session: TrainingSession) {
        withAnimation {
            modelContext.delete(session)
            try? modelContext.save()
        }
    }

    private func deleteIndividualSet(_ set: ExerciseSet) {
        withAnimation {
            modelContext.delete(set)
            try? modelContext.save()
        }
    }

    /// Expands/collapses the Gemini card. Gemini is only called on the first expand
    /// (when there's no result yet) or when you tap "Regenerate".
    private func handleAITap() {
        if aiExpanded {
            withAnimation { aiExpanded = false }
        } else {
            withAnimation { aiExpanded = true }
            if aiFeedbackText.isEmpty && !isFetchingAI {
                generateGeminiAnalysis()
            }
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toastMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { toastMessage = nil }
        }
    }

    /// Rolling window of whole IST calendar days, including today.
    /// Example: today = 30 Oct -> 1 Oct 00:00 up to (not including) 31 Oct 00:00.
    private func analysisWindow(now: Date = Date()) -> (start: Date, end: Date) {
        let calendar = Self.istCalendar
        let todayStart = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(Self.analysisWindowDays - 1), to: todayStart) ?? todayStart
        let end = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
        return (start, end)
    }

    /// Builds the JSON object that is sent to Gemini.
    /// Sets are grouped per exercise, and totals are calculated here so the AI doesn't have to.
    private func buildWorkoutPayload(
        sessionList: [TrainingSession],
        window: (start: Date, end: Date)
    ) -> [String: Any] {
        let formatter = Self.istFormatter

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "en_US_POSIX")
        weekdayFormatter.timeZone = Self.istTimeZone
        weekdayFormatter.dateFormat = "EEEE"

        let sessionPayloads: [[String: Any]] = sessionList.map { session -> [String: Any] in
            var exerciseOrder: [String] = []
            var grouped: [String: [ExerciseSet]] = [:]
            var activities: [[String: Any]] = []

            for set in session.workouts {
                if set.muscleGroup == Self.activityGroup {
                    activities.append([
                        "activity": set.exerciseName,
                        "duration_mins": set.repsCount
                    ])
                } else {
                    if grouped[set.exerciseName] == nil {
                        exerciseOrder.append(set.exerciseName)
                    }
                    grouped[set.exerciseName, default: []].append(set)
                }
            }

            let exercises: [[String: Any]] = exerciseOrder.map { name -> [String: Any] in
                // Performed order when the set number was recorded; older entries fall back to lightest-first.
                let sets = (grouped[name] ?? []).sorted {
                    if $0.setNumber != $1.setNumber { return $0.setNumber < $1.setNumber }
                    return ($0.weightKg, $0.repsCount) < ($1.weightKg, $1.repsCount)
                }
                let volume = sets.reduce(0.0) { $0 + $1.weightKg * Double($1.repsCount) }
                let setPayloads: [[String: Any]] = sets.map { s -> [String: Any] in
                    var entry: [String: Any] = ["weight_kg": s.weightKg, "reps": s.repsCount]
                    if s.setNumber > 0 { entry["set_number"] = s.setNumber }
                    return entry
                }

                return [
                    "exercise": name,
                    "muscle": sets.first?.muscleGroup ?? "General",
                    "sets": setPayloads,
                    "set_count": sets.count,
                    "top_weight_kg": sets.map { $0.weightKg }.max() ?? 0,
                    "total_reps": sets.reduce(0) { $0 + $1.repsCount },
                    "total_volume_kg": (volume * 10).rounded() / 10
                ]
            }

            return [
                "date": formatter.string(from: session.date),
                "weekday": weekdayFormatter.string(from: session.date),
                "split": session.focusRegime,
                "body_weight_kg": session.bodyWeight,
                "exercises": exercises,
                "other_activities": activities
            ]
        }

        return [
            "timezone": "Asia/Kolkata (IST, UTC+05:30). All dates and times below are in IST.",
            "window_start": formatter.string(from: window.start),
            "window_end_exclusive": formatter.string(from: window.end),
            "note": "The window covers \(Self.analysisWindowDays) calendar days including today. Sets within an exercise are listed in the order they were performed (set_number); older entries without a set_number are listed lightest to heaviest. total_volume_kg is the sum of weight x reps across the sets.",
            "sessions": sessionPayloads
        ]
    }

    private func generateGeminiAnalysis() {
        isFetchingAI = true

        guard let profile = personalProfiles.first else {
            aiFeedbackText = "Please complete Personal Information in Settings before generating your personalized AI report."
            isFetchingAI = false
            return
        }

        // Copy the saved SwiftData profile values before starting asynchronous work.
        let profileAge = profile.age
        let profileHeightCm = profile.heightCm
        let profileWeightKg = profile.weightKg
        let profileGender = profile.gender ?? "Prefer not to say"

        // Rolling 30 calendar days (IST), including today, oldest session first.
        let window = analysisWindow()
        let recentSessions = sessions
            .filter { $0.date >= window.start && $0.date < window.end }
            .sorted { $0.date < $1.date }

        let payloadData = buildWorkoutPayload(sessionList: recentSessions, window: window)

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payloadData, options: [.prettyPrinted, .sortedKeys]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            aiFeedbackText = "Failed to construct workout JSON payload."
            isFetchingAI = false
            return
        }

        Task {
            do {
                let aiResponse = try await GeminiAIService.shared.analyzeWorkouts(
                    workoutHistoryJSON: jsonString,
                    age: profileAge,
                    heightCm: profileHeightCm,
                    weightKg: profileWeightKg,
                    gender: profileGender
                )
                await MainActor.run {
                    self.aiFeedbackText = aiResponse
                    self.isFetchingAI = false
                }
            } catch {
                await MainActor.run {
                    if case GeminiError.server(let status, _) = error, status == 429 {
                        self.aiFeedbackText = "You've reached Gemini's free request limit for now. The quota resets daily, so try again later."
                    } else {
                        self.aiFeedbackText = "AI request failed: \(error.localizedDescription)"
                    }
                    self.isFetchingAI = false
                }
            }
        }
    }

    private func saveSession() {
        let weightNum = Double(bodyWeight.replacingOccurrences(of: ",", with: ".")) ?? 0.0

        // If you never touched the date/time, stamp the exact moment of saving.
        // If you set it manually, use exactly what you set.
        let effectiveDate = sessionDateEdited ? sessionDate : Date()

        let newSession = TrainingSession(date: effectiveDate, bodyWeight: weightNum, focusRegime: selectedRegime)

        var cloudSets: [ExerciseSetModel] = []
        // Running set number per exercise, so the same lift added twice in one session keeps counting up.
        var nextSetNumber: [String: Int] = [:]

        for draft in draftSets {
            let name = draft.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }

            if isOtherActivities {
                // Activity: needs a name and a duration in minutes.
                guard let mins = Int(draft.durationMins.trimmingCharacters(in: .whitespaces)), mins > 0 else { continue }

                let newSet = ExerciseSet(
                    exerciseName: name,
                    muscleGroup: Self.activityGroup,
                    weightKg: 0,
                    repsCount: mins,
                    date: effectiveDate
                )
                newSession.workouts.append(newSet)

                cloudSets.append(ExerciseSetModel(
                    exerciseName: name,
                    muscleGroup: Self.activityGroup,
                    weightKg: "",
                    repsCount: "",
                    durationMins: String(mins)
                ))
            } else {
                let muscle = muscleGroup(for: name)
                let key = name.lowercased()

                // Each filled-in row of the exercise card is one set, numbered in order.
                for row in draft.rows {
                    guard let w = Double(row.weightKg.replacingOccurrences(of: ",", with: ".")),
                          let r = Int(row.repsCount), r > 0 else { continue }

                    nextSetNumber[key, default: 0] += 1
                    let number = nextSetNumber[key] ?? 1

                    let newSet = ExerciseSet(
                        exerciseName: name,
                        muscleGroup: muscle,
                        weightKg: w,
                        repsCount: r,
                        date: effectiveDate
                    )
                    newSet.setNumber = number
                    newSession.workouts.append(newSet)

                    cloudSets.append(ExerciseSetModel(
                        exerciseName: name,
                        muscleGroup: muscle,
                        weightKg: row.weightKg,
                        repsCount: row.repsCount,
                        setNumber: number
                    ))
                }
            }
        }

        // Never create an empty session: at least one complete exercise is required.
        guard !newSession.workouts.isEmpty else {
            saveErrorMessage = isOtherActivities
                ? "Add an activity name and its duration in minutes, then tap Save Session."
                : "Add an exercise name with a weight and reps for at least one set, then tap Save Session."
            return
        }

        // Save Locally
        modelContext.insert(newSession)

        // Sync the entered body weight into Personal Information.
        // Same limits as the Settings form (0 < weight <= 500 kg).
        // A profile can't be created here because it also needs age and height.
        if weightNum > 0, weightNum <= 500, let profile = personalProfiles.first {
            profile.weightKg = weightNum
        }

        try? modelContext.save()

        // Sync to Creator Cloud
        let cloudModel = TrainingSessionModel(
            date: effectiveDate,
            bodyWeight: weightNum,
            focusRegime: selectedRegime,
            sets: cloudSets
        )

        Task {
            try? await CreatorWorkoutClient.shared.syncWorkoutSession(session: cloudModel)
        }

        // Reset sets; keep the body-weight field showing the latest saved weight.
        bodyWeight = (weightNum > 0 && weightNum <= 500 && !personalProfiles.isEmpty)
            ? weightText(weightNum)
            : ""
        draftSets = [DraftSet()]
        sessionDate = Date()
        sessionDateEdited = false

        let savedCount = newSession.workouts.count
        showToast(isOtherActivities
                  ? "Saved ✓ \(savedCount) activit\(savedCount == 1 ? "y" : "ies")"
                  : "Saved ✓ \(savedCount) set\(savedCount == 1 ? "" : "s")")
    }
}
