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
    @State private var selectedStatus: TenantStatus = .active
    
    private var filteredTenants: [Tenant] {
        manager.tenants.filter { $0.status == selectedStatus }
    }

    var body: some View {
        NavigationView {
            VStack {
                Picker("Status", selection: $selectedStatus) {
                    ForEach(TenantStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                List {
                    ForEach(filteredTenants) { tenant in
                        NavigationLink(destination: TenantDetailView(tenant: tenant)) {
                            TenantRowView(tenant: tenant)
                        }
                    }
                    .onDelete { offsets in
                        manager.deleteTenant(at: offsets, status: selectedStatus)
                    }
                }
                .listStyle(.insetGrouped)
            }
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

struct TenantRowView: View {
    @EnvironmentObject var manager: RentalManager
    @EnvironmentObject var settings: SettingsManager
    let tenant: Tenant
    
    var body: some View {
        HStack(spacing: 16) {
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
                
                if tenant.status == .active {
                    Spacer().frame(height: 4)
                    Text("Next Due: \(tenant.nextDueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(tenant.paymentStatus.color)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.vertical, 8)
    }
}


struct AddEditTenantView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var manager: RentalManager
    @EnvironmentObject var settings: SettingsManager
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
    @State private var amountOwedString: String = ""
    @State private var depositAmountString: String = ""

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
                
                Section("Assign to Property") {
                    Picker("Property", selection: $selectedPropertyId) {
                        Text("None").tag(UUID?.none)
                        ForEach(manager.properties.filter { $0.isVacant || $0.tenantId == self.id }) { Text($0.name).tag($0.id as UUID?) }
                    }
                }
                
                Section("Lease Details") {
                    DatePicker("Lease Start", selection: $leaseStartDate, displayedComponents: .date)
                    DatePicker("Lease End", selection: $leaseEndDate, displayedComponents: .date)
                    
                    HStack {
                        Text("Opening Balance (\(settings.currencySymbol.rawValue))")
                        TextField("0", text: $amountOwedString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Security Deposit (\(settings.currencySymbol.rawValue))")
                        TextField("0", text: $depositAmountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
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
            .onChange(of: selectedPropertyId) { _, newPropertyId in
                guard tenant == nil, amountOwedString.isEmpty, let newPropertyId = newPropertyId else { return }
                
                if let property = manager.getProperty(byId: newPropertyId) {
                    amountOwedString = String(property.rentAmount)
                }
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
            depositAmountString = String(t.depositAmount)
        }
    }
    
    private func save() {
        let amountOwed = Double(amountOwedString) ?? 0.0
        let depositAmount = Double(depositAmountString) ?? 0.0
        
        let newTenant = Tenant(id: id ?? UUID(), name: name, phone: phone, email: email, leaseStartDate: leaseStartDate, leaseEndDate: leaseEndDate, propertyId: selectedPropertyId, nextDueDate: tenant?.nextDueDate ?? leaseStartDate, imageData: imageData, amountOwed: amountOwed, depositAmount: depositAmount, isDepositPaid: tenant?.isDepositPaid ?? false, status: tenant?.status ?? .active)
        manager.saveTenant(tenant: newTenant)
        manager.recalculateBalance(forTenantId: newTenant.id)
        dismiss()
    }
}

struct TenantDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var manager: RentalManager
    @EnvironmentObject var settings: SettingsManager
    let tenant: Tenant
    @State private var showingAddEditTenant = false
    @State private var incomeToEdit: Income?
    @State private var showingLogDepositSheet = false
    @State private var showingArchiveAlert = false

    var body: some View {
        List {
            Section {
                if let imageData = tenant.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage).resizable().scaledToFill().frame(height: 250).clipped().listRowInsets(EdgeInsets())
                }
            }
            
            Section("Financials") {
                InfoRowView(label: "Current Balance", value: tenant.amountOwed.formattedAsCurrency(symbol: settings.currencySymbol.rawValue))
                if tenant.status == .active {
                    InfoRowView(label: "Next Payment Due", value: tenant.nextDueDate.formatted(date: .abbreviated, time: .omitted))
                }
                
                if tenant.depositAmount > 0 {
                    HStack {
                        InfoRowView(label: "Security Deposit", value: tenant.depositAmount.formattedAsCurrency(symbol: settings.currencySymbol.rawValue))
                        Spacer()
                        Text(tenant.isDepositPaid ? "Paid" : "Pending")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(tenant.isDepositPaid ? Color.green : Color.orange)
                            .clipShape(Capsule())
                    }
                }
                
                if !tenant.isDepositPaid && tenant.depositAmount > 0 {
                    Button("Log Deposit Payment") {
                        showingLogDepositSheet = true
                    }
                    .foregroundColor(.accentColor)
                }
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
            
            Section("Management") {
                if tenant.status == .active {
                    Button("Archive Tenant", role: .destructive) {
                        showingArchiveAlert = true
                    }
                } else {
                    Button("Reactivate Tenant") {
                        manager.reactivateTenant(tenant)
                        dismiss()
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
        .sheet(isPresented: $showingLogDepositSheet) {
            let depositCategory = manager.transactionCategories.first { $0.name == "Security Deposit" }
            AddIncomeView(
                preselectedTenantId: tenant.id,
                preselectedPropertyId: tenant.propertyId,
                preselectedAmount: tenant.depositAmount,
                preselectedDescription: "Security Deposit",
                preselectedCategoryId: depositCategory?.id
            )
        }
        .alert("Archive Tenant?", isPresented: $showingArchiveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Archive", role: .destructive) {
                manager.archiveTenant(tenant)
                dismiss()
            }
        } message: {
            Text("Archiving this tenant will mark their associated property as vacant. Their financial history will be preserved. Are you sure?")
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
