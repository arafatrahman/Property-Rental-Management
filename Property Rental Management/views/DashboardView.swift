//
//  DashboardView.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var manager: RentalManager
    @EnvironmentObject var settings: SettingsManager // ✅ ADDED: To access currency settings

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    HStack {
                        Text("Dashboard").font(.largeTitle).bold()
                        Spacer()
                    }.padding([.horizontal, .top])
                    
                    VStack(spacing: 15) {
                        NavigationLink(destination: FinancialsView(initialFilter: .all)) {
                            // ✅ MODIFIED: Uses the selected currency
                            DashboardCardView(title: "Net Income", value: manager.netIncome.formattedAsCurrency(symbol: settings.currencySymbol.rawValue), icon: "scalemass.fill", color: .indigo)
                        }
                        HStack {
                            NavigationLink(destination: FinancialsView(initialFilter: .income)) {
                                // ✅ MODIFIED: Uses the selected currency
                                DashboardCardView(title: "Total Income", value: manager.totalIncome.formattedAsCurrency(symbol: settings.currencySymbol.rawValue), icon: "arrow.up.right", color: .green)
                            }
                            NavigationLink(destination: FinancialsView(initialFilter: .expenses)) {
                                // ✅ MODIFIED: Uses the selected currency
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
                }.padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }.accentColor(.primary)
    }
}
