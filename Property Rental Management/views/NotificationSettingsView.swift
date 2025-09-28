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

    var body: some View {
        Form {
            Section("Enable Notifications") {
                Toggle("Payment Reminders", isOn: $enablePaymentReminders)
                Toggle("Appointment Reminders", isOn: $enableAppointmentReminders)
            }
            
            Section(footer: Text("Payment reminders are scheduled for one day before the due date. Appointment reminders are scheduled for one hour before the event.")) {
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
