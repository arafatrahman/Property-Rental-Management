//
//  HelperViews.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//

import SwiftUI

struct DashboardCardView: View {
    let title: String, value: String, icon: String, color: Color
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: icon).font(.title2).foregroundColor(color)
                Spacer()
                Text(title).font(.headline).foregroundColor(.secondary)
                Text(value).font(.title2).bold().foregroundColor(.primary)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
    }
}

struct NavigationCardView: View {
    let title: String, icon: String, color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Spacer()
            Text(title).font(.title2).bold().foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
    }
}


struct InfoRowView: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing).foregroundColor(.primary)
        }
    }
}

struct PropertiesListView: View {
    @EnvironmentObject var manager: RentalManager
    enum Filter { case occupied, vacant }
    let filter: Filter
    
    var filteredProperties: [Property] {
        switch filter {
        case .occupied: return manager.properties.filter { !$0.isVacant }
        case .vacant: return manager.properties.filter { $0.isVacant }
        }
    }
    
    var body: some View {
        List(filteredProperties) { property in
            NavigationLink(destination: PropertyDetailView(property: property)) {
                PropertyRowView(property: property)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(.plain)
        .navigationTitle(filter == .occupied ? "Occupied Properties" : "Vacant Properties")
    }
}

struct DuesListView: View {
    @EnvironmentObject var manager: RentalManager
    let filter: PaymentStatus
    
    var filteredTenants: [Tenant] {
        manager.tenants.filter { $0.paymentStatus == filter }
    }
    
    var body: some View {
        List(filteredTenants) { tenant in
            DueTenantRowView(tenant: tenant)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(filter.rawValue + " Dues")
    }
}
