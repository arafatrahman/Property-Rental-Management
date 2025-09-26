//
//  PropertiesViews.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//
import SwiftUI
import PhotosUI

struct PropertiesView: View {
    @EnvironmentObject var manager: RentalManager
    @State private var showingAddEditProperty = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(manager.properties) { property in
                    NavigationLink(destination: PropertyDetailView(property: property)) {
                        PropertyRowView(property: property)
                    }
                }
                .onDelete(perform: manager.deleteProperty)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Properties")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddEditProperty.toggle() }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddEditProperty) {
                AddEditPropertyView(property: nil)
            }
        }
    }
}

struct PropertyRowView: View {
    @EnvironmentObject var settings: SettingsManager
    let property: Property
    
    var body: some View {
        HStack(spacing: 15) {
            if let firstImageData = property.imagesData.first, let uiImage = UIImage(data: firstImageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .cornerRadius(12)
            } else {
                Image(systemName: property.isVacant ? "house.circle.fill" : "building.2.crop.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(property.isVacant ? .gray : .accentColor)
                    .frame(width: 80, height: 80)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(property.name).font(.headline)
                Text(property.address).font(.subheadline).foregroundColor(.secondary)
                Spacer()
                HStack {
                    Text(property.rentAmount.formattedAsCurrency(symbol: settings.currencySymbol.rawValue))
                        .font(.headline)
                        .foregroundColor(.green)
                    Spacer()
                    Text(property.isVacant ? "Vacant" : "Rented")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(property.isVacant ? Color.gray.opacity(0.7) : Color.green.opacity(0.7))
                        .cornerRadius(6)
                }
            }
        }
    }
}

struct AddEditPropertyView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var manager: RentalManager
    @EnvironmentObject var settings: SettingsManager
    var property: Property?

    @State private var id: UUID?
    @State private var name = ""
    @State private var address = ""
    @State private var rentAmountString = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var imagesData: [Data] = []
    @State private var paymentCycle: PaymentCycle = .monthly
    
    var body: some View {
        NavigationView {
            Form {
                Section("Property Information") {
                    TextField("Property Name", text: $name)
                    TextField("Address", text: $address)
                }
                
                Section("Payment Details") {
                    TextField("Rent Amount (\(settings.currencySymbol.rawValue))", text: $rentAmountString)
                        .keyboardType(.decimalPad)
                    
                    Picker("Payment Cycle", selection: $paymentCycle) {
                       ForEach(PaymentCycle.allCases) { cycle in
                           Text(cycle.rawValue).tag(cycle)
                       }
                   }
                }
                
                Section("Property Photos") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(imagesData, id: \.self) { data in
                                if let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 100, height: 100).cornerRadius(10)
                                }
                            }
                        }
                    }
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                        Label("Add Photos", systemImage: "photo.on.rectangle.angled")
                    }
                }
            }
            .navigationTitle(property == nil ? "Add Property" : "Edit Property")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .onChange(of: selectedPhotos) { _, newItems in
                Task {
                    var newImagesData: [Data] = []
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            newImagesData.append(data)
                        }
                    }
                    self.imagesData = newImagesData
                }
            }
            .onAppear(perform: loadPropertyData)
        }
    }
    
    private func loadPropertyData() {
        if let p = property {
            id = p.id; name = p.name; address = p.address
            rentAmountString = String(p.rentAmount); imagesData = p.imagesData
            paymentCycle = p.paymentCycle
        }
    }
    
    private func save() {
        let rent = Double(rentAmountString) ?? 0.0
        let newProperty = Property(id: id ?? UUID(), name: name, address: address, rentAmount: rent, isVacant: property?.isVacant ?? true, tenantId: property?.tenantId, imagesData: imagesData, paymentCycle: paymentCycle)
        manager.saveProperty(property: newProperty)
        dismiss()
    }
}

struct PropertyDetailView: View {
    @EnvironmentObject var manager: RentalManager
    @EnvironmentObject var settings: SettingsManager
    let property: Property
    @State private var showingAddEditProperty = false
    @State private var expenseToEdit: Expense?

    var body: some View {
        List {
            if !property.imagesData.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(property.imagesData, id: \.self) { data in
                                if let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage).resizable().scaledToFill().frame(height: 200).cornerRadius(12)
                                }
                            }
                        }.padding(.vertical, 4)
                    }.listRowInsets(EdgeInsets())
                }
            }
            
            Section("Property Details") {
                InfoRowView(label: "Name", value: property.name)
                InfoRowView(label: "Address", value: property.address)
                InfoRowView(label: "Rent", value: property.rentAmount.formattedAsCurrency(symbol: settings.currencySymbol.rawValue))
                InfoRowView(label: "Payment Cycle", value: property.paymentCycle.rawValue)
                InfoRowView(label: "Status", value: property.isVacant ? "Vacant" : "Rented")
            }

            if let tenant = manager.getTenant(for: property) {
                Section("Current Tenant") {
                    NavigationLink(destination: TenantDetailView(tenant: tenant)) {
                         VStack(alignment: .leading) {
                             Text(tenant.name).font(.headline)
                             Text(tenant.email).font(.subheadline)
                        }
                    }
                }
            }
            
            Section("Expenses") {
                let propertyExpenses = manager.expenses.filter { $0.propertyId == property.id }
                if propertyExpenses.isEmpty {
                    Text("No expenses logged for this property.")
                } else {
                    // ✅ REDESIGNED: The expense row now matches the design from FinancialsView
                    ForEach(propertyExpenses) { expense in
                        HStack(spacing: 15) {
                            let category = manager.getCategory(byId: expense.categoryId)
                            let iconName = category?.iconName ?? "questionmark.circle.fill"

                            Image(systemName: iconName)
                                .font(.headline)
                                .frame(width: 40, height: 40)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Circle())
                                .foregroundColor(.red)

                            VStack(alignment: .leading) {
                                Text(expense.description).font(.headline)
                                Text(category?.name ?? "Uncategorized").font(.caption).foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(expense.amount.formattedAsCurrency(symbol: settings.currencySymbol.rawValue))
                                .foregroundColor(.red)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 4)
                        .swipeActions {
                            Button(role: .destructive) {
                                manager.deleteExpense(expense)
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                            Button {
                                expenseToEdit = expense
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }.tint(.blue)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(property.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingAddEditProperty.toggle() }
            }
        }
        .sheet(isPresented: $showingAddEditProperty) {
            AddEditPropertyView(property: property)
        }
        .sheet(item: $expenseToEdit) { expense in
            EditExpenseView(expense: expense)
        }
    }
}
