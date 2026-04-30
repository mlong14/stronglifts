import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @Query private var templates: [WorkoutTemplate]
    @Query private var sessions: [WorkoutSession]
    @Environment(\.modelContext) private var modelContext

    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var showImporter = false
    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var showRestoreConfirm = false
    @State private var pendingImportURL: URL?

    @ObservedObject private var strava = StravaService.shared
    @State private var isConnectingStrava = false

    var body: some View {
        NavigationStack {
            List {
                Section("Strava") {
                    if strava.isConnected {
                        HStack {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Spacer()
                            Button("Disconnect", role: .destructive) {
                                strava.disconnect()
                            }
                            .buttonStyle(.borderless)
                        }
                    } else {
                        Button {
                            isConnectingStrava = true
                            Task {
                                do { try await strava.connect() }
                                catch {
                                    alertMessage = error.localizedDescription
                                    showAlert = true
                                }
                                isConnectingStrava = false
                            }
                        } label: {
                            HStack {
                                Label("Connect to Strava", systemImage: "link")
                                Spacer()
                                if isConnectingStrava { ProgressView() }
                            }
                        }
                        .disabled(isConnectingStrava)
                    }
                }

                Section("Backup") {
                    Button {
                        do {
                            exportURL = try BackupManager.export(templates: templates, sessions: sessions)
                            showShareSheet = true
                        } catch {
                            alertMessage = "Export failed: \(error.localizedDescription)"
                            showAlert = true
                        }
                    } label: {
                        Label("Export Backup", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showImporter = true
                    } label: {
                        Label("Import Backup", systemImage: "square.and.arrow.down")
                    }
                }

                ForEach(templates.sorted(by: { $0.name < $1.name })) { template in
                    WorkoutTemplateSectionView(
                        template: template,
                        canDelete: templates.count > 1,
                        onDelete: { deleteTemplate(template) }
                    )
                }

                Section {
                    Button { addTemplate() } label: {
                        Label("Add Workout", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(url: url)
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [UTType.json]
            ) { result in
                switch result {
                case .success(let url):
                    pendingImportURL = url
                    showRestoreConfirm = true
                case .failure(let error):
                    alertMessage = "Could not open file: \(error.localizedDescription)"
                    showAlert = true
                }
            }
            .confirmationDialog(
                "Replace all data with this backup?",
                isPresented: $showRestoreConfirm,
                titleVisibility: .visible
            ) {
                Button("Restore", role: .destructive) {
                    guard let url = pendingImportURL else { return }
                    do {
                        try BackupManager.restore(from: url, into: modelContext)
                        alertMessage = "Backup restored successfully."
                    } catch {
                        alertMessage = "Import failed: \(error.localizedDescription)"
                    }
                    showAlert = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will overwrite your current program and all workout history.")
            }
            .alert("Backup", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func addTemplate() {
        let existing = Set(templates.map(\.name))
        let candidates = ["A","B","C","D","E","F","G"]
        let name = candidates.first { !existing.contains($0) } ?? "New"
        let t = WorkoutTemplate(name: name)
        t.exercises = [ExerciseTemplate(name: "Squat", sets: 3, reps: 5, increment: 10, order: 0)]
        modelContext.insert(t)
        try? modelContext.save()
    }

    private func deleteTemplate(_ template: WorkoutTemplate) {
        modelContext.delete(template)
        try? modelContext.save()
    }

    private func formattedWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
    }
}

// MARK: - Per-template section

private struct WorkoutTemplateSectionView: View {
    @Bindable var template: WorkoutTemplate
    let canDelete: Bool
    let onDelete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirm = false

    var body: some View {
        Section {
            HStack {
                Circle()
                    .fill(template.color)
                    .frame(width: 10, height: 10)
                TextField("Name", text: $template.name)
                    .onChange(of: template.name) { _, _ in try? modelContext.save() }
            }

            ForEach(template.sortedExercises) { exercise in
                NavigationLink { ExerciseEditView(exercise: exercise) } label: {
                    HStack {
                        Text(exercise.name)
                        Spacer()
                        Text("\(exercise.sets)×\(exercise.reps) · \(fmt(exercise.currentWeight)) lbs")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onMove { from, to in
                var sorted = template.sortedExercises
                sorted.move(fromOffsets: from, toOffset: to)
                for (i, ex) in sorted.enumerated() { ex.order = i }
                try? modelContext.save()
            }
            .onDelete { offsets in
                let sorted = template.sortedExercises
                for i in offsets { modelContext.delete(sorted[i]) }
                try? modelContext.save()
            }

            Button { addExercise() } label: {
                Label("Add Exercise", systemImage: "plus.circle")
            }

            if canDelete {
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("Delete Workout \(template.name)", systemImage: "trash")
                }
            }
        } header: {
            Text("Workout \(template.name)")
        }
        .confirmationDialog(
            "Delete Workout \(template.name)?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the template and its exercises. Your workout history is kept.")
        }
    }

    private func addExercise() {
        let ex = ExerciseTemplate(
            name: "New Exercise",
            sets: 3, reps: 5, increment: 5,
            order: template.exercises.count
        )
        template.exercises.append(ex)
        try? modelContext.save()
    }

    private func fmt(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Exercise Edit

struct ExerciseEditView: View {
    @Bindable var exercise: ExerciseTemplate
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let weightValues = Array(stride(from: 0.0, through: 500.0, by: 2.5))
    private let incrementValues = [2.5, 5.0, 10.0, 15.0, 20.0, 25.0]

    private func fmt(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
    }

    var body: some View {
        Form {
            Section("Exercise") {
                TextField("Name", text: $exercise.name)
            }

            Section("Program") {
                HStack {
                    Text("Sets")
                    Spacer()
                    Picker("Sets", selection: $exercise.sets) {
                        ForEach(1...10, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                HStack {
                    Text("Reps")
                    Spacer()
                    Picker("Reps", selection: $exercise.reps) {
                        ForEach(1...20, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            }

            Section("Weight") {
                HStack {
                    Text("Current")
                    Spacer()
                    Picker("Current weight", selection: $exercise.currentWeight) {
                        ForEach(weightValues, id: \.self) { v in
                            Text(fmt(v) + " lbs").tag(v)
                        }
                    }
                    .pickerStyle(.menu)
                }
                HStack {
                    Text("Increment")
                    Spacer()
                    Picker("Increment", selection: $exercise.increment) {
                        ForEach(incrementValues, id: \.self) { v in
                            Text(fmt(v) + " lbs").tag(v)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: exercise.name) { _, _ in try? modelContext.save() }
        .onChange(of: exercise.sets) { _, _ in try? modelContext.save() }
        .onChange(of: exercise.reps) { _, _ in try? modelContext.save() }
        .onChange(of: exercise.currentWeight) { _, _ in try? modelContext.save() }
        .onChange(of: exercise.increment) { _, _ in try? modelContext.save() }
    }
}
