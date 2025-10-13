//
//  ScheduleViews.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//
import SwiftUI
import UIKit

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
    
    private var datesWithEvents: Set<DateComponents> {
        let calendar = Calendar.current
        
        let appointmentDates = manager.appointments.map {
            calendar.dateComponents([.year, .month, .day], from: $0.date)
        }
        
        let dueDates = manager.tenants.map {
            calendar.dateComponents([.year, .month, .day], from: $0.nextDueDate)
        }
        
        return Set(appointmentDates + dueDates)
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
                if #available(iOS 16.0, *) {
                    HighlightedCalendarView(selectedDate: $selectedDate, highlightedDates: datesWithEvents)
                        .padding(.horizontal)
                        .fixedSize(horizontal: false, vertical: true)

                } else {
                    // Fallback for older iOS versions
                    DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding(.horizontal)
                }
                
                let appointmentsForDate = manager.appointments.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
                let duesForDate = manager.tenants.filter { Calendar.current.isDate($0.nextDueDate, inSameDayAs: selectedDate) }
                
                List {
                    if appointmentsForDate.isEmpty && duesForDate.isEmpty {
                        Text("No events for \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                            .foregroundColor(.secondary)
                    } else {
                        if !appointmentsForDate.isEmpty {
                            Section("Appointments") {
                                ForEach(appointmentsForDate) { appointment in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(appointment.title).font(.headline)
                                            if let property = manager.getProperty(byId: appointment.propertyId) {
                                                Text(property.name).font(.subheadline).foregroundColor(.secondary)
                                            }
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
                                    // ✅ ADDED: A tap gesture to open the edit view, which acts as a detail view.
                                    .contentShape(Rectangle()) // Makes the entire row area tappable
                                    .onTapGesture {
                                        appointmentToEdit = appointment
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
                        if !duesForDate.isEmpty {
                            Section("Payments Due") {
                                ForEach(duesForDate) { tenant in
                                    Text("Rent due for \(tenant.name)")
                                }
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
                                    if let property = manager.getProperty(byId: appointment.propertyId) {
                                        Text(property.name).font(.subheadline).foregroundColor(.secondary)
                                    }
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
                            // ✅ ADDED: A tap gesture here as well for consistency.
                            .contentShape(Rectangle())
                            .onTapGesture {
                                appointmentToEdit = appointment
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
        guard let propertyId = selectedPropertyId else { return }
        let appointment = Appointment(propertyId: propertyId, title: title, date: date)
        manager.addAppointment(appointment)
        dismiss()
    }
}

struct EditAppointmentView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var manager: RentalManager
    
    @State private var appointment: Appointment
    
    init(appointment: Appointment) {
        _appointment = State(initialValue: appointment)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Appointment Details") {
                    Picker("Property", selection: $appointment.propertyId) {
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
        }
    }

    private func save() {
        manager.updateAppointment(appointment)
        dismiss()
    }
}


// MARK: - Custom Highlightable Calendar View
@available(iOS 16.0, *)
struct HighlightedCalendarView: UIViewRepresentable {
    @Binding var selectedDate: Date
    let highlightedDates: Set<DateComponents>
    
    func makeUIView(context: Context) -> UICalendarView {
        let calendarView = UICalendarView()
        calendarView.delegate = context.coordinator
        calendarView.calendar = Calendar(identifier: .gregorian)
        
        calendarView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        calendarView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        calendarView.selectionBehavior = selection
        
        return calendarView
    }
    
    func updateUIView(_ uiView: UICalendarView, context: Context) {
        if let selectionBehavior = uiView.selectionBehavior as? UICalendarSelectionSingleDate {
            let calendar = Calendar.current
            let selectedDateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
            
            if selectionBehavior.selectedDate != selectedDateComponents {
                 selectionBehavior.setSelected(selectedDateComponents, animated: true)
            }
        }
        
        let oldDates = context.coordinator.previouslyHighlightedDates
        let newDates = self.highlightedDates
        let datesToReload = oldDates.union(newDates)
        
        context.coordinator.highlightedDates = newDates
        context.coordinator.previouslyHighlightedDates = newDates
        
        uiView.reloadDecorations(forDateComponents: Array(datesToReload), animated: true)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, highlightedDates: highlightedDates)
    }
    
    class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: HighlightedCalendarView
        var highlightedDates: Set<DateComponents>
        var previouslyHighlightedDates: Set<DateComponents>

        init(parent: HighlightedCalendarView, highlightedDates: Set<DateComponents>) {
            self.parent = parent
            self.highlightedDates = highlightedDates
            self.previouslyHighlightedDates = highlightedDates
        }
        
        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents = dateComponents,
                  let newDate = Calendar.current.date(from: dateComponents) else { return }
            
            parent.selectedDate = newDate
        }
        
        @MainActor
        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            for highlightedDate in highlightedDates {
                if highlightedDate.year == dateComponents.year &&
                   highlightedDate.month == dateComponents.month &&
                   highlightedDate.day == dateComponents.day {
                    return .default(color: .red, size: .large)
                }
            }
            return nil
        }
    }
}
