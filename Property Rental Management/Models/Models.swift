//
//  Models.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//
import Foundation
import SwiftUI

struct AppData: Codable {
    var properties: [Property] = []
    var tenants: [Tenant] = []
    var incomes: [Income] = []
    var expenses: [Expense] = []
    var transactionCategories: [TransactionCategory] = []
    var maintenanceRequests: [MaintenanceRequest] = []
    var appointments: [Appointment] = []
}

enum TenantStatus: String, Codable, CaseIterable {
    case active = "Active"
    case archived = "Archived"
}

enum TransactionType: String, Codable, CaseIterable {
    case income = "Income"
    case expense = "Expense"
}

enum PaymentCycle: String, CaseIterable, Codable, Identifiable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    var id: String { self.rawValue }
}

enum PaymentStatus: String, CaseIterable {
    case paid = "Paid", due = "Due", overdue = "Overdue"
    var color: Color {
        switch self {
        case .paid: .green
        case .due: .orange
        case .overdue: .red
        }
    }
}

enum AppointmentStatus: String, Codable, CaseIterable, Identifiable {
    case scheduled = "Scheduled"
    case completed = "Completed"
    case canceled = "Canceled"
    var id: String { self.rawValue }
    
    var color: Color {
        switch self {
        case .scheduled: .blue
        case .completed: .green
        case .canceled: .gray
        }
    }
}


enum CurrencySymbol: String, CaseIterable, Identifiable {
    case usd = "$"
    case eur = "€"
    case gbp = "£"
    case jpy = "¥"
    var id: String { self.rawValue }
}

struct TransactionCategory: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var type: TransactionType
    var iconName: String
}

struct PropertyDeadline: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var expiryDate: Date
}

struct Property: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var address: String
    var rentAmount: Double
    var isVacant: Bool = true
    var tenantId: UUID?
    var imagesData: [Data] = []
    var paymentCycle: PaymentCycle = .monthly
    var deadlines: [PropertyDeadline] = []
}

struct Tenant: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var phone: String
    var email: String
    var leaseStartDate: Date = Date()
    var leaseEndDate: Date = Date()
    var propertyId: UUID?
    var nextDueDate: Date = Date()
    var imageData: Data?
    var amountOwed: Double = 0.0
    var depositAmount: Double = 0.0
    var isDepositPaid: Bool = false
    var status: TenantStatus = .active

    var paymentStatus: PaymentStatus {
        let today = Calendar.current.startOfDay(for: Date())
        let dueDate = Calendar.current.startOfDay(for: nextDueDate)
        if today > dueDate { return .overdue }
        if today == dueDate || (Calendar.current.date(byAdding: .day, value: -7, to: dueDate)! <= today) { return .due }
        return .paid
    }
}

struct Income: Identifiable, Codable, Hashable {
    var id = UUID()
    var description: String
    var amount: Double
    var date: Date = Date()
    var tenantId: UUID?
    var propertyId: UUID
    var categoryId: UUID?
}

struct Expense: Identifiable, Codable, Hashable {
    var id = UUID()
    var description: String
    var amount: Double
    var date: Date = Date()
    var propertyId: UUID
    var categoryId: UUID?
    var isBillableToTenant: Bool = false
}

struct MaintenanceRequest: Identifiable, Codable, Hashable {
    var id = UUID()
    var propertyId: UUID
    var description: String
    var isResolved: Bool = false
    var reportedDate: Date = Date()
}

struct Appointment: Identifiable, Codable, Hashable {
    var id = UUID()
    var propertyId: UUID
    var title: String
    var date: Date
    var status: AppointmentStatus = .scheduled
}
