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

    @AppStorage("enablePaymentReminders") private var enablePaymentReminders: Bool = true
    @AppStorage("enableAppointmentReminders") private var enableAppointmentReminders: Bool = true
    @AppStorage("enableLeaseExpiryReminders") private var enableLeaseExpiryReminders: Bool = true
    @AppStorage("enableMaintenanceReminders") private var enableMaintenanceReminders: Bool = true
    @AppStorage("enableDeadlineReminders") private var enableDeadlineReminders: Bool = true
    
    private var dataFileURL: URL {
        do {
            let documentsDirectory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            return documentsDirectory.appendingPathComponent("RentalManagementData.json")
        } catch {
            fatalError("Could not find or create documents directory.")
        }
    }
    
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
        let appData = AppData(
            properties: self.properties,
            tenants: self.tenants,
            incomes: self.incomes,
            expenses: self.expenses,
            transactionCategories: self.transactionCategories,
            maintenanceRequests: self.maintenanceRequests,
            appointments: self.appointments
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(appData)
            try data.write(to: dataFileURL, options: [.atomicWrite, .completeFileProtection])
        } catch {
            print("Error saving data: \(error.localizedDescription)")
        }
    }

    func loadData() {
        guard FileManager.default.fileExists(atPath: dataFileURL.path) else {
            if transactionCategories.isEmpty { loadDefaultCategories() }
            return
        }
        
        do {
            let data = try Data(contentsOf: dataFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let appData = try decoder.decode(AppData.self, from: data)
            
            self.properties = appData.properties
            self.tenants = appData.tenants
            self.incomes = appData.incomes
            self.expenses = appData.expenses
            self.transactionCategories = appData.transactionCategories
            self.maintenanceRequests = appData.maintenanceRequests
            self.appointments = appData.appointments
            
            if self.transactionCategories.isEmpty { loadDefaultCategories() }
            
        } catch {
            print("Error loading data: \(error.localizedDescription)")
            if transactionCategories.isEmpty { loadDefaultCategories() }
        }
    }
    
    func exportData() -> Data? {
        do {
            let data = try Data(contentsOf: dataFileURL)
            return data
        } catch {
            print("Could not read data file for export: \(error.localizedDescription)")
            return nil
        }
    }

    func importData(from data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let appData = try decoder.decode(AppData.self, from: data)
            self.properties = appData.properties
            self.tenants = appData.tenants
            self.incomes = appData.incomes
            self.expenses = appData.expenses
            self.transactionCategories = appData.transactionCategories
            self.maintenanceRequests = appData.maintenanceRequests
            self.appointments = appData.appointments
            
            saveData()
            
        } catch {
            print("Error importing data: \(error.localizedDescription)")
        }
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
        
        let totalBillableExpenses = expenses.filter { $0.propertyId == propertyId && $0.isBillableToTenant }.reduce(0) { $0 + $1.amount }
        totalOwed += totalBillableExpenses
        
        let depositCategory = transactionCategories.first { $0.name == "Security Deposit" }
        let totalPaid = incomes.filter {
            $0.tenantId == tenantId && $0.categoryId != depositCategory?.id
        }.reduce(0) { $0 + $1.amount }
        
        tenants[tenantIndex].nextDueDate = currentDate
        tenants[tenantIndex].amountOwed = totalOwed - totalPaid
    }

    
    private func loadDefaultCategories() {
        transactionCategories = [
            TransactionCategory(name: "Rent Payment", type: .income, iconName: "house.fill"),
            TransactionCategory(name: "Late Fee", type: .income, iconName: "clock.badge.exclamationmark.fill"),
            TransactionCategory(name: "Parking", type: .income, iconName: "car.fill"),
            TransactionCategory(name: "Laundry", type: .income, iconName: "washer.fill"),
            TransactionCategory(name: "Security Deposit", type: .income, iconName: "shield.lefthalf.filled"),
            TransactionCategory(name: "Other Income", type: .income, iconName: "dollarsign.circle.fill"),
            
            TransactionCategory(name: "Repairs", type: .expense, iconName: "wrench.and.screwdriver.fill"),
            TransactionCategory(name: "Utilities", type: .expense, iconName: "bolt.fill"),
            TransactionCategory(name: "Taxes", type: .expense, iconName: "building.columns.fill"),
            TransactionCategory(name: "Mortgage", type: .expense, iconName: "banknote.fill"),
            TransactionCategory(name: "Insurance", type: .expense, iconName: "shield.fill"),
            TransactionCategory(name: "Management", type: .expense, iconName: "person.2.badge.gearshape.fill"),
            TransactionCategory(name: "Deposit Refund", type: .expense, iconName: "shield.slash"),
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
        
        NotificationManager.instance.cancelLeaseExpiryNotification(for: finalTenant)
        if enableLeaseExpiryReminders {
            NotificationManager.instance.scheduleLeaseExpiryNotification(for: finalTenant)
        }
        
        saveData()
    }
    
    func deleteTenant(at offsets: IndexSet) {
        let tenantsToDelete = offsets.map { tenants[$0] }
        for tenant in tenantsToDelete {
            NotificationManager.instance.cancelNotification(for: tenant.id)
            NotificationManager.instance.cancelLeaseExpiryNotification(for: tenant)
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
        
        if let categoryId = income.categoryId, let category = getCategory(byId: categoryId), category.name == "Security Deposit" {
            if let tenantId = income.tenantId, let tenantIndex = tenants.firstIndex(where: { $0.id == tenantId }) {
                tenants[tenantIndex].isDepositPaid = true
            }
        }
        
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
            updateDepositStatus(for: oldTenantId)
        }
        if let currentTenantId = income.tenantId {
             recalculateBalance(forTenantId: currentTenantId)
             updateDepositStatus(for: currentTenantId)
        }
        saveData()
    }
    
    func deleteIncome(_ income: Income) {
        let wasDepositPayment = (getCategory(byId: income.categoryId)?.name ?? "") == "Security Deposit"

        incomes.removeAll { $0.id == income.id }
        
        if let tenantId = income.tenantId {
            if wasDepositPayment {
                updateDepositStatus(for: tenantId)
            }
            recalculateBalance(forTenantId: tenantId)
        }
        saveData()
    }
    
    private func updateDepositStatus(for tenantId: UUID) {
        guard let tenantIndex = tenants.firstIndex(where: { $0.id == tenantId }) else { return }
        
        let depositCategory = transactionCategories.first { $0.name == "Security Deposit" }
        let hasDepositPayment = incomes.contains {
            $0.tenantId == tenantId && $0.categoryId == depositCategory?.id
        }
        
        tenants[tenantIndex].isDepositPaid = hasDepositPayment
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
        guard enablePaymentReminders else { return }
        
        guard let property = getProperty(for: tenant) else { return }
        NotificationManager.instance.scheduleNotification(for: tenant, property: property)
        reminderScheduledForTenantIDs.insert(tenant.id)
    }

    func addMaintenanceRequest(_ request: MaintenanceRequest) {
        maintenanceRequests.insert(request, at: 0)
        if enableMaintenanceReminders {
            NotificationManager.instance.scheduleMaintenanceFollowUp(for: request)
        }
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
            NotificationManager.instance.cancelMaintenanceFollowUp(for: request)
            saveData()
        }
    }
    
    func deleteMaintenanceRequest(at offsets: IndexSet) {
        let openRequests = maintenanceRequests.filter { !$0.isResolved }
        let requestsToDelete = offsets.map { openRequests[$0] }
        let idsToDelete = Set(requestsToDelete.map { $0.id })
        
        for request in requestsToDelete {
            NotificationManager.instance.cancelMaintenanceFollowUp(for: request)
        }
        
        maintenanceRequests.removeAll { idsToDelete.contains($0.id) }
        saveData()
    }

    func addAppointment(_ appointment: Appointment) {
        appointments.append(appointment)
        appointments.sort(by: { $0.date < $1.date })
        
        if enableAppointmentReminders {
            NotificationManager.instance.scheduleAppointmentReminder(for: appointment)
        }
        saveData()
    }
    
    func updateAppointment(_ appointment: Appointment) {
        guard let index = appointments.firstIndex(where: { $0.id == appointment.id }) else { return }
        appointments[index] = appointment
        appointments.sort(by: { $0.date < $1.date })
        
        NotificationManager.instance.cancelAppointmentReminder(for: appointment.id)
        
        if enableAppointmentReminders {
            NotificationManager.instance.scheduleAppointmentReminder(for: appointment)
        }
        saveData()
    }

    func deleteAppointment(_ appointment: Appointment) {
        appointments.removeAll { $0.id == appointment.id }
        NotificationManager.instance.cancelAppointmentReminder(for: appointment.id)
        saveData()
    }
    
    func saveProperty(property: Property) {
        let oldProperty = getProperty(byId: property.id)
        
        if let index = properties.firstIndex(where: { $0.id == property.id }) {
            properties[index] = property
        } else {
            properties.append(property)
        }
        
        if let old = oldProperty {
            NotificationManager.instance.cancelAllDeadlineNotifications(forProperty: old)
        }
        if enableDeadlineReminders {
            for deadline in property.deadlines {
                NotificationManager.instance.schedulePropertyDeadlineNotification(for: property, deadline: deadline)
            }
        }
        saveData()
    }
    
    func deleteProperty(at offsets: IndexSet) {
        let propertiesToDelete = offsets.map { properties[$0] }
        for property in propertiesToDelete {
            NotificationManager.instance.cancelAllDeadlineNotifications(forProperty: property)
        }
        
        let idsToDelete = propertiesToDelete.map { $0.id }
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
}

class NotificationManager {
    static let instance = NotificationManager()

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

        let triggerDate = appointment.date.addingTimeInterval(-3600)
        guard triggerDate > Date() else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerDate.timeIntervalSinceNow, repeats: false)
        let request = UNNotificationRequest(identifier: "appt-\(appointment.id.uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleLeaseExpiryNotification(for tenant: Tenant) {
        let content = UNMutableNotificationContent()
        content.title = "Lease Expiry Reminder"
        content.body = "The lease for \(tenant.name) is ending on \(tenant.leaseEndDate.formatted(date: .abbreviated, time: .omitted))."
        content.sound = .default

        guard let reminderDate = Calendar.current.date(byAdding: .day, value: -60, to: tenant.leaseEndDate) else { return }
        guard reminderDate > Date() else { return }
        
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: reminderDate)
        dateComponents.hour = 9

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "lease-\(tenant.id.uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleMaintenanceFollowUp(for request: MaintenanceRequest) {
        let content = UNMutableNotificationContent()
        content.title = "Maintenance Follow-up"
        content.body = "The maintenance request '\(request.description)' has been open for 3 days."
        content.sound = .default

        guard let reminderDate = Calendar.current.date(byAdding: .day, value: 3, to: request.reportedDate) else { return }
        guard reminderDate > Date() else { return }

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: reminderDate)
        dateComponents.hour = 9
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let notificationRequest = UNNotificationRequest(identifier: "maintenance-\(request.id.uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(notificationRequest)
    }
    
    func schedulePropertyDeadlineNotification(for property: Property, deadline: PropertyDeadline) {
        let content = UNMutableNotificationContent()
        content.title = "Property Deadline Reminder"
        content.body = "'\(deadline.title)' for \(property.name) is due on \(deadline.expiryDate.formatted(date: .abbreviated, time: .omitted))."
        content.sound = .default
        
        guard let reminderDate = Calendar.current.date(byAdding: .day, value: -30, to: deadline.expiryDate) else { return }
        guard reminderDate > Date() else { return }

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: reminderDate)
        dateComponents.hour = 9

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "deadline-\(property.id.uuidString)-\(deadline.id.uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelNotification(for tenantId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rent-\(tenantId.uuidString)"])
    }
    
    func cancelAppointmentReminder(for appointmentId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["appt-\(appointmentId.uuidString)"])
    }
    
    func cancelLeaseExpiryNotification(for tenant: Tenant) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["lease-\(tenant.id.uuidString)"])
    }
    
    func cancelMaintenanceFollowUp(for request: MaintenanceRequest) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["maintenance-\(request.id.uuidString)"])
    }
    
    func cancelPropertyDeadlineNotification(for property: Property, deadline: PropertyDeadline) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["deadline-\(property.id.uuidString)-\(deadline.id.uuidString)"])
    }
    
    func cancelAllDeadlineNotifications(forProperty property: Property) {
        let identifiers = property.deadlines.map { "deadline-\(property.id.uuidString)-\($0.id.uuidString)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
