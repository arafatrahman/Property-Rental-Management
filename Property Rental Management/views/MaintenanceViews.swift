//
//  MaintenanceViews.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//

import SwiftUI

struct MaintenanceView: View {
    @EnvironmentObject var manager: RentalManager
    @State private var showingAddRequest = false

    var body: some View {
        List {
            Section("Open Requests") {
                let openRequests = manager.maintenanceRequests.filter { !$0.isResolved }
                if openRequests.isEmpty { Text("No open maintenance requests.") }
                ForEach(openRequests) { request in
                    NavigationLink(destination: EditMaintenanceRequestView(request: request)) {
                        MaintenanceRowView(request: request)
                    }
                    .swipeActions { Button { manager.resolveMaintenanceRequest(request) } label: { Label("Resolve", systemImage: "checkmark.circle.fill") }.tint(.green) }
                }
                .onDelete(perform: manager.deleteMaintenanceRequest)
            }
            
            Section("Resolved Requests") {
                let resolvedRequests = manager.maintenanceRequests.filter { $0.isResolved }
                if resolvedRequests.isEmpty { Text("No resolved requests.") }
                ForEach(resolvedRequests) { MaintenanceRowView(request: $0) }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Maintenance")
        .toolbar { Button { showingAddRequest.toggle() } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $showingAddRequest) { AddMaintenanceRequestView() }
    }
}

struct MaintenanceRowView: View {
    @EnvironmentObject var manager: RentalManager
    let request: MaintenanceRequest
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(manager.getProperty(byId: request.propertyId)?.name ?? "Unknown Property").font(.headline)
            Text(request.description).font(.subheadline).foregroundColor(.secondary)
            Text("Reported: \(request.reportedDate.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundColor(.gray)
        }
    }
}

struct AddMaintenanceRequestView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var manager: RentalManager
    @State private var description = ""
    @State private var selectedPropertyId: UUID?

    var body: some View {
        NavigationView {
            Form {
                Section("Request Details") {
                    Picker("Property", selection: $selectedPropertyId) {
                        Text("Select a Property").tag(UUID?.none)
                        ForEach(manager.properties) { Text($0.name).tag($0.id as UUID?) }
                    }
                    TextField("Description of Issue", text: $description)
                }
            }
            .navigationTitle("New Request")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(selectedPropertyId == nil || description.isEmpty) }
            }
        }
    }

    private func save() {
        guard let propertyId = selectedPropertyId else { return }
        let request = MaintenanceRequest(propertyId: propertyId, description: description)
        manager.addMaintenanceRequest(request)
        dismiss()
    }
}

struct EditMaintenanceRequestView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var manager: RentalManager
    @State var request: MaintenanceRequest
    
    var body: some View {
        NavigationView {
            Form {
                Section("Edit Request") {
                    TextField("Description", text: $request.description)
                }
            }
            .navigationTitle("Edit Maintenance")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        manager.updateMaintenanceRequest(request)
                        dismiss()
                    }
                }
            }
        }
    }
}
