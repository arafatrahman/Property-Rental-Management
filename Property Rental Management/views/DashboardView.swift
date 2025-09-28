//
//  DashboardView.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var manager: RentalManager
    @EnvironmentObject var settings: SettingsManager

    // ✅ ADDED: State variables to control the presentation of each "Add" sheet.
    @State private var showingAddIncome = false
    @State private var showingAddExpense = false
    @State private var showingAddTenant = false
    @State private var showingAddProperty = false
    @State private var showingAddAppointment = false
    @State private var showingAddMaintenance = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // ✅ MODIFIED: The header HStack now includes the Analytics and Quick Add buttons.
                    HStack(alignment: .center) {
                        Text("Dashboard").font(.largeTitle).bold()
                        Spacer()

                        NavigationLink(destination: AnalyticsView()) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .padding(8)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(Circle())
                        }
                        
                        Menu {
                            Button { showingAddProperty = true } label: { Label("New Property", systemImage: "house.fill") }
                            Button { showingAddTenant = true } label: { Label("New Tenant", systemImage: "person.fill.badge.plus") }
                            Divider()
                            Button { showingAddIncome = true } label: { Label("Log Income", systemImage: "arrow.up.right.circle.fill") }
                            Button { showingAddExpense = true } label: { Label("Log Expense", systemImage: "arrow.down.right.circle.fill") }
                            Divider()
                            Button { showingAddAppointment = true } label: { Label("New Appointment", systemImage: "calendar.badge.plus") }
                            Button { showingAddMaintenance = true } label: { Label("New Maintenance", systemImage: "wrench.and.screwdriver.fill") }
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .padding(8)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(Circle())
                        }
                    }
                    .padding([.horizontal, .top])
                    
                    VStack(spacing: 15) {
                        NavigationLink(destination: FinancialsView(initialFilter: .all)) {
                            DashboardCardView(title: "Net Income", value: manager.netIncome.formattedAsCurrency(symbol: settings.currencySymbol.rawValue), icon: "scalemass.fill", color: .indigo)
                        }
                        HStack {
                            NavigationLink(destination: FinancialsView(initialFilter: .income)) {
                                DashboardCardView(title: "Total Income", value: manager.totalIncome.formattedAsCurrency(symbol: settings.currencySymbol.rawValue), icon: "arrow.up.right", color: .green)
                            }
                            NavigationLink(destination: FinancialsView(initialFilter: .expenses)) {
                                DashboardCardView(title: "Total Expenses", value: manager.totalExpenses.formattedAsCurrency(symbol: settings.currencySymbol.rawValue), icon: "arrow.down.right", color: .red)
                            }
                        }
                    }.padding(.horizontal)

                    VStack(alignment: .leading, spacing: 15) {
                        Text("MANAGEMENT").font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                        HStack {
                            NavigationLink(destination: PropertiesListView(filter: .occupied)) { DashboardCardView(title: "Occupied", value: "\(manager.occupiedProperties)", icon: "building.2.fill", color: .blue) }
                            NavigationLink(destination: PropertiesListView(filter: .vacant)) { DashboardCardView(title: "Vacant", value: "\(manager.vacantProperties)", icon: "house.fill", color: .gray) }
                        }
                        
                        HStack {
                           NavigationLink(destination: DuesListView(filter: .overdue)) { DashboardCardView(title: "Overdue", value: "\(manager.overdueTenantsCount)", icon: "exclamationmark.triangle.fill", color: .red) }
                           NavigationLink(destination: DuesListView(filter: .due)) { DashboardCardView(title: "Due Soon", value: "\(manager.dueSoonTenantsCount)", icon: "clock.fill", color: .orange) }
                        }
                        
                        HStack {
                           NavigationLink(destination: MaintenanceView()) { DashboardCardView(title: "Maintenance", value: "\(manager.openMaintenanceRequests)", icon: "wrench.and.screwdriver.fill", color: .brown) }
                           NavigationLink(destination: ScheduleView()) { DashboardCardView(title: "Appointments", value: "\(manager.upcomingAppointments)", icon: "calendar.badge.plus", color: .purple) }
                        }
                    }.padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            // ✅ ADDED: Sheet modifiers to present the correct view when a menu item is tapped.
            .sheet(isPresented: $showingAddIncome) { AddIncomeView() }
            .sheet(isPresented: $showingAddExpense) { AddExpenseView() }
            .sheet(isPresented: $showingAddTenant) { AddEditTenantView(tenant: nil) }
            .sheet(isPresented: $showingAddProperty) { AddEditPropertyView(property: nil) }
            .sheet(isPresented: $showingAddAppointment) { AddAppointmentView() }
            .sheet(isPresented: $showingAddMaintenance) { AddMaintenanceRequestView() }
        }
        .accentColor(.primary)
    }
}
