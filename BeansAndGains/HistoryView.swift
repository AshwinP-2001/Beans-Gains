import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SupplementLog.logDate, order: .reverse)
    private var logs: [SupplementLog]

    @State private var logToDelete: SupplementLog?
    @State private var logToEdit: SupplementLog?
    @State private var logToView: SupplementLog?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                if logs.isEmpty {
                    ContentUnavailableView(
                        "No Check-Ins Yet",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Your saved check-in history will appear here.")
                    )
                }

                ForEach(logs) { log in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(log.logDate, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(summaryString(for: log))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if log.alcoholToday {
                            Text("Alcohol: \(log.howMuchAlcohol.isEmpty ? "Yes" : log.howMuchAlcohol)")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        if !log.workoutRoutine.isEmpty {
                            Text("Workout: \(log.workoutRoutine)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        logToView = log // Tapping opens the detail popup
                    }
                    .contextMenu { // Long-press triggers edit and delete options
                        Button {
                            logToEdit = log
                        } label: {
                            Label("Edit Entry", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            logToDelete = log
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Entry", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Check-In History")
            .sheet(item: $logToView) { log in
                SupplementDetailView(log: log)
            }
            .sheet(item: $logToEdit) { log in
                EditSupplementLogView(log: log)
            }
            .confirmationDialog(
                "Delete this check-in?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Entry", role: .destructive) {
                    deleteSelectedLog()
                }
                Button("Cancel", role: .cancel) {
                    logToDelete = nil
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    private func summaryString(for log: SupplementLog) -> String {
        var items: [String] = []
        if log.dailyCreatine { items.append("Creatine") }
        if log.zincIntake { items.append("Zinc") }
        if log.vitaminD { items.append("Vit D") }
        if log.calciumIntake { items.append("Calcium") }
        if log.multivitaminIntake { items.append("Multivitamin") }
        if log.vitaminCIntake { items.append("Vit C") }
        if log.vitaminBIntake { items.append("Vit B") }
        if log.fishOilIntake { items.append("Fish Oil") }
        
        return items.isEmpty ? "No supplements logged" : items.joined(separator: " · ")
    }

    private func deleteSelectedLog() {
        guard let log = logToDelete else { return }
        modelContext.delete(log)
        try? modelContext.save()
        logToDelete = nil
    }
}

// MARK: - Detail Popup View
struct SupplementDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let log: SupplementLog

    var body: some View {
        NavigationStack {
            Form {
                Section("Date & Time") {
                    Text(log.logDate, format: .dateTime.weekday(.wide).day().month(.wide).year().hour().minute())
                }

                Section("Supplements Taken") {
                    LabeledContent("Daily Creatine", value: log.dailyCreatine ? "Yes" : "No")
                    LabeledContent("Zinc Intake", value: log.zincIntake ? "Yes" : "No")
                    LabeledContent("Vitamin D", value: log.vitaminD ? "Yes" : "No")
                    LabeledContent("Calcium Intake", value: log.calciumIntake ? "Yes" : "No")
                    LabeledContent("Multivitamin Intake", value: log.multivitaminIntake ? "Yes" : "No")
                    LabeledContent("Vitamin C Intake", value: log.vitaminCIntake ? "Yes" : "No")
                    LabeledContent("Vitamin B Intake", value: log.vitaminBIntake ? "Yes" : "No")
                    LabeledContent("Fish Oil Intake", value: log.fishOilIntake ? "Yes" : "No")
                }

                Section("Daily Habits") {
                    LabeledContent("Alcohol Today", value: log.alcoholToday ? "Yes" : "No")
                    if log.alcoholToday {
                        LabeledContent("Alcohol Amount", value: log.howMuchAlcohol.isEmpty ? "Not specified" : log.howMuchAlcohol)
                    }
                }

                if !log.workoutRoutine.isEmpty {
                    Section("Workout Routine") {
                        Text(log.workoutRoutine)
                    }
                }

                if !log.dailyFeeling.isEmpty {
                    Section("Daily Feeling") {
                        Text(log.dailyFeeling)
                    }
                }
            }
            .navigationTitle("Check-In Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit Log View
struct EditSupplementLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var log: SupplementLog

    var body: some View {
        NavigationStack {
            Form {
                Section("Date & Time") {
                    DatePicker("Check-In Time", selection: $log.logDate)
                }

                Section("Daily Supplements") {
                    Toggle("Daily Creatine", isOn: $log.dailyCreatine)
                    Toggle("Zinc Intake", isOn: $log.zincIntake)
                    Toggle("Vitamin D", isOn: $log.vitaminD)
                    Toggle("Calcium Intake", isOn: $log.calciumIntake)
                    Toggle("Multivitamin Intake", isOn: $log.multivitaminIntake)
                    Toggle("Vitamin C Intake", isOn: $log.vitaminCIntake)
                    Toggle("Vitamin B Intake", isOn: $log.vitaminBIntake)
                    Toggle("Fish Oil Intake", isOn: $log.fishOilIntake)
                }

                Section("Daily Habits") {
                    Toggle("Alcohol Today", isOn: $log.alcoholToday)
                    if log.alcoholToday {
                        TextField("How much alcohol?", text: $log.howMuchAlcohol)
                            .keyboardType(.numberPad)
                    }
                }

                Section("Notes") {
                    TextField("Workout Routine", text: $log.workoutRoutine, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("How are you feeling today?", text: $log.dailyFeeling, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
