import SwiftUI
import SwiftData

struct SettingsHomeView: View {
    @State private var showPersonalInformation = false
    @State private var showDeveloperTools = false

    var body: some View {
        VStack(spacing: 16) {

            Button {
                showPersonalInformation = true
            } label: {
                settingsRow(
                    title: "Personal Information",
                    subtitle: "Age, height and weight",
                    icon: "person.crop.circle"
                )
            }
            .buttonStyle(.plain)

            Button {
                showDeveloperTools = true
            } label: {
                settingsRow(
                    title: "Developer Tools",
                    subtitle: "Zoho Creator and notification tools",
                    icon: "wrench.and.screwdriver"
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showPersonalInformation) {
            PersonalInformationFormView()
        }
        .sheet(isPresented: $showDeveloperTools) {
            CreatorFetchTestView()
        }
    }

    private func settingsRow(
        title: String,
        subtitle: String,
        icon: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
    }
}

struct PersonalInformationFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [PersonalInformation]

    @State private var name = ""
    @State private var age = ""
    @State private var height = ""
    @State private var weight = ""
    @State private var gender = "Male"
    private let genderOptions = ["Male", "Female", "Other", "Prefer not to say"]
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Profile") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)

                    Picker("Gender", selection: $gender) {
                        ForEach(genderOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    HStack {
                        Text("Age")
                        Spacer()
                        TextField("Years", text: $age)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("cm", text: $height)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("kg", text: $weight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    Button("Save Information") {
                        saveProfile()
                    }
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
                }
            }
            .navigationTitle("Personal Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Load once the sheet is presented.
                loadProfile()
            }
            .onChange(of: profiles.count) { _, _ in
                // SwiftData's @Query may populate just after the sheet appears.
                loadProfile()
            }
            .task {
                // Yield briefly so the sheet's SwiftData query can resolve first.
                await Task.yield()
                loadProfile()
            }
            .alert("Unable to Save", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Please check your details.")
            }
        }
    }

    private func loadProfile() {
        guard let profile = profiles.first else { return }

        name = profile.name ?? ""
        age = String(profile.age)
        height = String(profile.heightCm)
        weight = String(profile.weightKg)
        gender = profile.gender ?? "Male"
    }

    private func saveProfile() {
        guard
            let ageValue = Int(age),
            let heightValue = Double(height),
            let weightValue = Double(weight),
            (1...120).contains(ageValue),
            heightValue > 0 && heightValue <= 300,
            weightValue > 0 && weightValue <= 500
        else {
            errorMessage = """
            Enter a valid age, height in cm, and weight in kg.
            """
            showError = true
            return
        }

        if let profile = profiles.first {
            // Update the existing profile.
            profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : name.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.age = ageValue
            profile.heightCm = heightValue
            profile.weightKg = weightValue
            profile.gender = gender
        } else {
            // Create the profile only the first time.
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let profile = PersonalInformation(
                name: trimmedName.isEmpty ? nil : trimmedName,
                age: ageValue,
                heightCm: heightValue,
                weightKg: weightValue,
                gender: gender
            )
            modelContext.insert(profile)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Could not save your information: \(error.localizedDescription)"
            showError = true
        }
    }
}



