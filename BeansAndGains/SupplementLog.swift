import Foundation
import SwiftData

struct MedicationEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var dosage: String = ""
    var intakeTime: String = "Morning"
}

@Model
final class SupplementLog {
    var logDate: Date
    var dailyCreatine: Bool
    var zincIntake: Bool
    var vitaminD: Bool
    var calciumIntake: Bool
    var multivitaminIntake: Bool
    var vitaminCIntake: Bool
    var vitaminBIntake: Bool
    var fishOilIntake: Bool
    var alcoholToday: Bool
    var howMuchAlcohol: String
    var workoutRoutine: String
    var dailyFeeling: String
    var magnesiumIntake: Bool = false
    var biotinIntake: Bool = false
    var cigarette: Bool = false
    var howManyCigarettes: String = ""
    var medicationsJSON: String = "[]"


    init(
        logDate: Date = Date(),
        dailyCreatine: Bool = false,
        zincIntake: Bool = false,
        vitaminD: Bool = false,
        calciumIntake: Bool = false,
        multivitaminIntake: Bool = false,
        vitaminCIntake: Bool = false,
        vitaminBIntake: Bool = false,
        fishOilIntake: Bool = false,
        alcoholToday: Bool = false,
        howMuchAlcohol: String = "",
        workoutRoutine: String = "",
        dailyFeeling: String = "",
        magnesiumIntake: Bool = false,
        biotinIntake: Bool = false,
        cigarette: Bool = false,
        howManyCigarettes: String = "",
        medications: [MedicationEntry] = []
    ) {
        self.logDate = logDate
        self.dailyCreatine = dailyCreatine
        self.zincIntake = zincIntake
        self.vitaminD = vitaminD
        self.calciumIntake = calciumIntake
        self.multivitaminIntake = multivitaminIntake
        self.vitaminCIntake = vitaminCIntake
        self.vitaminBIntake = vitaminBIntake
        self.fishOilIntake = fishOilIntake
        self.alcoholToday = alcoholToday
        self.howMuchAlcohol = howMuchAlcohol
        self.workoutRoutine = workoutRoutine
        self.dailyFeeling = dailyFeeling
        self.magnesiumIntake = magnesiumIntake
        self.biotinIntake = biotinIntake
        self.cigarette = cigarette
        self.howManyCigarettes = howManyCigarettes
        if let data = try? JSONEncoder().encode(medications),
           let encoded = String(data: data, encoding: .utf8) {
            self.medicationsJSON = encoded
        } else {
            self.medicationsJSON = "[]"
        }
    }
}

