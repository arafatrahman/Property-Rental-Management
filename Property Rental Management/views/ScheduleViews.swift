//
//  ScheduleViews.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//
import SwiftUI

enum ScheduleViewMode {
    case calendar, list
}

struct ScheduleView: View {
    @EnvironmentObject var manager: RentalManager
    @State private var viewMode: ScheduleViewMode = .list
    @State private var selectedDate = Date()
    @State private var showingAddAppointment = false
    
    @State private var appointmentToEdit: Appointment?

    private var upcomingAppointments: [Appointment] {
        manager.appointments.filter { $0.date >= Date().startOfDay }.sorted(by: { $0.date < $1.date })
    }
    
    var body: some View {
        VStack {
            Picker("View Mode", selection: $viewMode) {
                Text("List").tag(ScheduleViewMode.list)
                Text("Calendar").tag(ScheduleViewMode.calendar)
            }
            .pickerStyle(.segmented)
            .padding()

            if viewMode == .calendar {
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)
                
                let appointmentsForDate = manager.appointments.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
                let duesForDate = manager.tenants.filter { Calendar.current.isDate($0.nextDueDate, inSameDayAs: selectedDate) }
                
                List {
                    if !appointmentsForDate.isEmpty {
                        Section("Appointments") {
                            ForEach(appointmentsForDate) { appointment in
                                Text("\(appointment.title) for \(appointment.property.name)")
                            }
                        }
                    }
                    if !duesForDate.isEmpty {
                        Section("Payments Due") {
                            ForEach(duesForDate) { tenant in
                                Text("Rent due for \(tenant.name)")
                            }
                        }
                    }
                }
            } else {
                List {
                    Section("Upcoming Appointments") {
                        ForEach(upcomingAppointments) { appointment in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(appointment.title).font(.headline)
                                    Text(appointment.property.name).font(.subheadline).foregroundColor(.secondary)
                                    Text("\(appointment.date.formatted(date: .abbreviated, time: .shortened))")
                                }
                                Spacer()
                                Text(appointment.status.rawValue)
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(appointment.status.color)
                                    .clipShape(Capsule())
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    manager.deleteAppointment(appointment)
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                                
                                Button {
                                    appointmentToEdit = appointment
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }.tint(.blue)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Schedule")
        .toolbar { Button { showingAddAppointment.toggle() } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $showingAddAppointment) { AddAppointmentView() }
        .sheet(item: $appointmentToEdit) { appointment in
            EditAppointmentView(appointment: appointment)
        }
    }
}


struct AddAppointmentView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var manager: RentalManager
    @State private var title = ""
    @State private var date = Date()
    @State private var selectedPropertyId: UUID?

    var body: some View {
        NavigationView {
            Form {
                Section("Appointment Details") {
                    Picker("Property", selection: $selectedPropertyId) {
                        Text("Select a Property").tag(UUID?.none)
                        ForEach(manager.properties) { Text($0.name).tag($0.id as UUID?) }
                    }
                    TextField("Title (e.g., Viewing)", text: $title)
                    DatePicker("Date & Time", selection: $date)
                }
            }
            .navigationTitle("New Appointment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(selectedPropertyId == nil || title.isEmpty) }
            }
        }
    }

    private func save() {
        guard let propertyId = selectedPropertyId, let property = manager.getProperty(byId: propertyId) else { return }
        let appointment = Appointment(property: property, title: title, date: date)
        manager.addAppointment(appointment)
        dismiss()
    }
}

struct EditAppointmentView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var manager: RentalManager
    
    @State private var appointment: Appointment
    @State private var selectedPropertyId: UUID
    
    init(appointment: Appointment) {
        _appointment = State(initialValue: appointment)
        _selectedPropertyId = State(initialValue: appointment.property.id)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Appointment Details") {
                    Picker("Property", selection: $selectedPropertyId) {
                        ForEach(manager.properties) { Text($0.name).tag($0.id) }
                    }
                    TextField("Title (e.g., Viewing)", text: $appointment.title)
                    DatePicker("Date & Time", selection: $appointment.date)
                }
                
                Section("Status") {
                    Picker("Status", selection: $appointment.status) {
                        ForEach(AppointmentStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Edit Appointment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .onChange(of: selectedPropertyId) { _, newId in
                if let property = manager.getProperty(byId: newId) {
                    appointment.property = property
                }
            }
        }
    }

    private func save() {
        manager.updateAppointment(appointment)
        dismiss()
    }
}
