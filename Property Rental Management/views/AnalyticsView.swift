//
//  AnalyticsView.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 28/09/2025.
//

import SwiftUI
import Charts

// MARK: - Helper Structs for Chart Data
struct FinancialPeriodData: Identifiable {
    let id = UUID()
    let date: Date
    var income: Double = 0
    var expense: Double = 0
}

struct CategorySummary: Identifiable {
    let id = UUID()
    let categoryName: String
    let totalAmount: Double
}

struct PropertyProfitability: Identifiable {
    let id = UUID()
    let propertyName: String
    let netProfit: Double
}


// MARK: - Main Analytics View
struct AnalyticsView: View {
    @EnvironmentObject var manager: RentalManager
    
    @State private var filterType: AnalyticsFilterType = .yearly
    @State private var selectedDate = Date()
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var endDate = Date()

    @State private var showingMonthYearSheet = false
    @State private var showingYearSheet = false

    // ✅ MODIFIED: Removed the 'weekly' case.
    enum AnalyticsFilterType: String, CaseIterable, Identifiable {
        case daily = "Daily"
        case monthly = "Monthly"
        case yearly = "Yearly"
        case customRange = "Custom"
        case allTime = "All Time"
        var id: String { self.rawValue }
    }
    
    // MARK: - Body View
    var body: some View {
        List {
            // MARK: Filter Section
            Section("Filter Options") {
                Picker("Filter by", selection: $filterType.animation()) {
                    ForEach(AnalyticsFilterType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                
                // ✅ MODIFIED: Removed the 'weekly' case from the switch.
                switch filterType {
                case .daily:
                    DatePicker(filterType.rawValue, selection: $selectedDate, displayedComponents: .date)
                case .monthly:
                    HStack {
                        Text("Month")
                        Spacer()
                        Button(selectedDate.formatted(.dateTime.month(.wide).year())) {
                            showingMonthYearSheet = true
                        }
                        .foregroundColor(.primary)
                    }
                case .yearly:
                    HStack {
                        Text("Year")
                        Spacer()
                        Button(selectedDate.formatted(.dateTime.year())) {
                            showingYearSheet = true
                        }
                        .foregroundColor(.primary)
                    }
                case .customRange:
                    DatePicker("Start Date", selection: $startDate, in: ...endDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                case .allTime:
                    EmptyView()
                }
            }
            
            // MARK: Financial Overview Chart
            Section("Financial Overview (\(dateRangeDescription))") {
                if financialSummary.isEmpty {
                    Text("No financial data for this period.")
                } else {
                    let (groupingUnit, timeUnit) = chartGroupingParameters
                    Chart(financialSummary) { dataPoint in
                        BarMark(
                            x: .value("Date", dataPoint.date, unit: timeUnit),
                            y: .value("Amount", dataPoint.income)
                        )
                        .foregroundStyle(Color.green.gradient)
                        
                        BarMark(
                            x: .value("Date", dataPoint.date, unit: timeUnit),
                            y: .value("Amount", dataPoint.expense)
                        )
                        .foregroundStyle(Color.red.gradient)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: groupingUnit)) { value in
                            AxisGridLine()
                            AxisTick()
                            if groupingUnit == .month {
                                AxisValueLabel(format: .dateTime.month(.narrow))
                            } else {
                                AxisValueLabel(format: .dateTime.day())
                            }
                        }
                    }
                    .frame(height: 250)
                    
                    HStack {
                        Circle().fill(.green).frame(width: 10, height: 10)
                        Text("Income")
                        Spacer()
                        Circle().fill(.red).frame(width: 10, height: 10)
                        Text("Expense")
                    }.font(.caption)
                }
            }

            // MARK: Expense Breakdown Chart
            Section("Expense Breakdown") {
                if expenseSummary.isEmpty {
                    Text("No expense data for this period.")
                } else {
                    Chart(expenseSummary) { summary in
                        SectorMark(
                            angle: .value("Amount", summary.totalAmount),
                            innerRadius: .ratio(0.6)
                        )
                        .foregroundStyle(by: .value("Category", summary.categoryName))
                    }
                    .chartLegend(position: .bottom, alignment: .center, spacing: 10)
                    .frame(height: 300)
                }
            }
            
            // MARK: Profitability by Property Chart
            Section("Profitability by Property") {
                let profitableProperties = propertyProfitability.filter { $0.netProfit != 0 }
                
                if profitableProperties.isEmpty {
                    Text("No profit data for this period.")
                } else {
                    Chart(profitableProperties) { summary in
                        BarMark(
                            x: .value("Profit", summary.netProfit),
                            y: .value("Property", summary.propertyName)
                        )
                        .foregroundStyle(summary.netProfit >= 0 ? Color.blue.gradient : Color.orange.gradient)
                    }
                    .frame(height: CGFloat(profitableProperties.count * 40))
                }
            }
        }
        .navigationTitle("Analytics")
        .sheet(isPresented: $showingYearSheet) {
            YearSelectionView(date: $selectedDate)
        }
        .sheet(isPresented: $showingMonthYearSheet) {
            MonthYearSelectionView(date: $selectedDate)
        }
    }

    // MARK: - Data Processing & Filtering
    
    private var dateRangeDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        // ✅ MODIFIED: Removed the 'weekly' case.
        switch filterType {
        case .daily: return formatter.string(from: selectedDate)
        case .monthly:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: selectedDate)
        case .yearly:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: selectedDate)
        case .customRange:
             return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        case .allTime:
            return "All Time"
        }
    }
    
    private var dateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        // ✅ MODIFIED: Removed the 'weekly' case.
        switch filterType {
        case .daily:
            return calendar.startOfDay(for: selectedDate)...selectedDate.endOfDay
        case .monthly:
            let month = calendar.dateInterval(of: .month, for: selectedDate)!
            return month.start...month.end
        case .yearly:
            let year = calendar.dateInterval(of: .year, for: selectedDate)!
            return year.start...year.end
        case .customRange:
            return startDate.startOfDay...endDate.endOfDay
        case .allTime:
            return Date.distantPast...Date.distantFuture
        }
    }
    
    private var chartGroupingParameters: (strideBy: Calendar.Component, unit: Calendar.Component) {
        let duration = dateRange.upperBound.timeIntervalSince(dateRange.lowerBound)
        let oneHundredDays: TimeInterval = 100 * 24 * 60 * 60
        
        // ✅ MODIFIED: Removed the 'weekly' case.
        switch filterType {
        case .daily, .monthly:
            return (.day, .day)
        case .yearly, .allTime:
            return (.month, .month)
        case .customRange:
            return duration < oneHundredDays ? (.day, .day) : (.month, .month)
        }
    }
    
    private var financialSummary: [FinancialPeriodData] {
        let filteredIncomes = manager.incomes.filter { dateRange.contains($0.date) }
        let filteredExpenses = manager.expenses.filter { dateRange.contains($0.date) }
        
        var periodDataDict: [Date: FinancialPeriodData] = [:]
        let calendar = Calendar.current
        let (_, timeUnit) = chartGroupingParameters
        let components: Set<Calendar.Component> = timeUnit == .day ? [.year, .month, .day] : [.year, .month]
        
        for income in filteredIncomes {
            let dateComponents = calendar.dateComponents(components, from: income.date)
            let startOfPeriod = calendar.date(from: dateComponents)!
            periodDataDict[startOfPeriod, default: FinancialPeriodData(date: startOfPeriod)].income += income.amount
        }
        
        for expense in filteredExpenses {
            let dateComponents = calendar.dateComponents(components, from: expense.date)
            let startOfPeriod = calendar.date(from: dateComponents)!
            periodDataDict[startOfPeriod, default: FinancialPeriodData(date: startOfPeriod)].expense += expense.amount
        }
        
        return periodDataDict.values.sorted(by: { $0.date < $1.date })
    }
    
    private var expenseSummary: [CategorySummary] {
        let filteredExpenses = manager.expenses.filter { dateRange.contains($0.date) }
        let groupedByCategory = Dictionary(grouping: filteredExpenses, by: { $0.categoryId })
        return groupedByCategory.map { categoryId, expenses in
            let categoryName = manager.getCategory(byId: categoryId)?.name ?? "Uncategorized"
            let totalAmount = expenses.reduce(0) { $0 + $1.amount }
            return CategorySummary(categoryName: categoryName, totalAmount: totalAmount)
        }.sorted { $0.totalAmount > $1.totalAmount }
    }
    
    private var propertyProfitability: [PropertyProfitability] {
        manager.properties.map { property in
            let totalIncome = manager.incomes.filter { $0.propertyId == property.id && dateRange.contains($0.date) }.reduce(0) { $0 + $1.amount }
            let totalExpense = manager.expenses.filter { $0.propertyId == property.id && dateRange.contains($0.date) }.reduce(0) { $0 + $1.amount }
            return PropertyProfitability(propertyName: property.name, netProfit: totalIncome - totalExpense)
        }.sorted { $0.netProfit > $1.netProfit }
    }
}


// MARK: - Picker Sheet Views
private struct YearSelectionView: View {
    @Binding var date: Date
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedYear: Int
    private let calendar = Calendar.current
    
    init(date: Binding<Date>) {
        self._date = date
        self._selectedYear = State(initialValue: Calendar.current.component(.year, from: date.wrappedValue))
    }

    var body: some View {
        NavigationView {
            VStack {
                Picker("Year", selection: $selectedYear) {
                    ForEach((2010...2035), id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                
                Spacer()
                
                Button("Done") {
                    var components = calendar.dateComponents([.month, .day], from: date)
                    components.year = selectedYear
                    date = calendar.date(from: components) ?? date
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle("Select Year")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

private struct MonthYearSelectionView: View {
    @Binding var date: Date
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedMonth: Int
    @State private var selectedYear: Int
    private let calendar = Calendar.current
    
    init(date: Binding<Date>) {
        self._date = date
        let components = Calendar.current.dateComponents([.month, .year], from: date.wrappedValue)
        self._selectedMonth = State(initialValue: components.month ?? 1)
        self._selectedYear = State(initialValue: components.year ?? 2025)
    }

    var body: some View {
        NavigationView {
            VStack {
                HStack(spacing: 0) {
                    Picker("Month", selection: $selectedMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text(calendar.monthSymbols[month - 1]).tag(month)
                        }
                    }
                    .pickerStyle(.wheel)
                    
                    Picker("Year", selection: $selectedYear) {
                        ForEach((2010...2035), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                .labelsHidden()
                
                Spacer()
                
                Button("Done") {
                    var components = calendar.dateComponents([.day], from: date)
                    components.month = selectedMonth
                    components.year = selectedYear
                    date = calendar.date(from: components) ?? date
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle("Select Month & Year")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
