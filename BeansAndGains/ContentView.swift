import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var personalProfiles: [PersonalInformation]

    // MARK: - Form State
    @State private var logDate = Date.now
    @State private var dailyCreatine = false
    @State private var zincIntake = false
    @State private var vitaminD = false
    @State private var calciumIntake = false
    @State private var multivitaminIntake = false
    @State private var vitaminCIntake = false
    @State private var vitaminBIntake = false
    @State private var fishOilIntake = false
    @State private var magnesiumIntake = false
    @State private var biotinIntake = false
    @State private var cigarette = false
    @State private var howManyCigarettes = ""
    @State private var showMedications = false
    @State private var medications: [MedicationEntry] = []
    @State private var alcoholToday = false
    @State private var howMuchAlcohol = ""

    @State private var workoutRoutine = ""
    @State private var dailyFeeling = ""

    @State private var isSubmitting = false
    @State private var statusAlertMessage: String?
    @State private var showAlert = false

    // MARK: - Focus State for Auto-Scrolling
    enum FormField: Hashable {
        case alcohol, workout, feeling
    }
    @FocusState private var activeField: FormField?

    // MARK: - PIN Security State for Settings Tab
    @State private var selectedTab = 0
    @State private var showPinSheet = false
    @State private var enteredPin = ""
    @State private var isSettingsUnlocked = false
    @FocusState private var isPinFocused: Bool

    private var profileName: String {
        personalProfiles.first?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func greeting(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    // MARK: - Monday Check
    private var isMonday: Bool {
        Calendar.current.component(.weekday, from: Date()) == 2
    }

    var body: some View {
        TabView(selection: $selectedTab) {

            // MARK: - Check-In Tab (Tag 0)
            NavigationStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {

                            // 1. Warm Header Banner Card
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    TimelineView(.periodic(from: .now, by: 60)) { context in
                                        let appearance = timeOfDayAppearance(for: context.date)
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.orange.opacity(0.2))
                                                    .frame(width: 50, height: 50)
                                                Image(systemName: appearance.symbol)
                                                    .font(.title2)
                                                    .foregroundColor(appearance.color)
                                                    .contentTransition(.symbolEffect(.replace))
                                            }
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("\(greeting(for: context.date))\(profileName.isEmpty ? "" : ", \(profileName)")!")
                                                    .font(.title3.bold())
                                                    .foregroundColor(.primary)
                                                Text("Keep building momentum today.")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }

                                Divider()
                                    .padding(.vertical, 4)

                                HStack {
                                    Label("Date", systemImage: "calendar")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    DatePicker("", selection: $logDate, displayedComponents: [.date])
                                        .labelsHidden()
                                }
                            }
                            .padding(20)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)

                            // 2. Daily Supplements Card (Pill Chips)
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Daily Supplements")
                                    .font(.headline)
                                    .padding(.horizontal, 4)

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                    PillChip(title: "Creatine", isOn: $dailyCreatine, icon: "bolt.fill")

                                    if isMonday {
                                        PillChip(title: "Zinc (Mon)", isOn: $zincIntake, icon: "sparkles")
                                        PillChip(title: "Vit D (Mon)", isOn: $vitaminD, icon: "sun.min.fill")
                                    }

                                    PillChip(title: "Calcium", isOn: $calciumIntake, icon: "pills.fill")
                                    PillChip(title: "Multi-vit", isOn: $multivitaminIntake, icon: "cross.case.fill")
                                    PillChip(title: "Vit C", isOn: $vitaminCIntake, icon: "leaf.fill")
                                    PillChip(title: "Vit B", isOn: $vitaminBIntake, icon: "bolt.heart.fill")
                                    PillChip(title: "Fish Oil", isOn: $fishOilIntake, icon: "drop.fill")
                                    PillChip(title: "Mg", isOn: $magnesiumIntake, icon: "moon.stars.fill")
                                    PillChip(title: "Biotin", isOn: $biotinIntake, icon: "sparkles")
                                }
                            }
                            .padding(20)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                            // 3. Daily Habits Card
                            dailyHabitsCard

                            // 4. Medications Card
                            medicationsCard

                            // 5. Workout Routine Card
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Workout Routine")
                                    .font(.headline)
                                    .padding(.horizontal, 4)

                                TextEditor(text: $workoutRoutine)
                                    .frame(height: 120)
                                    .padding(8)
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .focused($activeField, equals: .workout)
                                    .id("workoutField")
                            }
                            .padding(20)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                            // 6. Daily Feeling Card
                            VStack(alignment: .leading, spacing: 10) {
                                Text("How are you feeling today?")
                                    .font(.headline)
                                    .padding(.horizontal, 4)

                                TextEditor(text: $dailyFeeling)
                                    .frame(height: 120)
                                    .padding(8)
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .focused($activeField, equals: .feeling)
                                    .id("feelingField")
                            }
                            .padding(20)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                            // 7. Action Buttons
                            VStack(spacing: 12) {
                                Button {
                                    Task { await submitCheckIn() }
                                } label: {
                                    HStack {
                                        if isSubmitting { ProgressView().tint(.white) }
                                        Text(isSubmitting ? "Submitting..." : "Submit Check-In")
                                            .font(.headline)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 4)
                                }
                                .disabled(isSubmitting)

                                Button(role: .destructive) {
                                    resetForm()
                                } label: {
                                    Text("Reset Form")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 8)
                                }
                            }
                            .padding(.top, 10)
                        }
                        .padding(16)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .onChange(of: activeField) { _, newField in
                        guard let field = newField else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            withAnimation {
                                switch field {
                                case .alcohol:
                                    proxy.scrollTo("alcoholSection", anchor: .center)
                                case .workout:
                                    proxy.scrollTo("workoutField", anchor: .center)
                                case .feeling:
                                    proxy.scrollTo("feelingField", anchor: .center)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Daily Check-In")
            }
            .tag(0)
            .tabItem {
                Label("Check-In", systemImage: "checkmark.circle")
            }

            // MARK: - History Tab (Tag 1)
            HistoryView()
                .tag(1)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            // MARK: - Workouts Tab (Tag 4)
            WorkoutTrackerView()
                            .tag(4)
                            .tabItem {
                                Label("Workouts", systemImage: "figure.strengthtraining.traditional")
                            }

            // MARK: - Calendar Tab (Tag 2)
            CalendarReportView()
                .tag(2)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            // MARK: - Settings / Test Console Tab (Tag 3 - PIN Protected)
            NavigationStack {
                Group {
                    if isSettingsUnlocked {
                        SettingsHomeView()
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.orange)
                            Text("Protected Developer Settings")
                                .font(.title2.bold())
                            Text("Please enter your PIN to access token management and test tools.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 32)

                            Button("Enter PIN") {
                                showPinSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .padding(.top, 8)
                        }
                    }
                }
                .navigationTitle("Settings")
            }
            .tag(3)
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .accentColor(.orange)
        .onChange(of: selectedTab) { oldTab, newTab in
            if oldTab == 3 {
                isSettingsUnlocked = false
            }
            if newTab == 3 && !isSettingsUnlocked {
                showPinSheet = true
            }
        }
        .sheet(isPresented: $showPinSheet, onDismiss: {
            if !isSettingsUnlocked {
                selectedTab = 0
            }
        }) {
            NavigationStack {
                VStack(spacing: 20) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                        .padding(.top, 20)

                    Text("Enter Security PIN")
                        .font(.title3.bold())

                    SecureField("PIN", text: $enteredPin)
                        .keyboardType(.numberPad)
                        .focused($isPinFocused)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                        .multilineTextAlignment(.center)
                        .id("pinField")

                    Button("Unlock") {
                        if enteredPin == "1811" {
                            isSettingsUnlocked = true
                            enteredPin = ""
                            showPinSheet = false
                        } else {
                            enteredPin = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Spacer()
                }
                .padding()
                .navigationTitle("Authentication")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            enteredPin = ""
                            showPinSheet = false
                            selectedTab = 0
                        }
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isPinFocused = true
                    }
                }
            }
            .presentationDetents([.height(280)])
        }
        .alert("Check-In Status", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(statusAlertMessage ?? "")
        }
    }

    // Split complex SwiftUI sections into separate view expressions to help type-checking.
    private var dailyHabitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Daily Habits")
                .font(.headline)
                .padding(.horizontal, 4)

            Toggle(isOn: $alcoholToday) {
                HStack {
                    Image(systemName: "wineglass.fill")
                        .foregroundColor(alcoholToday ? .orange : .secondary)
                    Text("Alcohol Today")
                        .font(.subheadline.weight(.medium))
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .orange))

            if alcoholToday {
                TextField("How much alcohol? (e.g. 60ml)", text: $howMuchAlcohol)
                    .keyboardType(.numbersAndPunctuation)
                    .padding(12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .focused($activeField, equals: .alcohol)
                    .id("alcoholSection")
            }

            Toggle(isOn: $cigarette) {
                HStack {
                    Text("🚬")
                        .opacity(cigarette ? 1 : 0.5)
                    Text("Smoking Today")
                        .font(.subheadline.weight(.medium))
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .orange))

            if cigarette {
                cigaretteCountField
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var cigaretteCountField: some View {
        TextField("Number of cigarettes", text: $howManyCigarettes)
            .keyboardType(.numberPad)
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var medicationsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $showMedications) {
                Label("Medications", systemImage: "pills.fill")
                    .font(.headline)
            }
            .toggleStyle(SwitchToggleStyle(tint: .orange))

            if showMedications {
                medicationEntryList

                Button {
                    medications.append(MedicationEntry())
                } label: {
                    Label("Add Medication", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                }
                .tint(.orange)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var medicationEntryList: some View {
        ForEach($medications) { $medication in
            MedicationEntryEditor(
                medication: $medication,
                onDelete: {
                    let id = medication.id
                    medications.removeAll { $0.id == id }
                }
            )
        }
    }

    @MainActor
    private func submitCheckIn() async {
        isSubmitting = true
        defer { isSubmitting = false }

        let localEntry = SupplementLog(
            logDate: logDate,
            dailyCreatine: dailyCreatine,
            zincIntake: zincIntake,
            vitaminD: vitaminD,
            calciumIntake: calciumIntake,
            multivitaminIntake: multivitaminIntake,
            vitaminCIntake: vitaminCIntake,
            vitaminBIntake: vitaminBIntake,
            fishOilIntake: fishOilIntake,
            alcoholToday: alcoholToday,
            howMuchAlcohol: howMuchAlcohol,
            workoutRoutine: workoutRoutine,
            dailyFeeling: dailyFeeling,
            magnesiumIntake: magnesiumIntake,
            biotinIntake: biotinIntake,
            cigarette: cigarette,
            howManyCigarettes: howManyCigarettes,
            medications: medications
        )
        modelContext.insert(localEntry)
        try? modelContext.save()

        let cloudModel = SupplementCheckInModel(
            logDate: logDate,
            dailyCreatine: dailyCreatine,
            zincIntake: zincIntake,
            vitaminD: vitaminD,
            calciumIntake: calciumIntake,
            multivitaminIntake: multivitaminIntake,
            vitaminCIntake: vitaminCIntake,
            vitaminBIntake: vitaminBIntake,
            fishOilIntake: fishOilIntake,
            alcoholToday: alcoholToday,
            howMuchAlcohol: howMuchAlcohol,
            workoutRoutine: workoutRoutine,
            dailyFeeling: dailyFeeling,
            magnesiumIntake: magnesiumIntake,
            biotinIntake: biotinIntake,
            cigarette: cigarette,
            howManyCigarettes: howManyCigarettes,
            medications: medications
        )

        do {
            try await CreatorAddClient.shared.addSupplementRecord(entry: cloudModel)
            statusAlertMessage = "SUCCESS!\nSaved locally and synced to Zoho Creator. Reminders cleared!"
            showAlert = true
            resetForm()
        } catch {
            statusAlertMessage = "Saved locally, but Zoho sync failed:\n\(error.localizedDescription)"
            showAlert = true
        }
    }

    private func resetForm() {
        logDate = .now
        dailyCreatine = false
        zincIntake = false
        vitaminD = false
        calciumIntake = false
        multivitaminIntake = false
        vitaminCIntake = false
        vitaminBIntake = false
        fishOilIntake = false
        magnesiumIntake = false
        biotinIntake = false
        cigarette = false
        howManyCigarettes = ""
        showMedications = false
        medications = []
        alcoholToday = false
        howMuchAlcohol = ""
        workoutRoutine = ""
        dailyFeeling = ""
    }
}

private struct MedicationEntryEditor: View {
    @Binding var medication: MedicationEntry
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Medication")
                    .font(.subheadline.bold())
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
            }

            TextField("Medicine name", text: $medication.name)
                .textInputAutocapitalization(.words)
                .textFieldStyle(.roundedBorder)

            TextField("Dosage (number)", text: $medication.dosage)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

            Picker("Intake time", selection: $medication.intakeTime) {
                Text("Morning").tag("Morning")
                Text("Afternoon").tag("Afternoon")
                Text("Night").tag("Night")
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Time-of-day welcome icon
private extension ContentView {
    func timeOfDayAppearance(for date: Date) -> (symbol: String, color: Color) {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11:
            return ("sun.max.fill", .orange)
        case 11..<16:
            return ("sun.max.fill", .orange)
        case 16..<19:
            return ("cloud.moon.fill", Color(red: 0.38, green: 0.48, blue: 0.78))
        default:
            return ("moon.stars.fill", Color(red: 0.43, green: 0.48, blue: 0.78))
        }
    }
}

// MARK: - Reusable Headspace-Style Pill Chip View
struct PillChip: View {
    let title: String
    @Binding var isOn: Bool
    let icon: String

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isOn ? Color.orange.opacity(0.18) : Color(.systemBackground))
            .foregroundColor(isOn ? .orange : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isOn ? Color.orange : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

