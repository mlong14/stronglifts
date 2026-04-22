import Foundation
import SwiftData

// MARK: - Codable DTOs

struct BackupFile: Codable {
    let version: Int
    let exportedAt: Date
    let templates: [TemplateDTO]
    let sessions: [SessionDTO]
}

struct TemplateDTO: Codable {
    let name: String
    let exercises: [ExerciseTemplateDTO]
}

struct ExerciseTemplateDTO: Codable {
    let name: String
    let sets: Int
    let reps: Int
    let increment: Double
    let currentWeight: Double
    let order: Int
}

struct SessionDTO: Codable {
    let date: Date
    let templateName: String
    let isCompleted: Bool
    let exerciseLogs: [ExerciseLogDTO]
}

struct ExerciseLogDTO: Codable {
    let exerciseName: String
    let targetWeight: Double
    let order: Int
    let setLogs: [SetLogDTO]
}

struct SetLogDTO: Codable {
    let setNumber: Int
    let targetReps: Int
    let completedReps: Int
    let failed: Bool
    let isCompleted: Bool
    let weight: Double?
}

// MARK: - BackupManager

enum BackupManager {
    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: Export

    static func export(templates: [WorkoutTemplate], sessions: [WorkoutSession]) throws -> URL {
        let backup = BackupFile(
            version: 1,
            exportedAt: .now,
            templates: templates.sorted { $0.name < $1.name }.map { templateDTO($0) },
            sessions: sessions.filter { $0.isCompleted }.sorted { $0.date < $1.date }.map { sessionDTO($0) }
        )
        let data = try encoder.encode(backup)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: .now)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("stronglifts_backup_\(dateStr).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: Import

    static func restore(from url: URL, into context: ModelContext) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let backup = try decoder.decode(BackupFile.self, from: data)

        // Delete existing data (sessions first due to cascade)
        let existingSessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        for s in existingSessions { context.delete(s) }
        let existingTemplates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        for t in existingTemplates { context.delete(t) }
        try context.save()

        // Restore templates
        for dto in backup.templates {
            let template = WorkoutTemplate(name: dto.name)
            for exDTO in dto.exercises.sorted(by: { $0.order < $1.order }) {
                let ex = ExerciseTemplate(
                    name: exDTO.name,
                    sets: exDTO.sets,
                    reps: exDTO.reps,
                    increment: exDTO.increment,
                    order: exDTO.order
                )
                ex.currentWeight = exDTO.currentWeight
                template.exercises.append(ex)
            }
            context.insert(template)
        }

        // Restore sessions
        for dto in backup.sessions {
            let session = WorkoutSession(date: dto.date, templateName: dto.templateName)
            session.isCompleted = dto.isCompleted
            for logDTO in dto.exerciseLogs.sorted(by: { $0.order < $1.order }) {
                let log = ExerciseLog(
                    exerciseName: logDTO.exerciseName,
                    targetWeight: logDTO.targetWeight,
                    order: logDTO.order
                )
                for setDTO in logDTO.setLogs.sorted(by: { $0.setNumber < $1.setNumber }) {
                    let set = SetLog(setNumber: setDTO.setNumber, targetReps: setDTO.targetReps)
                    set.completedReps = setDTO.completedReps
                    set.failed = setDTO.failed
                    set.isCompleted = setDTO.isCompleted
                    set.weight = setDTO.weight
                    log.setLogs.append(set)
                }
                session.exerciseLogs.append(log)
            }
            context.insert(session)
        }

        try context.save()
    }

    // MARK: - Helpers

    private static func templateDTO(_ t: WorkoutTemplate) -> TemplateDTO {
        TemplateDTO(name: t.name, exercises: t.sortedExercises.map {
            ExerciseTemplateDTO(
                name: $0.name, sets: $0.sets, reps: $0.reps,
                increment: $0.increment, currentWeight: $0.currentWeight, order: $0.order
            )
        })
    }

    private static func sessionDTO(_ s: WorkoutSession) -> SessionDTO {
        SessionDTO(
            date: s.date,
            templateName: s.templateName,
            isCompleted: s.isCompleted,
            exerciseLogs: s.sortedLogs.map { log in
                ExerciseLogDTO(
                    exerciseName: log.exerciseName,
                    targetWeight: log.targetWeight,
                    order: log.order,
                    setLogs: log.sortedSets.map {
                        SetLogDTO(
                            setNumber: $0.setNumber, targetReps: $0.targetReps,
                            completedReps: $0.completedReps, failed: $0.failed,
                            isCompleted: $0.isCompleted, weight: $0.weight
                        )
                    }
                )
            }
        )
    }
}
