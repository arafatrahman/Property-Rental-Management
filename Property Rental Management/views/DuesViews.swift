//
//  DuesViews.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//

import SwiftUI

struct DuesSectionView: View {
    @EnvironmentObject var manager: RentalManager
    let status: PaymentStatus
    let tenants: [Tenant]
    
    @Binding var selectedTenant: Tenant?
    @Binding var showingLogPayment: Bool
    @Binding var reminderTenantName: String
    @Binding var showReminderAlert: Bool
    
    var body: some View {
        Section(header: Text(status.rawValue).foregroundColor(status.color).bold()) {
            ForEach(tenants) { tenant in
                DueTenantRowView(tenant: tenant)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            self.selectedTenant = tenant
                            self.showingLogPayment = true
                        } label: { Label("Log Payment", systemImage: "dollarsign.circle.fill") }.tint(.green)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            manager.scheduleReminder(for: tenant)
                            self.reminderTenantName = tenant.name
                            self.showReminderAlert = true
                        } label: { Label("Remind", systemImage: "bell.fill") }.tint(.blue)
                        .disabled(manager.reminderScheduledForTenantIDs.contains(tenant.id))
                    }
            }
        }
    }
}

struct DuesView: View {
    @EnvironmentObject var manager: RentalManager
    @State private var showingLogPayment = false
    @State private var selectedTenant: Tenant?
    @State private var showReminderAlert = false
    @State private var reminderTenantName = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach(PaymentStatus.allCases, id: \.self) { status in
                    let filteredTenants = manager.tenants.filter { $0.paymentStatus == status && $0.propertyId != nil }.sorted(by: {$0.nextDueDate < $1.nextDueDate})
                    if !filteredTenants.isEmpty {
                        DuesSectionView(
                            status: status,
                            tenants: filteredTenants,
                            selectedTenant: $selectedTenant,
                            showingLogPayment: $showingLogPayment,
                            reminderTenantName: $reminderTenantName,
                            showReminderAlert: $showReminderAlert
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Payment Dues")
            .sheet(isPresented: $showingLogPayment) {
                if let tenant = selectedTenant, let property = manager.getProperty(for: tenant) {
                    LogPaymentView(preselectedTenantId: tenant.id, preselectedAmount: property.rentAmount)
                }
            }
            .alert("Reminder Scheduled", isPresented: $showReminderAlert) {
                Button("OK", role: .cancel) { }
            } message: { Text("A payment reminder has been scheduled for \(reminderTenantName).") }
        }
    }
}

struct DueTenantRowView: View {
    @EnvironmentObject var manager: RentalManager
    let tenant: Tenant
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(tenant.name).font(.headline)
                Text(manager.getProperty(for: tenant)?.name ?? "No Property").font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Due: \(tenant.nextDueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).bold()
                Text(tenant.paymentStatus.rawValue)
                    .font(.caption).foregroundColor(.white).padding(4)
                    .background(tenant.paymentStatus.color).cornerRadius(4)
            }
        }
    }
}

struct LogPaymentView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var manager: RentalManager
    @State private var selectedTenantId: UUID?
    @State private var amountString = ""
    @State private var paymentDate = Date()
    
    var preselectedTenantId: UUID? = nil
    var preselectedAmount: Double? = nil

    var body: some View {
        NavigationView {
            Form {
                Section("Payment Details") {
                    Picker("Tenant", selection: $selectedTenantId) {
                        Text("Select a Tenant").tag(UUID?.none)
                        ForEach(manager.tenants.filter { $0.propertyId != nil }) { Text($0.name).tag($0.id as UUID?) }
                    }
                    TextField("Amount", text: $amountString)
                        .keyboardType(.decimalPad)
                    DatePicker("Payment Date", selection: $paymentDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Log Rent Payment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(selectedTenantId == nil || (Double(amountString) ?? 0) <= 0) }
            }
            .onAppear {
                if let id = preselectedTenantId { self.selectedTenantId = id }
                if let amount = preselectedAmount { self.amountString = String(amount) }
            }
        }
    }
    
    private func save() {
        guard let tenantId = selectedTenantId,
              let tenant = manager.getTenant(byId: tenantId),
              let propertyId = tenant.propertyId,
              let amount = Double(amountString) else { return }
        
        let rentCategory = manager.transactionCategories.first { $0.name == "Rent Payment" && $0.type == .income }
        
        let income = Income(description: "Rent Payment", amount: amount, date: paymentDate, tenantId: tenantId, propertyId: propertyId, categoryId: rentCategory?.id)
        manager.logIncome(income: income)
        dismiss()
    }
}
