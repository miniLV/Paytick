import Foundation

// MARK: - User Profile Data Model
struct UserProfile: Codable, Identifiable {
    let id = UUID()
    var name: String
    var monthlySalary: Double
    var workdaysPerMonth: Int
    var currency: String
    var createdAt: Date
    var updatedAt: Date
    
    init(name: String, monthlySalary: Double, workdaysPerMonth: Int, currency: String = "CNY") {
        self.name = name
        self.monthlySalary = monthlySalary
        self.workdaysPerMonth = workdaysPerMonth
        self.currency = currency
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, monthlySalary, workdaysPerMonth, currency, createdAt, updatedAt
    }
}

// MARK: - Work Schedule Data Model
struct WorkSchedule: Codable, Identifiable {
    let id = UUID()
    var startTime: Date
    var endTime: Date
    var lunchStartTime: Date
    var lunchEndTime: Date
    var workdays: Set<Weekday>
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(startTime: Date, endTime: Date, lunchStartTime: Date, lunchEndTime: Date, workdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]) {
        self.startTime = startTime
        self.endTime = endTime
        self.lunchStartTime = lunchStartTime
        self.lunchEndTime = lunchEndTime
        self.workdays = workdays
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var totalWorkMinutesPerDay: Double {
        // Extract only hour and minute components, ignore date part
        // This fixes the bug where dates from different days cause wrong calculations
        let calendar = Calendar.current
        
        let startMinutes = calendar.component(.hour, from: startTime) * 60 + calendar.component(.minute, from: startTime)
        let endMinutes = calendar.component(.hour, from: endTime) * 60 + calendar.component(.minute, from: endTime)
        
        // Simple calculation: just end time - start time
        var workMinutes = Double(endMinutes - startMinutes)
        
        // Deduct lunch break
        let lunchStartMinutes = calendar.component(.hour, from: lunchStartTime) * 60 + calendar.component(.minute, from: lunchStartTime)
        let lunchEndMinutes = calendar.component(.hour, from: lunchEndTime) * 60 + calendar.component(.minute, from: lunchEndTime)
        let lunchDuration = Double(max(0, lunchEndMinutes - lunchStartMinutes))
        
        // Only deduct if lunch is within work hours - simplified assumption for now
        if lunchDuration > 0 {
            workMinutes -= lunchDuration
        }
        
        return max(0, workMinutes)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, startTime, endTime, lunchStartTime, lunchEndTime, workdays, isActive, createdAt, updatedAt
    }
}

enum Weekday: String, Codable, CaseIterable {
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"
    case sunday = "Sunday"
    
    var calendarWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
    
    var shortName: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }
}

// MARK: - Income Data Model
struct IncomeData: Codable, Identifiable {
    let id = UUID()
    var date: Date
    var totalMinutesWorked: Double
    var calculatedIncome: Double
    var minuteRate: Double
    var overtimeMinutes: Double
    var overtimeRate: Double
    var bonuses: [Bonus]
    var deductions: [Deduction]
    var finalIncome: Double
    var workStatus: WorkStatus
    var createdAt: Date
    var updatedAt: Date
    
    init(date: Date, totalMinutesWorked: Double, minuteRate: Double, overtimeMinutes: Double = 0, overtimeRate: Double = 1.5) {
        self.date = date
        self.totalMinutesWorked = totalMinutesWorked
        self.minuteRate = minuteRate
        self.calculatedIncome = totalMinutesWorked * minuteRate
        self.overtimeMinutes = overtimeMinutes
        self.overtimeRate = overtimeRate
        self.bonuses = []
        self.deductions = []
        self.finalIncome = self.calculatedIncome + (overtimeMinutes * minuteRate * overtimeRate)
        self.workStatus = .working
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    mutating func addBonus(_ bonus: Bonus) {
        bonuses.append(bonus)
        calculateFinalIncome()
    }
    
    mutating func addDeduction(_ deduction: Deduction) {
        deductions.append(deduction)
        calculateFinalIncome()
    }
    
    private mutating func calculateFinalIncome() {
        let totalBonuses = bonuses.reduce(0) { $0 + $1.amount }
        let totalDeductions = deductions.reduce(0) { $0 + $1.amount }
        let overtimeIncome = overtimeMinutes * minuteRate * overtimeRate
        finalIncome = calculatedIncome + overtimeIncome + totalBonuses - totalDeductions
    }
    
    enum CodingKeys: String, CodingKey {
        case id, date, totalMinutesWorked, calculatedIncome, minuteRate, overtimeMinutes, overtimeRate, bonuses, deductions, finalIncome, workStatus, createdAt, updatedAt
    }
}

enum WorkStatus: String, Codable, CaseIterable {
    case notStarted = "Not Started"
    case working = "Working"
    case lunch = "Lunch Break"
    case overtime = "Overtime"
    case finished = "Finished"
    case absent = "Absent"
    case holiday = "Holiday"
}

struct Bonus: Codable, Identifiable {
    let id = UUID()
    var amount: Double
    var reason: String
    var date: Date
    
    enum CodingKeys: String, CodingKey {
        case id, amount, reason, date
    }
}

struct Deduction: Codable, Identifiable {
    let id = UUID()
    var amount: Double
    var reason: String
    var date: Date
    
    enum CodingKeys: String, CodingKey {
        case id, amount, reason, date
    }
}

// MARK: - Reward System Data Models
struct Reward: Codable, Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var targetAmount: Double
    var currentAmount: Double
    var rewardType: RewardType
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    
    init(title: String, description: String, targetAmount: Double, rewardType: RewardType) {
        self.title = title
        self.description = description
        self.targetAmount = targetAmount
        self.currentAmount = 0
        self.rewardType = rewardType
        self.isCompleted = false
        self.completedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(currentAmount / targetAmount, 1.0)
    }
    
    mutating func updateProgress(_ amount: Double) {
        currentAmount = amount
        if currentAmount >= targetAmount && !isCompleted {
            isCompleted = true
            completedAt = Date()
        }
        updatedAt = Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, targetAmount, currentAmount, rewardType, isCompleted, completedAt, createdAt, updatedAt
    }
}

enum RewardType: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case milestone = "Milestone"
    case achievement = "Achievement"
    
    var emoji: String {
        switch self {
        case .daily: return "📅"
        case .weekly: return "📊"
        case .monthly: return "🗓️"
        case .milestone: return "🎯"
        case .achievement: return "🏆"
        }
    }
}

// MARK: - Financial Planning Models
struct Expense: Codable, Identifiable {
    let id = UUID()
    var name: String
    var amount: Double
    var category: ExpenseCategory
    var isRecurring: Bool
    var frequency: RecurrenceFrequency?
    var nextDueDate: Date?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(name: String, amount: Double, category: ExpenseCategory, isRecurring: Bool = false, frequency: RecurrenceFrequency? = nil) {
        self.name = name
        self.amount = amount
        self.category = category
        self.isRecurring = isRecurring
        self.frequency = frequency
        self.nextDueDate = isRecurring ? Self.calculateNextDueDate(from: Date(), frequency: frequency) : nil
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    private static func calculateNextDueDate(from date: Date, frequency: RecurrenceFrequency?) -> Date? {
        guard let freq = frequency else { return nil }
        let calendar = Calendar.current
        
        switch freq {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, amount, category, isRecurring, frequency, nextDueDate, isActive, createdAt, updatedAt
    }
}

enum ExpenseCategory: String, Codable, CaseIterable {
    case housing = "Housing"
    case food = "Food"
    case transportation = "Transportation"
    case utilities = "Utilities"
    case entertainment = "Entertainment"
    case healthcare = "Healthcare"
    case education = "Education"
    case shopping = "Shopping"
    case other = "Other"
    
    var emoji: String {
        switch self {
        case .housing: return "🏠"
        case .food: return "🍽️"
        case .transportation: return "🚗"
        case .utilities: return "⚡"
        case .entertainment: return "🎬"
        case .healthcare: return "🏥"
        case .education: return "📚"
        case .shopping: return "🛍️"
        case .other: return "💼"
        }
    }
}

enum RecurrenceFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
}

struct FinancialHealth: Codable {
    var score: Double
    var savingsRate: Double
    var expenseToIncomeRatio: Double
    var recommendations: [String]
    var lastCalculated: Date
    
    init() {
        self.score = 0
        self.savingsRate = 0
        self.expenseToIncomeRatio = 0
        self.recommendations = []
        self.lastCalculated = Date()
    }
    
    mutating func calculate(monthlyIncome: Double, monthlyExpenses: Double, savings: Double) {
        expenseToIncomeRatio = monthlyIncome > 0 ? monthlyExpenses / monthlyIncome : 0
        savingsRate = monthlyIncome > 0 ? savings / monthlyIncome : 0
        
        // Calculate health score (0-100)
        score = calculateHealthScore()
        
        // Generate recommendations
        recommendations = generateRecommendations()
        lastCalculated = Date()
    }
    
    private func calculateHealthScore() -> Double {
        var score = 100.0
        
        // Deduct points for high expense ratio
        if expenseToIncomeRatio > 0.8 {
            score -= 30
        } else if expenseToIncomeRatio > 0.6 {
            score -= 15
        }
        
        // Deduct points for low savings rate
        if savingsRate < 0.1 {
            score -= 25
        } else if savingsRate < 0.2 {
            score -= 10
        }
        
        return max(0, score)
    }
    
    private func generateRecommendations() -> [String] {
        var recs: [String] = []
        
        if expenseToIncomeRatio > 0.8 {
            recs.append("Consider reducing non-essential expenses, expense ratio is too high")
        }
        
        if savingsRate < 0.1 {
            recs.append("Suggestion: increase savings, target at least 20% of income")
        }
        
        if score < 50 {
            recs.append("Financial health needs improvement. Consider creating a detailed financial plan.")
        }
        
        return recs
    }
}

// MARK: - Date Extension
extension Date {
    /// Creates a Date with specified hour and minute for today
    static func createTime(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? Date()
    }
}