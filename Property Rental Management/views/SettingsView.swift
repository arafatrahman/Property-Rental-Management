//
//  SettingsView.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//

import SwiftUI
import UniformTypeIdentifiers
import FirebaseAuth

// A helper document struct for the fileExporter
struct DataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}


struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var manager: RentalManager
    @EnvironmentObject var firebaseManager: FirebaseManager
    @EnvironmentObject var themeManager: ThemeManager
    
    @AppStorage("hasChosenGuestMode") private var hasChosenGuestMode: Bool = false
    
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showingImportAlert = false
    @State private var showingDeleteAlert = false
    @State private var importedData: Data?

    var body: some View {
        Form {
            Section("Account") {
                // ✅ CORRECTED: This now checks the `authState` enum instead of the old boolean.
                if firebaseManager.authState == .signedIn {
                    Text("Signed in as \(Auth.auth().currentUser?.email ?? "...")")
                    Button("Sign Out", role: .destructive) {
                        firebaseManager.signOut(rentalManager: manager)
                        // This will cause the login screen to reappear on next launch
                        hasChosenGuestMode = false
                    }
                    Button("Delete Account", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } else {
                    Button("Sign In / Sign Up") {
                        // Setting this to false will trigger the login view to appear
                        hasChosenGuestMode = false
                    }
                }
            }
            
            Section("Appearance") {
                Toggle("Dark Mode", isOn: $themeManager.isDarkMode)
            }
            
            Section("Currency") {
                Picker("Currency Symbol", selection: $settingsManager.currencySymbol) {
                    ForEach(CurrencySymbol.allCases) { symbol in
                        Text(symbol.rawValue).tag(symbol)
                    }
                }
            }
            
            Section("Data Management") {
                Button {
                    showingExporter = true
                } label: {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                }
                
                Button(role: .destructive) {
                    showingImporter = true
                } label: {
                    Label("Import Data", systemImage: "square.and.arrow.down")
                }
            }
        }
        .navigationTitle("Settings")
        .fileExporter(isPresented: $showingExporter, document: DataDocument(data: manager.exportData() ?? Data()), contentType: .json, defaultFilename: "RentalDataBackup.json") { result in
            switch result {
            case .success(let url):
                print("Exported successfully to \(url)")
            case .failure(let error):
                print("Export failed: \(error.localizedDescription)")
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    do {
                        let data = try Data(contentsOf: url)
                        self.importedData = data
                        self.showingImportAlert = true
                    } catch {
                        print("Error reading file: \(error.localizedDescription)")
                    }
                }
            case .failure(let error):
                print("Error importing file: \(error.localizedDescription)")
            }
        }
        .alert("Import Data?", isPresented: $showingImportAlert) {
            Button("Cancel", role: .cancel) {
                importedData = nil
            }
            Button("Import", role: .destructive) {
                if let data = importedData {
                    manager.importData(from: data)
                }
                importedData = nil
            }
        } message: {
            Text("This will overwrite all existing data in the app. This action cannot be undone.")
        }
        .alert("Delete Account?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                firebaseManager.deleteAccount(rentalManager: manager) { error in
                    if let error = error {
                        print("Error deleting account: \(error.localizedDescription)")
                    } else {
                        hasChosenGuestMode = false
                    }
                }
            }
        } message: {
            Text("Are you sure you want to permanently delete your account and all associated data? This action cannot be undone.")
        }
    }
}
