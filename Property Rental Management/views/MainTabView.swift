//
//  MainTabView.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//
import SwiftUI

struct MainTabView: View {
    init() {
        UITabBar.appearance().backgroundColor = UIColor.systemBackground
    }

    var body: some View {
        TabView {
            DashboardView().tabItem { Label("Dashboard", systemImage: "square.grid.2x2.fill") }
            PropertiesView().tabItem { Label("Properties", systemImage: "house.fill") }
            TenantsView().tabItem { Label("Tenants", systemImage: "person.2.fill") }
            FinancialsView().tabItem { Label("Financials", systemImage: "dollarsign.circle.fill") }
            MoreView().tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
        }
        .accentColor(.blue)
    }
}     
