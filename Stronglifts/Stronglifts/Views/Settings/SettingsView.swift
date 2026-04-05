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
                    Section("Workout \(template.name)") {
                        ForEach(template.sortedExercises) { exercise in
                            NavigationLink {
                                ExerciseEditView(exercise: exercise)
                            } label: {
                                HStack {
                                    Text(exercise.name)
                                    Spacer()
                                    Text("\(exercise.sets)×\(exercise.reps) · \(formattedWeight(exercise.currentWeight)) lbs")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
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

                        Button {
                            addExercise(to: template)
                        } label: {
                            Label("Add Exercise", systemImage: "plus.circle")
                        }
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

    private func addExercise(to template: WorkoutTemplate) {
        let ex = ExerciseTemplate(
            name: "New Exercise",
            sets: 3,
            reps: 5,
            increment: 5,
            order: template.exercises.count
        )
        template.exercises.append(ex)
        try? modelContext.save()
    }

    private func formattedWeight(_ w: Double) -> String {
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

    var body: some View {
        Form {
            Section("Exercise") {
                TextField("Name", text: $exercise.name)
            }

            Section("Program") {
                Stepper("Sets: \(exercise.sets)", value: $exercise.sets, in: 1...10)
                Stepper("Reps: \(exercise.reps)", value: $exercise.reps, in: 1...20)
            }

            Section("Weight") {
                HStack {
                    Text("Current")
                    Spacer()
                    TextField("0", value: $exercise.currentWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("lbs").foregroundStyle(.secondary)
                }
                HStack {
                    Text("Increment")
                    Spacer()
                    TextField("0", value: $exercise.increment, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("lbs").foregroundStyle(.secondary)
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
