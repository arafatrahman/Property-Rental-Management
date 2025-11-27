//
//  Models.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//
import Foundation
import SwiftUI
import UIKit // Required for image processing

// MARK: - App Data Container
struct AppData: Codable {
    var properties: [Property] = []
    var tenants: [Tenant] = []
    var incomes: [Income] = []
    var expenses: [Expense] = []
    var transactionCategories: [TransactionCategory] = []
    var maintenanceRequests: [MaintenanceRequest] = []
    var appointments: [Appointment] = []
}

// MARK: - Image Compression Helper
// Aggressively compresses images to ensure the 1MB Firestore limit is respected.
func compressImage(_ data: Data, maxDimension: CGFloat = 350, quality: CGFloat = 0.5) -> Data {
    guard let image = UIImage(data: data) else { return data }
    
    // Calculate new size maintaining aspect ratio
    let size = image.size
    let ratio = min(maxDimension/size.width, maxDimension/size.height)
    
    // If image is already small enough, just return JPEG data
    if ratio >= 1.0 {
        return image.jpegData(compressionQuality: quality) ?? data
    }
    
    // Resize the image
    let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
    let renderer = UIGraphicsImageRenderer(size: newSize)
    let resizedImage = renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
    
    // Return compressed JPEG
    return resizedImage.jpegData(compressionQuality: quality) ?? data
}

// MARK: - Enums
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

// MARK: - Sub-Models
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

// MARK: - Property Model
struct Property: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var address: String
    var rentAmount: Double
    var isVacant: Bool = true
    var tenantId: UUID?
    
    // Stores compressed Base64 strings to avoid Firestore nested array errors
    var encodedImages: [String] = []
    
    var paymentCycle: PaymentCycle = .monthly
    var deadlines: [PropertyDeadline] = []
    
    enum CodingKeys: String, CodingKey {
        case id, name, address, rentAmount, isVacant, tenantId, paymentCycle, deadlines
        case encodedImages = "imagesData" // Maps to existing JSON data
    }
    
    // Computed property for UI usage
    var imagesData: [Data] {
        get {
            encodedImages.compactMap { Data(base64Encoded: $0, options: .ignoreUnknownCharacters) }
        }
        set {
            // Compress and encode new images immediately
            encodedImages = newValue.map { compressImage($0).base64EncodedString() }
        }
    }
    
    // Standard Init
    init(id: UUID = UUID(), name: String, address: String, rentAmount: Double, isVacant: Bool = true, tenantId: UUID? = nil, imagesData: [Data] = [], paymentCycle: PaymentCycle = .monthly, deadlines: [PropertyDeadline] = []) {
        self.id = id
        self.name = name
        self.address = address
        self.rentAmount = rentAmount
        self.isVacant = isVacant
        self.tenantId = tenantId
        self.paymentCycle = paymentCycle
        self.deadlines = deadlines
        self.encodedImages = imagesData.map { compressImage($0).base64EncodedString() }
    }
    
    // Decoder Init (Crucial for fixing existing data)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decode(String.self, forKey: .address)
        rentAmount = try container.decode(Double.self, forKey: .rentAmount)
        isVacant = try container.decode(Bool.self, forKey: .isVacant)
        tenantId = try container.decodeIfPresent(UUID.self, forKey: .tenantId)
        paymentCycle = try container.decode(PaymentCycle.self, forKey: .paymentCycle)
        deadlines = try container.decode([PropertyDeadline].self, forKey: .deadlines)
        
        // Clean existing data: Decode strings, compress them, and re-store
        let rawImages = try container.decode([String].self, forKey: .encodedImages)
        self.encodedImages = rawImages.compactMap { str in
            guard let data = Data(base64Encoded: str, options: .ignoreUnknownCharacters) else { return nil }
            // Apply compression to existing images loaded from disk
            return compressImage(data).base64EncodedString()
        }
    }
    
    // Encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(address, forKey: .address)
        try container.encode(rentAmount, forKey: .rentAmount)
        try container.encode(isVacant, forKey: .isVacant)
        try container.encode(tenantId, forKey: .tenantId)
        try container.encode(paymentCycle, forKey: .paymentCycle)
        try container.encode(deadlines, forKey: .deadlines)
        try container.encode(encodedImages, forKey: .encodedImages)
    }
}

// MARK: - Tenant Model
struct Tenant: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var phone: String
    var email: String
    var leaseStartDate: Date = Date()
    var leaseEndDate: Date = Date()
    var propertyId: UUID?
    var nextDueDate: Date = Date()
    
    // Stores compressed Base64 string
    var encodedImage: String?
    
    var amountOwed: Double = 0.0
    var depositAmount: Double = 0.0
    var isDepositPaid: Bool = false
    var status: TenantStatus = .active

    enum CodingKeys: String, CodingKey {
        case id, name, phone, email, leaseStartDate, leaseEndDate, propertyId, nextDueDate
        case encodedImage = "imageData" // Maps to existing JSON data
        case amountOwed, depositAmount, isDepositPaid, status
    }

    var imageData: Data? {
        get {
            guard let string = encodedImage else { return nil }
            return Data(base64Encoded: string, options: .ignoreUnknownCharacters)
        }
        set {
            if let data = newValue {
                encodedImage = compressImage(data).base64EncodedString()
            } else {
                encodedImage = nil
            }
        }
    }

    var paymentStatus: PaymentStatus {
        let today = Calendar.current.startOfDay(for: Date())
        let dueDate = Calendar.current.startOfDay(for: nextDueDate)
        if today > dueDate { return .overdue }
        if today == dueDate || (Calendar.current.date(byAdding: .day, value: -7, to: dueDate)! <= today) { return .due }
        return .paid
    }
    
    // Standard Init
    init(id: UUID = UUID(), name: String, phone: String, email: String, leaseStartDate: Date = Date(), leaseEndDate: Date = Date(), propertyId: UUID? = nil, nextDueDate: Date = Date(), imageData: Data? = nil, amountOwed: Double = 0.0, depositAmount: Double = 0.0, isDepositPaid: Bool = false, status: TenantStatus = .active) {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.leaseStartDate = leaseStartDate
        self.leaseEndDate = leaseEndDate
        self.propertyId = propertyId
        self.nextDueDate = nextDueDate
        self.amountOwed = amountOwed
        self.depositAmount = depositAmount
        self.isDepositPaid = isDepositPaid
        self.status = status
        
        if let data = imageData {
            self.encodedImage = compressImage(data).base64EncodedString()
        } else {
            self.encodedImage = nil
        }
    }
    
    // Decoder Init (Crucial for fixing existing data)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        phone = try container.decode(String.self, forKey: .phone)
        email = try container.decode(String.self, forKey: .email)
        leaseStartDate = try container.decode(Date.self, forKey: .leaseStartDate)
        leaseEndDate = try container.decode(Date.self, forKey: .leaseEndDate)
        propertyId = try container.decodeIfPresent(UUID.self, forKey: .propertyId)
        nextDueDate = try container.decode(Date.self, forKey: .nextDueDate)
        amountOwed = try container.decode(Double.self, forKey: .amountOwed)
        depositAmount = try container.decode(Double.self, forKey: .depositAmount)
        isDepositPaid = try container.decode(Bool.self, forKey: .isDepositPaid)
        status = try container.decode(TenantStatus.self, forKey: .status)
        
        // Clean existing image
        if let str = try container.decodeIfPresent(String.self, forKey: .encodedImage),
           let data = Data(base64Encoded: str, options: .ignoreUnknownCharacters) {
            self.encodedImage = compressImage(data).base64EncodedString()
        } else {
            self.encodedImage = nil
        }
    }
    
    // Encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(phone, forKey: .phone)
        try container.encode(email, forKey: .email)
        try container.encode(leaseStartDate, forKey: .leaseStartDate)
        try container.encode(leaseEndDate, forKey: .leaseEndDate)
        try container.encode(propertyId, forKey: .propertyId)
        try container.encode(nextDueDate, forKey: .nextDueDate)
        try container.encode(amountOwed, forKey: .amountOwed)
        try container.encode(depositAmount, forKey: .depositAmount)
        try container.encode(isDepositPaid, forKey: .isDepositPaid)
        try container.encode(status, forKey: .status)
        try container.encode(encodedImage, forKey: .encodedImage)
    }
}

// MARK: - Other Models (Unchanged)
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
