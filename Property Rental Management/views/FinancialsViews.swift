//
//  FinancialsViews.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//
import SwiftUI

enum FinancialFilter { case all, income, expenses }

enum DateFilterType: String, CaseIterable, Identifiable {
    case daily = "Daily"
    case monthly = "Monthly"
    case yearly = "Yearly"
    case custom = "Custom Range"
    var id: String { self.rawValue }
}

struct FinancialsView: View {
    @EnvironmentObject var manager: RentalManager
    @EnvironmentObject var settings: SettingsManager
    @State private var showingAddExpense = false
    @State private var showingAddIncome = false
    @State var filter: FinancialFilter
    
    @State private var filterType: DateFilterType = .monthly
    @State private var selectedDate = Date()
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var endDate = Date()
    
    @State private var incomeToEdit: Income?
    @State private var expenseToEdit: Expense?
    
    @State private var searchText = ""

    init(initialFilter: FinancialFilter = .all) {
        _filter = State(initialValue: initialFilter)
    }
    
    private var dateRangeDescription: String {
        let formatter = DateFormatter()
        switch filterType {
        case .daily:
            formatter.dateStyle = .long
            return formatter.string(from: selectedDate)
        case .monthly:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: selectedDate)
        case .yearly:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: selectedDate)
        case .custom:
            formatter.dateStyle = .medium
            let start = formatter.string(from: startDate)
            let end = formatter.string(from: endDate)
            return "\(start) - \(end)"
        }
    }
    
    private var filteredIncomes: [Income] {
        var dateFilteredIncomes: [Income]
        let sortedIncomes = manager.incomes.sorted { $0.date > $1.date }

        switch filterType {
        case .daily:
            dateFilteredIncomes = sortedIncomes.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
        case .monthly:
            dateFilteredIncomes = sortedIncomes.filter { Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: .month) }
        case .yearly:
            dateFilteredIncomes = sortedIncomes.filter { Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: .year) }
        case .custom:
            let range = startDate.startOfDay...endDate.endOfDay
            dateFilteredIncomes = sortedIncomes.filter { range.contains($0.date) }
        }

        if searchText.isEmpty {
            return dateFilteredIncomes
        } else {
            return dateFilteredIncomes.filter { $0.description.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var filteredExpenses: [Expense] {
        var dateFilteredExpenses: [Expense]
        let sortedExpenses = manager.expenses.sorted { $0.date > $1.date }

        switch filterType {
        case .daily:
            dateFilteredExpenses = sortedExpenses.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
        case .monthly:
            dateFilteredExpenses = sortedExpenses.filter { Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: .month) }
        case .yearly:
            dateFilteredExpenses = sortedExpenses.filter { Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: .year) }
        case .custom:
            let range = startDate.startOfDay...endDate.endOfDay
            dateFilteredExpenses = sortedExpenses.filter { range.contains($0.date) }
        }

        if searchText.isEmpty {
            return dateFilteredExpenses
        } else {
            return dateFilteredExpenses.filter { $0.description.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var totalFilteredIncome: Double {
        filteredIncomes.reduce(0) { $0 + $1.amount }
    }
    private var totalFilteredExpenses: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }
    private var netFilteredIncome: Double {
        totalFilteredIncome - totalFilteredExpenses
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Filter Period") {
                    Picker("Filter by", selection: $filterType.animation()) {
                        ForEach(DateFilterType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    switch filterType {
                    case .daily:
                        DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    case .monthly:
                        DatePicker("Select Month", selection: $selectedDate, displayedComponents: .date)
                    case .yearly:
                        DatePicker("Select Year", selection: $selectedDate, displayedComponents: .date)
                    case .custom:
                        DatePicker("Start Date", selection: $startDate, in: ...endDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }

                Section("Summary for Selected Period") {
                    InfoRowView(label: "Net Income", value: netFilteredIncome.formattedAsCurrency(symbol: settings.currencySymbol.rawValue))
                    InfoRowView(label: "Total Income", value: totalFilteredIncome.formattedAsCurrency(symbol: settings.currencySymbol.rawValue))
                    InfoRowView(label: "Total Expenses", value: totalFilteredExpenses.formattedAsCurrency(symbol: settings.currencySymbol.rawValue))
                }
                
                if filter == .all || filter == .income {
                    Section(header: Text("Income"), footer: Text("Displaying results for \(dateRangeDescription)")) {
                        ForEach(filteredIncomes) { income in
                            HStack(spacing: 15) {
                                let category = manager.getCategory(byId: income.categoryId)
                                let iconName = category?.iconName ?? "questionmark.circle.fill"
                                
                                Image(systemName: iconName)
                                    .font(.headline)
                                    .frame(width: 40, height: 40)
                                    .background(Color.green.opacity(0.1))
                                    .clipShape(Circle())
                                    .foregroundColor(.green)

                                VStack(alignment: .leading) {
                                    Text(income.description).font(.headline)
                                    Text(category?.name ?? "Uncategorized").font(.caption).foregroundColor(.secondary)
                                }

                                Spacer()

                                Text(income.amount.formattedAsCurrency(symbol: settings.currencySymbol.rawValue))
                                    .foregroundColor(.green)
                                    .fontWeight(.semibold)
                            }
                            .padding(.vertical, 4)
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
                
                if filter == .all || filter == .expenses {
                    Section(header: Text("Expenses"), footer: Text("Displaying results for \(dateRangeDescription)")) {
                        ForEach(filteredExpenses) { expense in
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
            .navigationTitle("Financials")
            .navigationBarTitleDisplayMode(.inline) // Changed to inline
            .searchable(text: $searchText, prompt: "Search by description")
            .toolbar {
                Menu {
                    Button { showingAddIncome = true } label: { Label("Add Income", systemImage: "plus.circle.fill") }
                    Button { showingAddExpense = true } label: { Label("Add Expense", systemImage: "minus.circle.fill") }
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddIncome) { AddIncomeView() }
            .sheet(isPresented: $showingAddExpense) { AddExpenseView() }
            .sheet(item: $incomeToEdit) { income in EditIncomeView(income: income) }
            .sheet(item: $expenseToEdit) { expense in EditExpenseView(expense: expense) }
        }
        .navigationViewStyle(.stack)
    }
}



struct AddIncomeView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var manager: RentalManager
    
    @State private var description: String = ""
    @State private var amountString: String = ""
    @State private var date: Date = Date()
    @State private var selectedPropertyId: UUID?
    @State private var selectedTenantId: UUID?
    @State private var categoryId: UUID?

    var preselectedTenantId: UUID?
    var preselectedPropertyId: UUID?
    var preselectedAmount: Double?
    var preselectedDescription: String?
    var preselectedCategoryId: UUID?

    var body: some View {
        NavigationView {
            Form {
                Section("Income Details") {
                    Picker("Property", selection: $selectedPropertyId) {
                        Text("Unassigned").tag(UUID?.none)
                        ForEach(manager.properties) { Text($0.name).tag($0.id as UUID?) }
                    }
                    
                    Picker("Associated Tenant (Optional)", selection: $selectedTenantId) {
                        Text("None").tag(UUID?.none)
                        ForEach(manager.tenants) { Text($0.name).tag($0.id as UUID?) }
                    }
                    
                    TextField("Description", text: $description)
                    TextField("Amount", text: $amountString).keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    Picker("Category", selection: $categoryId) {
                        Text("Select a Category").tag(UUID?.none)
                        ForEach(manager.transactionCategories.filter { $0.type == .income }) { category in
                            Label(category.name, systemImage: category.iconName).tag(category.id as UUID?)
                        }
                    }
                }
            }
            .navigationTitle("Add Income")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!isFormValid) }
            }
            .onChange(of: selectedPropertyId) { _, newPropertyId in
                if preselectedTenantId == nil {
                    guard let newPropertyId = newPropertyId,
                          let property = manager.getProperty(byId: newPropertyId) else {
                        selectedTenantId = nil
                        return
                    }
                    selectedTenantId = property.tenantId
                }
            }
            .onAppear {
                if let id = preselectedTenantId { selectedTenantId = id }
                if let id = preselectedPropertyId { selectedPropertyId = id }
                if let amount = preselectedAmount { amountString = String(amount) }
                if let desc = preselectedDescription { description = desc }
                if let id = preselectedCategoryId { categoryId = id }
            }
        }
    }
    
    private var isFormValid: Bool {
        !(description.isEmpty || (Double(amountString) ?? 0) <= 0 || selectedPropertyId == nil || categoryId == nil)
    }
    
    private func save() {
        guard let propertyId = selectedPropertyId,
              let amount = Double(amountString) else { return }
        
        let newIncome = Income(description: description,
                               amount: amount,
                               date: date,
                               tenantId: selectedTenantId,
                               propertyId: propertyId,
                               categoryId: categoryId)
        manager.logIncome(income: newIncome)
        dismiss()
    }
}

struct AddExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var manager: RentalManager
    @State private var description = ""
    @State private var amountString = ""
    @State private var date = Date()
    @State private var selectedPropertyId: UUID?
    @State private var categoryId: UUID?
    @State private var selectedTenantId: UUID?

    var body: some View {
        NavigationView {
            Form {
                Section("Expense Details") {
                    Picker("Property", selection: $selectedPropertyId) {
                        Text("Unassigned").tag(UUID?.none)
                        ForEach(manager.properties) { Text($0.name).tag($0.id as UUID?) }
                    }
                    TextField("Description", text: $description)
                    TextField("Amount", text: $amountString).keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Category", selection: $categoryId) {
                        Text("Select a Category").tag(UUID?.none)
                        ForEach(manager.transactionCategories.filter { $0.type == .expense }) { category in
                            Label(category.name, systemImage: category.iconName).tag(category.id as UUID?)
                        }
                    }
                }
            }
            .navigationTitle("Add Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!isFormValid) }
            }
            .onChange(of: selectedPropertyId) { _, newPropertyId in
                guard let newPropertyId = newPropertyId,
                      let property = manager.getProperty(byId: newPropertyId) else {
                    selectedTenantId = nil
                    return
                }
                selectedTenantId = property.tenantId
            }
        }
    }
    
    private var isFormValid: Bool {
        !(description.isEmpty || (Double(amountString) ?? 0) <= 0 || selectedPropertyId == nil || categoryId == nil)
    }

    private func save() {
        guard let propertyId = selectedPropertyId, let amount = Double(amountString) else { return }
        let expense = Expense(description: description, amount: amount, date: date, propertyId: propertyId, categoryId: categoryId)
        manager.logExpense(expense: expense)
        dismiss()
    }
}

struct CategoriesView: View {
    @EnvironmentObject var manager: RentalManager
    @State private var showingAddCategory = false
    
    var incomeCategories: [TransactionCategory] {
        manager.transactionCategories.filter { $0.type == .income }.sorted { $0.name < $1.name }
    }
    
    var expenseCategories: [TransactionCategory] {
        manager.transactionCategories.filter { $0.type == .expense }.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            Section("Income Categories") {
                ForEach(incomeCategories) { category in
                    Label(category.name, systemImage: category.iconName)
                }
                .onDelete { offsets in
                    manager.deleteCategory(at: offsets, type: .income)
                }
            }
            
            Section("Expense Categories") {
                ForEach(expenseCategories) { category in
                    Label(category.name, systemImage: category.iconName)
                }
                .onDelete { offsets in
                    manager.deleteCategory(at: offsets, type: .expense)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Manage Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddCategory.toggle() } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView()
        }
    }
}

struct AddCategoryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var manager: RentalManager
    
    @State private var name: String = ""
    @State private var type: TransactionType = .expense
    @State private var iconName: String = "questionmark.circle.fill"
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category Details") {
                    TextField("Category Name", text: $name)
                    
                    HStack {
                        TextField("SF Symbol Name", text: $iconName)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        Image(systemName: iconName)
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                    Picker("Type", selection: $type) {
                        ForEach(TransactionType.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(name.isEmpty || iconName.isEmpty) }
            }
        }
    }
    
    private func save() {
        let newCategory = TransactionCategory(name: name, type: type, iconName: iconName)
        manager.addCategory(newCategory)
        dismiss()
    }
}

struct EditExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var manager: RentalManager
    
    @State private var expense: Expense
    @State private var amountString: String = ""
    
    init(expense: Expense) {
        _expense = State(initialValue: expense)
        _amountString = State(initialValue: String(expense.amount))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Expense Details") {
                    Picker("Property", selection: $expense.propertyId) {
                        Text("Unassigned").tag(nil as UUID?)
                        ForEach(manager.properties) { Text($0.name).tag($0.id as UUID?) }
                    }
                    TextField("Description", text: $expense.description)
                    TextField("Amount", text: $amountString).keyboardType(.decimalPad)
                    DatePicker("Date", selection: $expense.date, displayedComponents: .date)
                    Picker("Category", selection: $expense.categoryId) {
                        Text("Select a Category").tag(UUID?.none)
                        ForEach(manager.transactionCategories.filter { $0.type == .expense }) { category in
                            Label(category.name, systemImage: category.iconName).tag(category.id as UUID?)
                        }
                    }
                }
            }
            .navigationTitle("Edit Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
    }
    
    private func save() {
        if let amount = Double(amountString) {
            expense.amount = amount
            manager.updateExpense(expense)
            dismiss()
        }
    }
}
