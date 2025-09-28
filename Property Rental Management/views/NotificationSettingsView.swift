//
//  NotificationSettingsView.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 28/09/2025.
//

import SwiftUI

struct NotificationSettingsView: View {
    @AppStorage("enablePaymentReminders") private var enablePaymentReminders: Bool = true
    @AppStorage("enableAppointmentReminders") private var enableAppointmentReminders: Bool = true
    @AppStorage("enableLeaseExpiryReminders") private var enableLeaseExpiryReminders: Bool = true
    @AppStorage("enableMaintenanceReminders") private var enableMaintenanceReminders: Bool = true
    @AppStorage("enableDeadlineReminders") private var enableDeadlineReminders: Bool = true


    var body: some View {
        Form {
            Section("Reminders") {
                Toggle("Payment Due Reminders", isOn: $enablePaymentReminders)
                Toggle("Appointment Reminders", isOn: $enableAppointmentReminders)
                Toggle("Lease Expiry Reminders", isOn: $enableLeaseExpiryReminders)
                Toggle("Maintenance Follow-ups", isOn: $enableMaintenanceReminders)
                Toggle("Property Deadline Reminders", isOn: $enableDeadlineReminders)
            }
            
            Section(footer: Text("Reminders are scheduled automatically based on the dates you enter throughout the app. You can request notification permissions again if needed.")) {
                Button("Request Notification Permissions") {
                    NotificationManager.instance.requestAuthorization()
                }
            }
        }
        .navigationTitle("Notification Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NotificationSettingsView()
        }
    }
}
