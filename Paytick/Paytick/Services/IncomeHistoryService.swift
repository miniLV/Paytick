//
//  IncomeHistoryService.swift
//  Paytick
//
//  Basic income history tracking and statistics
//

import Foundation
import Combine

// MARK: - Daily Income Record
struct DailyIncomeRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let income: Double
    let workedMinutes: Double
    let isWorkday: Bool
    
    init(date: Date, income: Double, workedMinutes: Double, isWorkday: Bool) {
        self.id = UUID()
        self.date = date
        self.income = income
        self.workedMinutes = workedMinutes
        self.isWorkday = isWorkday
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Income Statistics
struct IncomeStatistics {
    var todayIncome: Double = 0
    var weekIncome: Double = 0
    var monthIncome: Double = 0
    
    var weekAverage: Double = 0
    var monthAverage: Double = 0
    
    var weekWorkedDays: Int = 0
    var monthWorkedDays: Int = 0
    
    var weekTotalMinutes: Double = 0
    var monthTotalMinutes: Double = 0
    
    // Trends
    var weekTrend: Trend = .stable
    var monthTrend: Trend = .stable
    
    enum Trend {
        case up
        case down
        case stable
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "arrow.right"
            }
        }
        
        var color: String {
            switch self {
            case .up: return "green"
            case .down: return "red"
            case .stable: return "yellow"
            }
        }
    }
}

// MARK: - Income History Service
class IncomeHistoryService: ObservableObject {
    static let shared = IncomeHistoryService()
    
    @Published var records: [DailyIncomeRecord] = []
    @Published var statistics: IncomeStatistics = IncomeStatistics()
    @Published var weeklyData: [DailyIncomeRecord] = []
    
    private let maxRecordsToKeep = 90 // Keep 3 months of data
    private let storageKey = "incomeHistoryRecords"
    
    private init() {
        loadRecords()
        calculateStatistics()
    }
    
    // MARK: - Record Management
    
    /// Save today's income at end of workday
    func recordDailyIncome(income: Double, workedMinutes: Double, isWorkday: Bool) {
        let today = Calendar.current.startOfDay(for: Date())
        
        // Check if we already have a record for today
        if let existingIndex = records.firstIndex(where: { 
            Calendar.current.isDate($0.date, inSameDayAs: today) 
        }) {
            // Update existing record
            records[existingIndex] = DailyIncomeRecord(
                date: today,
                income: income,
                workedMinutes: workedMinutes,
                isWorkday: isWorkday
            )
        } else {
            // Add new record
            let record = DailyIncomeRecord(
                date: today,
                income: income,
                workedMinutes: workedMinutes,
                isWorkday: isWorkday
            )
            records.append(record)
        }
        
        // Trim old records
        trimOldRecords()
        
        // Save and recalculate
        saveRecords()
        calculateStatistics()
    }
    
    /// Get records for the last N days
    func getRecords(lastDays: Int) -> [DailyIncomeRecord] {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -lastDays, to: Date()) ?? Date()
        
        return records.filter { $0.date >= cutoffDate }
            .sorted { $0.date < $1.date }
    }
    
    /// Get weekly data (last 7 days)
    func getWeeklyData() -> [DailyIncomeRecord] {
        return getRecords(lastDays: 7)
    }
    
    /// Get monthly data (last 30 days)
    func getMonthlyData() -> [DailyIncomeRecord] {
        return getRecords(lastDays: 30)
    }
    
    // MARK: - Statistics Calculation
    
    func calculateStatistics() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Get date boundaries
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        let twoMonthsAgo = calendar.date(byAdding: .day, value: -60, to: today) ?? today
        
        // Today's income
        statistics.todayIncome = records.first { 
            calendar.isDate($0.date, inSameDayAs: today) 
        }?.income ?? 0
        
        // Week data
        let weekRecords = records.filter { $0.date >= weekAgo && $0.date <= today && $0.isWorkday }
        statistics.weekIncome = weekRecords.reduce(0) { $0 + $1.income }
        statistics.weekWorkedDays = weekRecords.count
        statistics.weekTotalMinutes = weekRecords.reduce(0) { $0 + $1.workedMinutes }
        statistics.weekAverage = statistics.weekWorkedDays > 0 
            ? statistics.weekIncome / Double(statistics.weekWorkedDays) 
            : 0
        
        // Month data
        let monthRecords = records.filter { $0.date >= monthAgo && $0.date <= today && $0.isWorkday }
        statistics.monthIncome = monthRecords.reduce(0) { $0 + $1.income }
        statistics.monthWorkedDays = monthRecords.count
        statistics.monthTotalMinutes = monthRecords.reduce(0) { $0 + $1.workedMinutes }
        statistics.monthAverage = statistics.monthWorkedDays > 0 
            ? statistics.monthIncome / Double(statistics.monthWorkedDays) 
            : 0
        
        // Calculate trends
        let previousWeekRecords = records.filter { 
            $0.date >= twoWeeksAgo && $0.date < weekAgo && $0.isWorkday 
        }
        let previousWeekIncome = previousWeekRecords.reduce(0) { $0 + $1.income }
        
        if previousWeekIncome > 0 {
            let weekChange = (statistics.weekIncome - previousWeekIncome) / previousWeekIncome
            if weekChange > 0.05 {
                statistics.weekTrend = .up
            } else if weekChange < -0.05 {
                statistics.weekTrend = .down
            } else {
                statistics.weekTrend = .stable
            }
        }
        
        let previousMonthRecords = records.filter { 
            $0.date >= twoMonthsAgo && $0.date < monthAgo && $0.isWorkday 
        }
        let previousMonthIncome = previousMonthRecords.reduce(0) { $0 + $1.income }
        
        if previousMonthIncome > 0 {
            let monthChange = (statistics.monthIncome - previousMonthIncome) / previousMonthIncome
            if monthChange > 0.05 {
                statistics.monthTrend = .up
            } else if monthChange < -0.05 {
                statistics.monthTrend = .down
            } else {
                statistics.monthTrend = .stable
            }
        }
        
        // Update weekly data for chart
        weeklyData = getWeeklyData()
    }
    
    // MARK: - Persistence
    
    private func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                records = try JSONDecoder().decode([DailyIncomeRecord].self, from: data)
            } catch {
                records = []
            }
        }
    }
    
    private func saveRecords() {
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
        }
    }
    
    private func trimOldRecords() {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -maxRecordsToKeep, to: Date()) ?? Date()
        records = records.filter { $0.date >= cutoffDate }
    }
    
    // MARK: - Utility
    
    func clearAllHistory() {
        records = []
        saveRecords()
        calculateStatistics()
    }
}

