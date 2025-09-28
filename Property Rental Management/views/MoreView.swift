//
//  MoreView.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//
import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationView {
            List {
                Section("Management") {
                    NavigationLink(destination: ScheduleView()) {
                        Label("Schedule", systemImage: "calendar")
                    }
                    NavigationLink(destination: MaintenanceView()) {
                        Label("Maintenance", systemImage: "wrench.and.screwdriver.fill")
                    }
                }
                
                Section("Configuration") {
                    NavigationLink(destination: CategoriesView()) {
                        Label("Manage Categories", systemImage: "folder.fill")
                    }
                    NavigationLink(destination: NotificationSettingsView()) {
                        Label("Notifications", systemImage: "bell.badge.fill")
                    }
                    NavigationLink(destination: SettingsView()) {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("More")
        }
    }
}
