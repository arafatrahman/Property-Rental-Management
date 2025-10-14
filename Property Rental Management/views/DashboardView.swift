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

    @State private var showingAddIncome = false
    @State private var showingAddExpense = false
    @State private var showingAddTenant = false
    @State private var showingAddProperty = false
    @State private var showingAddAppointment = false
    @State private var showingAddMaintenance = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack { // This outer VStack will help in centering our content
                    VStack(alignment: .leading, spacing: 25) {
                        // Header Toolbar
                        HStack(alignment: .center) {
                            Text("Dashboard").font(.largeTitle).bold()
                            
                            Spacer()

                            // Right-side Icons in the specified order
                            HStack(spacing: 20) {
                                // 1. Account Button
                                NavigationLink(destination: SettingsView()) {
                                    Image(systemName: "person.crop.circle")
                                        .font(.title2)
                                        .foregroundColor(.primary)
                                }
                                
                                // 2. Analytics Button
                                NavigationLink(destination: AnalyticsView()) {
                                    Image(systemName: "chart.bar.xaxis")
                                        .font(.title2)
                                        .foregroundColor(.primary)
                                }
                                
                                // 3. Add Button Menu
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
                                }
                            }
                        }
                        .padding([.horizontal, .top])
                        
                        VStack(spacing: 15) {
                            NavigationLink(destination: FinancialsView(initialFilter: .all)) {
                                DashboardCardView(title: "Net Income", value: manager.netIncome.formattedAsCurrency(symbol: settings.currencySymbol.rawValue), icon: "scalemass.fill", color: .indigo)
                            }
                            HStack(spacing: 15) {
                                NavigationLink(destination: FinancialsView(initialFilter: .income)) {
                                    DashboardCardView(title: "Total Income", value: manager.totalIncome.formattedAsCurrency(symbol: settings.currencySymbol.rawValue), icon: "arrow.up.right", color: .green)
                                }
                                NavigationLink(destination: FinancialsView(initialFilter: .expenses)) {
                                    DashboardCardView(title: "Total Expenses", value: manager.totalExpenses.formattedAsCurrency(symbol: settings.currencySymbol.rawValue), icon: "arrow.down.right", color: .red)
                                }
                            }
                        }.padding(.horizontal)

                        VStack(alignment: .leading, spacing: 15) {
                            Text("MANAGEMENT").font(.caption).foregroundColor(.secondary).padding(.horizontal)
                            
                            HStack(spacing: 15) {
                                NavigationLink(destination: PropertiesListView(filter: .occupied)) { DashboardCardView(title: "Occupied", value: "\(manager.occupiedProperties)", icon: "building.2.fill", color: .blue) }
                                NavigationLink(destination: PropertiesListView(filter: .vacant)) { DashboardCardView(title: "Vacant", value: "\(manager.vacantProperties)", icon: "house.fill", color: .gray) }
                            }
                            
                            HStack(spacing: 15) {
                               NavigationLink(destination: DuesListView(filter: .overdue)) { DashboardCardView(title: "Overdue", value: "\(manager.overdueTenantsCount)", icon: "exclamationmark.triangle.fill", color: .red) }
                               NavigationLink(destination: DuesListView(filter: .due)) { DashboardCardView(title: "Due Soon", value: "\(manager.dueSoonTenantsCount)", icon: "clock.fill", color: .orange) }
                            }
                            
                            HStack(spacing: 15) {
                               NavigationLink(destination: MaintenanceView()) { DashboardCardView(title: "Maintenance", value: "\(manager.openMaintenanceRequests)", icon: "wrench.and.screwdriver.fill", color: .brown) }
                               NavigationLink(destination: ScheduleView()) { DashboardCardView(title: "Appointments", value: "\(manager.upcomingAppointments)", icon: "calendar.badge.plus", color: .purple) }
                            }
                        }.padding(.horizontal)
                    }
                    .padding()
                    .frame(maxWidth: 800) // Constrains the content to a readable width on large screens
                }
                .frame(maxWidth: .infinity) // Ensures the centering container uses the full width
                .padding(.bottom)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddIncome) { AddIncomeView() }
            .sheet(isPresented: $showingAddExpense) { AddExpenseView() }
            .sheet(isPresented: $showingAddTenant) { AddEditTenantView(tenant: nil) }
            .sheet(isPresented: $showingAddProperty) { AddEditPropertyView(property: nil) }
            .sheet(isPresented: $showingAddAppointment) { AddAppointmentView() }
            .sheet(isPresented: $showingAddMaintenance) { AddMaintenanceRequestView() }
        }
        .navigationViewStyle(.stack)
        .accentColor(.primary)
    }
}
