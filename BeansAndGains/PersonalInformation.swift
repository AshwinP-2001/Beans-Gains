
import Foundation
import SwiftData

@Model
final class PersonalInformation {
    // Optional to support existing SwiftData records during schema migration.
    var name: String? = nil
    var age: Int
    var heightCm: Double
    var weightKg: Double

    // Optional so existing database records can migrate more safely.
    var gender: String?

    init(
        name: String? = nil,
        age: Int,
        heightCm: Double,
        weightKg: Double,
        gender: String = "Male"
    ) {
        self.name = name
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.gender = gender
    }
}


