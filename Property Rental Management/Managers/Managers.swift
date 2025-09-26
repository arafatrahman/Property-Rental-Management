//
//  Managers.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//
import Foundation
import Combine
import UserNotifications
import SwiftUI

// MARK: - Settings Manager
class SettingsManager: ObservableObject {
    @AppStorage("currencySymbol") var currencySymbolRaw: String = CurrencySymbol.usd.rawValue

    var currencySymbol: CurrencySymbol {
        get {
            CurrencySymbol(rawValue: currencySymbolRaw) ?? .usd
        }
        set {
            objectWillChange.send()
            currencySymbolRaw = newValue.rawValue
        }
    }
}


// MARK: - Rental Manager
@MainActor
class RentalManager: ObservableObject {
    @Published var properties: [Property] = []
    @Published var tenants: [Tenant] = []
    @Published var incomes: [Income] = []
    @Published var expenses: [Expense] = []
    @Published var transactionCategories: [TransactionCategory] = []
    @Published var maintenanceRequests: [MaintenanceRequest] = []
    @Published var appointments: [Appointment] = []
    @Published var reminderScheduledForTenantIDs: Set<UUID> = []

    private let propertiesKey = "propertiesKey", tenantsKey = "tenantsKey"
    private let incomesKey = "incomesKey", expensesKey = "expensesKey"
    private let maintenanceKey = "maintenanceKey", appointmentsKey = "appointmentsKey"
    private let categoriesKey = "categoriesKey"
    
    var totalProperties: Int { properties.count }
    var occupiedProperties: Int { properties.filter { !$0.isVacant }.count }
    var vacantProperties: Int { properties.filter { $0.isVacant }.count }
    var overdueTenantsCount: Int { tenants.filter { $0.paymentStatus == .overdue }.count }
    var dueSoonTenantsCount: Int { tenants.filter { $0.paymentStatus == .due }.count }
    var openMaintenanceRequests: Int { maintenanceRequests.filter { !$0.isResolved }.count }
    var upcomingAppointments: Int { appointments.filter { $0.date >= Date().startOfDay }.count }
    var totalIncome: Double { incomes.reduce(0) { $0 + $1.amount } }
    var totalExpenses: Double { expenses.reduce(0) { $0 + $1.amount } }
    var netIncome: Double { totalIncome - totalExpenses }
    
    init() {
        loadData()
        updateAllTenantBalances()
    }

    func saveData() {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        if let d = try? encoder.encode(properties) { UserDefaults.standard.set(d, forKey: propertiesKey) }
        if let d = try? encoder.encode(tenants) { UserDefaults.standard.set(d, forKey: tenantsKey) }
        if let d = try? encoder.encode(incomes) { UserDefaults.standard.set(d, forKey: incomesKey) }
        if let d = try? encoder.encode(expenses) { UserDefaults.standard.set(d, forKey: expensesKey) }
        if let d = try? encoder.encode(transactionCategories) { UserDefaults.standard.set(d, forKey: categoriesKey) }
        if let d = try? encoder.encode(maintenanceRequests) { UserDefaults.standard.set(d, forKey: maintenanceKey) }
        if let d = try? encoder.encode(appointments) { UserDefaults.standard.set(d, forKey: appointmentsKey) }
    }

    func loadData() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let d=UserDefaults.standard.data(forKey: propertiesKey), let dec=try? decoder.decode([Property].self, from:d){ properties = dec }
        if let d=UserDefaults.standard.data(forKey: tenantsKey), let dec=try? decoder.decode([Tenant].self, from:d){ tenants = dec }
        if let d=UserDefaults.standard.data(forKey: incomesKey), let dec=try? decoder.decode([Income].self, from:d){ incomes = dec }
        if let d=UserDefaults.standard.data(forKey: expensesKey), let dec=try? decoder.decode([Expense].self, from:d){ expenses = dec }
        if let d=UserDefaults.standard.data(forKey: categoriesKey), let dec=try? decoder.decode([TransactionCategory].self, from:d){ transactionCategories = dec }
        if let d=UserDefaults.standard.data(forKey: maintenanceKey), let dec=try? decoder.decode([MaintenanceRequest].self, from:d){ maintenanceRequests = dec }
        if let d=UserDefaults.standard.data(forKey: appointmentsKey), let dec=try? decoder.decode([Appointment].self, from:d){ appointments = dec }

        if transactionCategories.isEmpty { loadDefaultCategories() }
        if properties.isEmpty && tenants.isEmpty { loadMockData(); saveData() }
    }
    
    func updateAllTenantBalances() {
        for i in tenants.indices {
            recalculateBalance(forTenantId: tenants[i].id)
        }
        saveData()
    }
    
    func recalculateBalance(forTenantId tenantId: UUID) {
        guard let tenantIndex = tenants.firstIndex(where: { $0.id == tenantId }) else { return }
        
        let tenant = tenants[tenantIndex]
        
        guard let propertyId = tenant.propertyId,
              let property = getProperty(byId: propertyId) else {
            tenants[tenantIndex].amountOwed = 0
            return
        }

        var totalOwed: Double = 0
        var currentDate = tenant.leaseStartDate
        
        // 1. Calculate total rent charges from lease start to today
        while currentDate < Date() {
            totalOwed += property.rentAmount
            
            var component: Calendar.Component = .month
            var value = 1
            
            switch property.paymentCycle {
            case .daily: component = .day
            case .weekly: component = .day; value = 7
            case .monthly: component = .month
            case .yearly: component = .year
            }
            
            if let nextDate = Calendar.current.date(byAdding: component, value: value, to: currentDate) {
                currentDate = nextDate
            } else {
                break
            }
        }
        
        // 2. Add all billable expenses
        let totalBillableExpenses = expenses.filter { $0.propertyId == propertyId && $0.isBillableToTenant }.reduce(0) { $0 + $1.amount }
        totalOwed += totalBillableExpenses
        
        // 3. Subtract all payments made
        let totalPaid = incomes.filter { $0.tenantId == tenantId }.reduce(0) { $0 + $1.amount }
        
        // 4. Update tenant's balance and next due date
        tenants[tenantIndex].nextDueDate = currentDate
        tenants[tenantIndex].amountOwed = totalOwed - totalPaid
    }

    
    private func loadDefaultCategories() {
        transactionCategories = [
            TransactionCategory(name: "Rent Payment", type: .income, iconName: "house.fill"),
            TransactionCategory(name: "Late Fee", type: .income, iconName: "clock.badge.exclamationmark.fill"),
            TransactionCategory(name: "Parking", type: .income, iconName: "car.fill"),
            TransactionCategory(name: "Laundry", type: .income, iconName: "washer.fill"),
            TransactionCategory(name: "Other Income", type: .income, iconName: "dollarsign.circle.fill"),
            
            TransactionCategory(name: "Repairs", type: .expense, iconName: "wrench.and.screwdriver.fill"),
            TransactionCategory(name: "Utilities", type: .expense, iconName: "bolt.fill"),
            TransactionCategory(name: "Taxes", type: .expense, iconName: "building.columns.fill"),
            TransactionCategory(name: "Mortgage", type: .expense, iconName: "banknote.fill"),
            TransactionCategory(name: "Insurance", type: .expense, iconName: "shield.fill"),
            TransactionCategory(name: "Management", type: .expense, iconName: "person.2.badge.gearshape.fill"),
            TransactionCategory(name: "Landscaping", type: .expense, iconName: "leaf.fill"),
            TransactionCategory(name: "Other Expense", type: .expense, iconName: "creditcard.fill")
        ]
    }
    
    func addCategory(_ category: TransactionCategory) {
        transactionCategories.append(category)
        transactionCategories.sort { $0.name < $1.name }
        saveData()
    }
    
    func deleteCategory(at offsets: IndexSet, type: TransactionType) {
        let categoriesToDelete = transactionCategories.filter({$0.type == type}).sorted(by: { $0.name < $1.name })
        let idsToDelete = offsets.map { categoriesToDelete[$0].id }
        transactionCategories.removeAll { idsToDelete.contains($0.id) }
        saveData()
    }
    
    func getCategory(byId id: UUID?) -> TransactionCategory? {
        guard let id = id else { return nil }
        return transactionCategories.first { $0.id == id }
    }
    
    func saveTenant(tenant: Tenant) {
        var finalTenant = tenant
        if finalTenant.nextDueDate == finalTenant.leaseEndDate, finalTenant.nextDueDate < Date() {
            finalTenant.nextDueDate = finalTenant.leaseStartDate
        }

        if let propertyId = finalTenant.propertyId, let propIndex = properties.firstIndex(where: { $0.id == propertyId }) {
            properties[propIndex].isVacant = false
            properties[propIndex].tenantId = finalTenant.id
        }
        if let index = tenants.firstIndex(where: { $0.id == finalTenant.id }) {
            let oldTenant = tenants[index]
            if let oldPropId = oldTenant.propertyId, oldPropId != finalTenant.propertyId, let propIndex = properties.firstIndex(where: { $0.id == oldPropId }) {
                properties[propIndex].isVacant = true
                properties[propIndex].tenantId = nil
            }
            tenants[index] = finalTenant
        } else {
            tenants.append(finalTenant)
        }
        saveData()
    }
    
    func deleteTenant(at offsets: IndexSet) {
        let tenantsToDelete = offsets.map { tenants[$0] }
        for tenant in tenantsToDelete {
            NotificationManager.instance.cancelNotification(for: tenant.id)
            reminderScheduledForTenantIDs.remove(tenant.id)
        }
        let idsToDelete = tenantsToDelete.map { $0.id }
        properties = properties.map { property in
            var mutableProperty = property
            if let tenantId = mutableProperty.tenantId, idsToDelete.contains(tenantId) {
                mutableProperty.isVacant = true
                mutableProperty.tenantId = nil
            }
            return mutableProperty
        }
        incomes.removeAll { income in
            if let tenantId = income.tenantId {
                return idsToDelete.contains(tenantId)
            }
            return false
        }
        tenants.remove(atOffsets: offsets)
        saveData()
    }

    func logIncome(income: Income) {
        incomes.insert(income, at: 0)
        
        if let tenantId = income.tenantId {
            recalculateBalance(forTenantId: tenantId)
        }
        saveData()
    }

    func updateIncome(_ income: Income) {
        guard let index = incomes.firstIndex(where: { $0.id == income.id }) else { return }
        let oldIncome = incomes[index]
        incomes[index] = income
        
        if let oldTenantId = oldIncome.tenantId, oldTenantId != income.tenantId {
            recalculateBalance(forTenantId: oldTenantId)
        }
        if let currentTenantId = income.tenantId {
             recalculateBalance(forTenantId: currentTenantId)
        }
        saveData()
    }
    
    func deleteIncome(_ income: Income) {
        incomes.removeAll { $0.id == income.id }
        if let tenantId = income.tenantId {
            recalculateBalance(forTenantId: tenantId)
        }
        saveData()
    }
    
    func logExpense(expense: Expense) {
        expenses.insert(expense, at: 0)
        saveData()
    }

    func updateExpense(_ expense: Expense) {
        guard let index = expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        expenses[index] = expense
        saveData()
    }

    func deleteExpense(_ expense: Expense) {
        expenses.removeAll { $0.id == expense.id }
        saveData()
    }
    
    func scheduleReminder(for tenant: Tenant) {
        guard let property = getProperty(for: tenant) else { return }
        NotificationManager.instance.scheduleNotification(for: tenant, property: property)
        reminderScheduledForTenantIDs.insert(tenant.id)
    }

    func addMaintenanceRequest(_ request: MaintenanceRequest) {
        maintenanceRequests.insert(request, at: 0)
        saveData()
    }
    
    func updateMaintenanceRequest(_ request: MaintenanceRequest) {
        if let index = maintenanceRequests.firstIndex(where: { $0.id == request.id }) {
            maintenanceRequests[index] = request
            saveData()
        }
    }

    func resolveMaintenanceRequest(_ request: MaintenanceRequest) {
        if let index = maintenanceRequests.firstIndex(where: { $0.id == request.id }) {
            maintenanceRequests[index].isResolved = true
            saveData()
        }
    }
    
    func deleteMaintenanceRequest(at offsets: IndexSet) {
        let maintenanceRequestsToDelete = offsets.map { maintenanceRequests[$0] }
        let idsToDelete = maintenanceRequestsToDelete.map { $0.id }
        maintenanceRequests.removeAll { idsToDelete.contains($0.id) }
        saveData()
    }

    func addAppointment(_ appointment: Appointment) {
        appointments.append(appointment)
        appointments.sort(by: { $0.date < $1.date })
        NotificationManager.instance.scheduleAppointmentReminder(for: appointment)
        saveData()
    }
    
    func updateAppointment(_ appointment: Appointment) {
        guard let index = appointments.firstIndex(where: { $0.id == appointment.id }) else { return }
        appointments[index] = appointment
        appointments.sort(by: { $0.date < $1.date })
        NotificationManager.instance.cancelAppointmentReminder(for: appointment.id)
        NotificationManager.instance.scheduleAppointmentReminder(for: appointment)
        saveData()
    }

    func deleteAppointment(_ appointment: Appointment) {
        appointments.removeAll { $0.id == appointment.id }
        NotificationManager.instance.cancelAppointmentReminder(for: appointment.id)
        saveData()
    }
    
    func saveProperty(property: Property) {
        if let index = properties.firstIndex(where: { $0.id == property.id }) {
            properties[index] = property
        } else {
            properties.append(property)
        }
        saveData()
    }
    
    func deleteProperty(at offsets: IndexSet) {
        let idsToDelete = offsets.map { properties[$0].id }
        tenants = tenants.map { tenant in
            var mutableTenant = tenant
            if let propId = mutableTenant.propertyId, idsToDelete.contains(propId) {
                mutableTenant.propertyId = nil
            }
            return mutableTenant
        }
        incomes.removeAll { idsToDelete.contains($0.propertyId) }
        expenses.removeAll { idsToDelete.contains($0.propertyId) }
        maintenanceRequests.removeAll { idsToDelete.contains($0.propertyId) }
        properties.remove(atOffsets: offsets)
        saveData()
    }
    
    func getTenant(for property: Property) -> Tenant? { tenants.first { $0.id == property.tenantId } }
    func getProperty(for tenant: Tenant) -> Property? { properties.first { $0.id == tenant.propertyId } }
    func getTenant(byId id: UUID) -> Tenant? { tenants.first { $0.id == id } }
    func getProperty(byId id: UUID) -> Property? { properties.first { $0.id == id } }
    
    private func loadMockData() {
        let t1Id=UUID(), t2Id=UUID(), t3Id=UUID(); let p1Id=UUID(), p2Id=UUID(), p3Id=UUID()
        let today = Date(); let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: today)!
        let overdueDate = Calendar.current.date(byAdding: .day, value: -3, to: today)!
        let prop1 = Property(id:p1Id, name:"Sunrise Villa", address:"123 Sunny Lane", rentAmount:2500, isVacant:false, tenantId:t1Id, paymentCycle: .monthly)
        let prop2 = Property(id:p2Id, name:"Downtown Loft", address:"456 Urban St", rentAmount:1800, isVacant:false, tenantId:t2Id, paymentCycle: .monthly)
        let prop3 = Property(id:p3Id, name:"Oakside Cottage", address:"789 Forest Rd", rentAmount:2100, isVacant:false, tenantId: t3Id, paymentCycle: .weekly)
        properties = [prop1, prop2, prop3]
        tenants = [Tenant(id:t1Id, name:"John Appleseed", phone:"555-123-4567", email:"john@example.com", propertyId:p1Id, nextDueDate: today), Tenant(id:t2Id, name:"Jane Doe", phone:"555-987-6543", email:"jane@example.com", propertyId:p2Id, nextDueDate:overdueDate, amountOwed: 1800), Tenant(id:t3Id, name:"Peter Jones", phone:"555-555-5555", email:"peter@example.com", propertyId: p3Id, nextDueDate: Calendar.current.date(byAdding: .day, value: 10, to: today)!)]
        
        let rentCategoryId = transactionCategories.first { $0.name == "Rent Payment" }?.id
        incomes = [Income(description: "Rent", amount:2500, date:lastMonth, tenantId:t1Id, propertyId:p1Id, categoryId: rentCategoryId), Income(description: "Rent", amount:1800, date:lastMonth, tenantId:t2Id, propertyId:p2Id, categoryId: rentCategoryId), Income(description: "Rent", amount:2500, date: today, tenantId:t1Id, propertyId:p1Id, categoryId: rentCategoryId)]
        
        let repairCategoryId = transactionCategories.first { $0.name == "Repairs" }?.id
        expenses = [Expense(description:"Plumbing Repair", amount:350.00, date:Calendar.current.date(byAdding: .day, value:-10, to:today)!, propertyId:p1Id, categoryId: repairCategoryId), Expense(description:"Lawn Care", amount:75.00, date:Calendar.current.date(byAdding:.day, value:-5, to:today)!, propertyId:p3Id)]
        
        maintenanceRequests = [MaintenanceRequest(propertyId: p2Id, description: "Leaky faucet in kitchen", isResolved: false, reportedDate: Calendar.current.date(byAdding: .day, value: -2, to: today)!)]
        appointments = [Appointment(property: prop1, title: "Prospective Tenant Viewing", date: Calendar.current.date(byAdding: .day, value: 1, to: today)!, status: .scheduled)]
    }
}


// MARK: - Notification Manager
class NotificationManager {
    static let instance = NotificationManager() // Singleton

    func requestAuthorization() {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { (success, error) in
            if let error = error {
                print("ERROR: \(error)")
            } else {
                print("Notification permissions granted.")
            }
        }
    }

    func scheduleNotification(for tenant: Tenant, property: Property) {
        let content = UNMutableNotificationContent()
        content.title = "Rent Reminder"
        content.subtitle = "Your payment for \(property.name) is due soon."
        content.body = "A payment of \(property.rentAmount.formatted(.currency(code: "USD"))) is due on \(tenant.nextDueDate.formatted(date: .abbreviated, time: .omitted)). Please make a payment to avoid any late fees."
        content.sound = .default

        guard let reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: tenant.nextDueDate) else { return }
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: reminderDate)
        dateComponents.hour = 12
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "rent-\(tenant.id.uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleAppointmentReminder(for appointment: Appointment) {
        let content = UNMutableNotificationContent()
        content.title = "Appointment Reminder"
        content.subtitle = appointment.title
        content.body = "You have an appointment for \(appointment.property.name) in 1 hour."
        content.sound = .default

        let triggerDate = appointment.date.addingTimeInterval(-3600) // 1 hour before
        guard triggerDate > Date() else { return } // Don't schedule for past appointments
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerDate.timeIntervalSinceNow, repeats: false)
        let request = UNNotificationRequest(identifier: "appt-\(appointment.id.uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelNotification(for tenantId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rent-\(tenantId.uuidString)"])
    }
    
    func cancelAppointmentReminder(for appointmentId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["appt-\(appointmentId.uuidString)"])
    }
}
