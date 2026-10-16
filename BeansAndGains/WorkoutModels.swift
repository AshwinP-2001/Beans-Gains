import Foundation
import SwiftData

@Model
final class TrainingSession {
    var id: UUID
    var date: Date
    var bodyWeight: Double
    var focusRegime: String // e.g. "Upper Heavy", "Arms + Pull Isolation", "Legs + Core"
    
    @Relationship(deleteRule: .cascade)
    var workouts: [ExerciseSet]

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        bodyWeight: Double = 0.0,
        focusRegime: String = "Upper Moderate",
        workouts: [ExerciseSet] = []
    ) {
        self.id = id
        self.date = date
        self.bodyWeight = bodyWeight
        self.focusRegime = focusRegime
        self.workouts = workouts
    }
}

@Model
final class ExerciseSet {
    var id: UUID
    var exerciseName: String
    var muscleGroup: String
    var weightKg: Double
    var repsCount: Int
    var date: Date
    var setNumber: Int = 0

    init(
        id: UUID = UUID(),
        exerciseName: String,
        muscleGroup: String,
        weightKg: Double,
        repsCount: Int,
        date: Date = Date()
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.muscleGroup = muscleGroup
        self.weightKg = weightKg
        self.repsCount = repsCount
        self.date = date
    }
}
