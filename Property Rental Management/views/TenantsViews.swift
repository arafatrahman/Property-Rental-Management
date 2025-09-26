//
//  TenantsViews.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//
import SwiftUI
import PhotosUI

struct TenantsView: View {
    @EnvironmentObject var manager: RentalManager
    @State private var showingAddEditTenant = false

    var body: some View {
        NavigationView {
            List {
                ForEach(manager.tenants) { tenant in
                    NavigationLink(destination: TenantDetailView(tenant: tenant)) {
                        TenantRowView(tenant: tenant)
                    }
                }
                .onDelete(perform: manager.deleteTenant)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Tenants")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddEditTenant.toggle() }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddEditTenant) {
                AddEditTenantView(tenant: nil)
            }
        }
    }
}

// ✅ REDESIGNED: A final, minimalist design removing all amounts from the row.
struct TenantRowView: View {
    @EnvironmentObject var manager: RentalManager
    @EnvironmentObject var settings: SettingsManager
    let tenant: Tenant
    
    var body: some View {
        HStack(spacing: 16) {
            // MARK: Avatar
            if let imageData = tenant.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
            }

            // MARK: Tenant Info
            VStack(alignment: .leading, spacing: 4) {
                Text(tenant.name)
                    .font(.headline)
                    .fontWeight(.bold)
                
                if let property = manager.getProperty(for: tenant) {
                    Text(property.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("No Property Assigned")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                
                Spacer().frame(height: 4)
                
                Text("Next Due: \(tenant.nextDueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(tenant.paymentStatus.color)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 8)
    }
}


struct AddEditTenantView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var manager: RentalManager
    var tenant: Tenant?

    @State private var id: UUID?
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var leaseStartDate = Date()
    @State private var leaseEndDate = Date()
    @State private var selectedPropertyId: UUID?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var amountOwedString: String = "0.0"

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack {
                            if let imageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 100, height: 100).clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().frame(width: 100, height: 100).foregroundColor(.gray)
                            }
                            PhotosPicker(selection: $selectedPhoto, matching: .images) { Text("Select Photo").font(.caption) }
                        }
                        Spacer()
                    }
                }

                Section("Personal Information") {
                    TextField("Full Name", text: $name)
                    TextField("Phone Number", text: $phone).keyboardType(.phonePad)
                    TextField("Email Address", text: $email).keyboardType(.emailAddress)
                }
                
                Section("Lease Details") {
                    DatePicker("Lease Start", selection: $leaseStartDate, displayedComponents: .date)
                    DatePicker("Lease End", selection: $leaseEndDate, displayedComponents: .date)
                    TextField("Opening Balance Owed", text: $amountOwedString)
                        .keyboardType(.decimalPad)
                }
                
                Section("Assign to Property") {
                    Picker("Property", selection: $selectedPropertyId) {
                        Text("None").tag(UUID?.none)
                        ForEach(manager.properties.filter { $0.isVacant || $0.tenantId == self.id }) { Text($0.name).tag($0.id as UUID?) }
                    }
                }
            }
            .navigationTitle(tenant == nil ? "Add Tenant" : "Edit Tenant")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task { if let data = try? await newItem?.loadTransferable(type: Data.self) { imageData = data } }
            }
            .onAppear(perform: loadTenantData)
        }
    }
    
    private func loadTenantData() {
        if let t = tenant {
            id = t.id; name = t.name; phone = t.phone; email = t.email
            leaseStartDate = t.leaseStartDate; leaseEndDate = t.leaseEndDate
            selectedPropertyId = t.propertyId; imageData = t.imageData
            amountOwedString = String(t.amountOwed)
        }
    }
    
    private func save() {
        let amountOwed = Double(amountOwedString) ?? 0.0
        let newTenant = Tenant(id: id ?? UUID(), name: name, phone: phone, email: email, leaseStartDate: leaseStartDate, leaseEndDate: leaseEndDate, propertyId: selectedPropertyId, nextDueDate: tenant?.nextDueDate ?? leaseStartDate, imageData: imageData, amountOwed: amountOwed)
        manager.saveTenant(tenant: newTenant)
        manager.recalculateBalance(forTenantId: newTenant.id)
        dismiss()
    }
}

struct TenantDetailView: View {
    @EnvironmentObject var manager: RentalManager
    @EnvironmentObject var settings: SettingsManager
    let tenant: Tenant
    @State private var showingAddEditTenant = false
    @State private var incomeToEdit: Income?

    var body: some View {
        List {
            Section {
                if let imageData = tenant.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage).resizable().scaledToFill().frame(height: 250).clipped().listRowInsets(EdgeInsets())
                }
            }
            
            Section("Financials") {
                InfoRowView(label: "Amount Owed", value: tenant.amountOwed.formattedAsCurrency(symbol: settings.currencySymbol.rawValue))
                InfoRowView(label: "Next Payment Due", value: tenant.nextDueDate.formatted(date: .abbreviated, time: .omitted))
            }
            
            Section("Contact Information") {
                InfoRowView(label: "Name", value: tenant.name)
                InfoRowView(label: "Phone", value: tenant.phone)
                InfoRowView(label: "Email", value: tenant.email)
            }
            
            Section("Lease Details") {
                InfoRowView(label: "Lease Starts", value: tenant.leaseStartDate.formatted(date: .abbreviated, time: .omitted))
                InfoRowView(label: "Lease Ends", value: tenant.leaseEndDate.formatted(date: .abbreviated, time: .omitted))
            }
            
            if let property = manager.getProperty(for: tenant) {
                Section("Rented Property") {
                    NavigationLink(destination: PropertyDetailView(property: property)) {
                        VStack(alignment: .leading) {
                           Text(property.name).font(.headline)
                           Text(property.address).font(.subheadline)
                       }
                    }
                }
            }
            
            Section("Billable Expenses") {
                let billableExpenses = manager.expenses.filter { $0.propertyId == tenant.propertyId && $0.isBillableToTenant }
                if billableExpenses.isEmpty {
                    Text("No billable expenses found.")
                } else {
                    ForEach(billableExpenses) { expense in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(expense.description)
                                if let category = manager.getCategory(byId: expense.categoryId) {
                                    Text(category.name).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(expense.amount.formattedAsCurrency(symbol: settings.currencySymbol.rawValue))
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            Section("Payment History") {
                let tenantIncomes = manager.incomes.filter { $0.tenantId == tenant.id }.sorted(by: { $0.date > $1.date })
                if tenantIncomes.isEmpty {
                    Text("No payments have been logged.")
                } else {
                    ForEach(tenantIncomes) { income in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(income.description)
                                if let category = manager.getCategory(byId: income.categoryId) {
                                    Text(category.name).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(income.amount.formattedAsCurrency(symbol: settings.currencySymbol.rawValue))
                                    .foregroundColor(.green)
                                Text(income.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                manager.deleteIncome(income)
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                            Button {
                                incomeToEdit = income
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }.tint(.blue)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(tenant.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingAddEditTenant.toggle() }
            }
        }
        .sheet(isPresented: $showingAddEditTenant) {
            AddEditTenantView(tenant: tenant)
        }
        .sheet(item: $incomeToEdit) { income in
            EditIncomeView(income: income)
        }
    }
}

struct EditIncomeView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var manager: RentalManager
    
    @State private var income: Income
    @State private var amountString: String = ""
    
    init(income: Income) {
        _income = State(initialValue: income)
        _amountString = State(initialValue: String(income.amount))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Edit Income Details") {
                    Picker("Property", selection: $income.propertyId) {
                        Text("Select a Property").tag(nil as UUID?)
                        ForEach(manager.properties) { Text($0.name).tag($0.id as UUID?) }
                    }
                    
                    Picker("Associated Tenant (Optional)", selection: $income.tenantId) {
                        Text("None").tag(nil as UUID?)
                        ForEach(manager.tenants) { Text($0.name).tag($0.id as UUID?) }
                    }
                    
                    TextField("Description", text: $income.description)
                    TextField("Amount", text: $amountString).keyboardType(.decimalPad)
                    DatePicker("Date", selection: $income.date, displayedComponents: .date)
                    
                    Picker("Category", selection: $income.categoryId) {
                        Text("Select a Category").tag(UUID?.none)
                        ForEach(manager.transactionCategories.filter { $0.type == .income }) {
                            Text($0.name).tag($0.id as UUID?)
                        }
                    }
                }
            }
            .navigationTitle("Edit Income")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
    }
    
    private func save() {
        if let amount = Double(amountString) {
            income.amount = amount
            manager.updateIncome(income)
            dismiss()
        }
    }
}
