//
//  AddDeadlineView.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 28/09/2025.
//

import SwiftUI

struct AddDeadlineView: View {
    @State private var title: String = ""
    @State private var expiryDate: Date = Date()
    @Environment(\.dismiss) var dismiss
    var onSave: (PropertyDeadline) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("Deadline Details") {
                    TextField("Title (e.g., Insurance Renewal)", text: $title)
                    DatePicker("Expiry Date", selection: $expiryDate, in: Date()..., displayedComponents: .date)
                }
            }
            .navigationTitle("New Deadline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(title.isEmpty) }
            }
        }
    }
    
    private func save() {
        let newDeadline = PropertyDeadline(title: title, expiryDate: expiryDate)
        onSave(newDeadline)
        dismiss()
    }
}
