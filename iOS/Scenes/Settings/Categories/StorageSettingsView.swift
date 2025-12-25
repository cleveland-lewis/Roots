import SwiftUI
#if os(iOS)

import UIKit

struct StorageSettingsView: View {
    @EnvironmentObject var settings: AppSettingsModel
    @State private var storageSize: String = "Calculating..."
    @State private var storageLocation: String = ""
    @State private var showingClearCacheConfirmation = false
    @State private var showingExportSheet = false
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var isExporting = false
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text(NSLocalizedString("settings.storage.used", comment: "Storage Used"))
                    Spacer()
                    Text(storageSize)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(NSLocalizedString("settings.storage.location", comment: "Location"))
                    Spacer()
                    Text(storageLocation.isEmpty
                         ? NSLocalizedString("settings.storage.location.local", comment: "Local")
                         : storageLocation)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                }
            } header: {
                Text(NSLocalizedString("settings.storage.info.header", comment: "Storage"))
            }
            
            Section {
                Button {
                    showingClearCacheConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text(NSLocalizedString("settings.storage.clear_cache", comment: "Clear Cache"))
                    }
                }
                .confirmationDialog(
                    NSLocalizedString("settings.storage.clear_cache.confirm.title", comment: "Clear Cache?"),
                    isPresented: $showingClearCacheConfirmation
                ) {
                    Button(NSLocalizedString("settings.storage.clear_cache.confirm.action", comment: "Clear Cache"), role: .destructive) {
                        clearCache()
                    }
                    Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) { }
                } message: {
                    Text(NSLocalizedString("settings.storage.clear_cache.confirm.message", comment: "This will clear temporary files and cached data. Your tasks, courses, and settings will not be affected."))
                }
            } header: {
                Text(NSLocalizedString("settings.storage.maintenance.header", comment: "Maintenance"))
            } footer: {
                Text(NSLocalizedString("settings.storage.maintenance.footer", comment: "Clearing cache can free up storage space and may improve performance"))
            }
            
            Section {
                Button {
                    showingExportSheet = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text(NSLocalizedString("settings.storage.export", comment: "Export Data"))
                    }
                }
            } header: {
                Text(NSLocalizedString("settings.storage.backup.header", comment: "Backup"))
            } footer: {
                Text(NSLocalizedString("settings.storage.backup.footer", comment: "Export your data as a backup file"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("settings.category.storage", comment: "Storage"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            calculateStorageSize()
            updateStorageLocation()
        }
        .sheet(isPresented: $showingExportSheet) {
            exportView
        }
        .sheet(isPresented: $showingShareSheet) {
            if let exportURL = exportURL {
                ShareSheet(activityItems: [exportURL]) {
                    showingShareSheet = false
                    try? FileManager.default.removeItem(at: exportURL)
                    self.exportURL = nil
                }
            } else {
                EmptyView()
            }
        }
        .alert(NSLocalizedString("settings.storage.export.error.title", comment: "Export Failed"), isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? NSLocalizedString("settings.storage.export.error.message", comment: "Unable to create the export file right now."))
        }
    }
    
    private var exportView: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text(NSLocalizedString("settings.storage.export.title", comment: "Export Data"))
                    .font(.title2.weight(.semibold))
                
                Text(NSLocalizedString("settings.storage.export.message", comment: "Your data will be exported as a JSON file that you can save or share."))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Button {
                    Task {
                        await performExport()
                    }
                } label: {
                    if isExporting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(NSLocalizedString("settings.storage.export.button", comment: "Export Now"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .disabled(isExporting)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.done", comment: "Done")) {
                        showingExportSheet = false
                    }
                }
            }
        }
    }
    
    private func calculateStorageSize() {
        DispatchQueue.global(qos: .utility).async {
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            
            let size = try? FileManager.default.allocatedSizeOfDirectory(at: documentsPath)
            let sizeInMB = Double(size ?? 0) / 1_048_576
            
            DispatchQueue.main.async {
                if sizeInMB < 1 {
                    storageSize = String(format: "%.1f KB", sizeInMB * 1024)
                } else {
                    storageSize = String(format: "%.1f MB", sizeInMB)
                }
            }
        }
    }

    private func updateStorageLocation() {
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            storageLocation = documentsPath.path
        }
    }
    
    private func clearCache() {
        // Clear URLCache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear temp directory
        let tmpDirectory = FileManager.default.temporaryDirectory
        try? FileManager.default.contentsOfDirectory(at: tmpDirectory, includingPropertiesForKeys: nil).forEach { url in
            try? FileManager.default.removeItem(at: url)
        }
        
        // Recalculate storage and refresh location
        calculateStorageSize()
        updateStorageLocation()
    }
    
    @MainActor private func performExport() async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        let assignments = AssignmentsStore.shared.tasks
        guard let coursesStore = CoursesStore.shared else {
            exportError = "Unable to gather course data for export."
            return
        }

        let payload = StorageDataExport(
            exportedAt: Date(),
            tasks: assignments,
            semesters: coursesStore.semesters,
            courses: coursesStore.courses,
            scheduledSessions: PlannerStore.shared.scheduled,
            overflowSessions: PlannerStore.shared.overflow,
            settings: AppSettingsModel.shared
        )

        do {
            let data = try JSONEncoder().encode(payload)
            let targetURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("roots-data-export-\(Int(Date().timeIntervalSince1970)).json")
            try data.write(to: targetURL, options: .atomic)
            exportError = nil
            exportURL = targetURL
            showingExportSheet = false
            showingShareSheet = true
        } catch {
            exportError = error.localizedDescription
        }
    }
}

private struct StorageDataExport: Codable {
    let exportedAt: Date
    let tasks: [AppTask]
    let semesters: [Semester]
    let courses: [Course]
    let scheduledSessions: [StoredScheduledSession]
    let overflowSessions: [StoredOverflowSession]
    let settings: AppSettingsModel
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let completion: (() -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            completion?()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension FileManager {
    func allocatedSizeOfDirectory(at url: URL) throws -> Int64 {
        let enumerator = enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey])
        var total: Int64 = 0
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        
        return total
    }
}

#Preview {
    NavigationStack {
        StorageSettingsView()
            .environmentObject(AppSettingsModel.shared)
    }
}
#endif
