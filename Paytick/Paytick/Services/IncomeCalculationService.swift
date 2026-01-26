import Foundation
import Combine

// MARK: - Income Calculation Protocol
protocol IncomeCalculationServiceProtocol {
    func calculateMinuteRate(userProfile: UserProfile, workSchedule: WorkSchedule) -> Double
    func calculateDailyIncome(currentTime: Date, userProfile: UserProfile, workSchedule: WorkSchedule) -> IncomeData
    func calculateWeeklyIncome(userProfile: UserProfile, workSchedule: WorkSchedule) -> Double
    func calculateMonthlyProjection(userProfile: UserProfile, workSchedule: WorkSchedule) -> Double
    func calculateOvertimeIncome(overtimeMinutes: Double, minuteRate: Double, overtimeRate: Double) -> Double
    func isWorkingTime(currentTime: Date, workSchedule: WorkSchedule) -> WorkStatus
    func getWorkProgress(currentTime: Date, workSchedule: WorkSchedule) -> Double
    func calculateTimeWorkedToday(currentTime: Date, workSchedule: WorkSchedule) -> Double
}

// MARK: - Income Calculation Service Implementation
class IncomeCalculationService: IncomeCalculationServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentIncome: Double = 0
    @Published var workStatus: WorkStatus = .notStarted
    @Published var workProgress: Double = 0
    @Published var minuteRate: Double = 0
    @Published var todayWorkedMinutes: Double = 0
    
    // MARK: - Private Properties
    // Use a calendar with explicit timezone to avoid timezone issues
    private var calendar: Calendar = {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal
    }()
    private let repositoryManager = RepositoryManager.shared
    private var currentUserProfile: UserProfile?
    private var currentWorkSchedule: WorkSchedule?
    private var timer: Timer?
    
    // MARK: - Initialization
    init() {
        loadUserData()
        startRealTimeCalculation()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Public Methods
    func calculateMinuteRate(userProfile: UserProfile, workSchedule: WorkSchedule) -> Double {
        let workMinutesPerDay = workSchedule.totalWorkMinutesPerDay
        let workDaysInMonth = Double(userProfile.workdaysPerMonth)
        let totalWorkMinutesPerMonth = workMinutesPerDay * workDaysInMonth
        
        guard totalWorkMinutesPerMonth > 0 else { return 0 }
        
        let rate = userProfile.monthlySalary / totalWorkMinutesPerMonth
        DispatchQueue.main.async {
            self.minuteRate = rate
        }
        return rate
    }
    
    func calculateDailyIncome(currentTime: Date, userProfile: UserProfile, workSchedule: WorkSchedule) -> IncomeData {
        let minuteRate = calculateMinuteRate(userProfile: userProfile, workSchedule: workSchedule)
        let workedMinutes = calculateTimeWorkedToday(currentTime: currentTime, workSchedule: workSchedule)
        let status = isWorkingTime(currentTime: currentTime, workSchedule: workSchedule)
        
        var incomeData = IncomeData(
            date: currentTime,
            totalMinutesWorked: workedMinutes,
            minuteRate: minuteRate
        )
        
        incomeData.workStatus = status
        
        // Calculate overtime if applicable
        let regularWorkMinutes = workSchedule.totalWorkMinutesPerDay
        if workedMinutes > regularWorkMinutes {
            let overtimeMinutes = workedMinutes - regularWorkMinutes
            incomeData.overtimeMinutes = overtimeMinutes
            let overtimeIncome = calculateOvertimeIncome(overtimeMinutes: overtimeMinutes, minuteRate: minuteRate, overtimeRate: 1.5)
            incomeData.finalIncome = incomeData.calculatedIncome + overtimeIncome
        }
        
        return incomeData
    }
    
    func calculateWeeklyIncome(userProfile: UserProfile, workSchedule: WorkSchedule) -> Double {
        let minuteRate = calculateMinuteRate(userProfile: userProfile, workSchedule: workSchedule)
        let workMinutesPerDay = workSchedule.totalWorkMinutesPerDay
        let workDaysInWeek = Double(workSchedule.workdays.count)
        
        return minuteRate * workMinutesPerDay * workDaysInWeek
    }
    
    func calculateMonthlyProjection(userProfile: UserProfile, workSchedule: WorkSchedule) -> Double {
        return userProfile.monthlySalary
    }
    
    func calculateOvertimeIncome(overtimeMinutes: Double, minuteRate: Double, overtimeRate: Double) -> Double {
        return overtimeMinutes * minuteRate * overtimeRate
    }
    
    func isWorkingTime(currentTime: Date, workSchedule: WorkSchedule) -> WorkStatus {
        let weekday = getWeekdayFromDate(currentTime)
        
        // Check if today is a work day
        guard workSchedule.workdays.contains(weekday) else {
            return .holiday
        }
        
        let todayStart = getTodayTime(from: workSchedule.startTime, for: currentTime)
        let todayEnd = getTodayTime(from: workSchedule.endTime, for: currentTime)
        
        if currentTime < todayStart {
            return .notStarted
        } else if currentTime >= todayStart && currentTime < todayEnd {
            return .working
        } else if currentTime >= todayEnd {
            // Check if it's overtime (within reasonable hours)
            let maxOvertimeHours = 4 // Max 4 hours of overtime
            let maxOvertimeEnd = calendar.date(byAdding: .hour, value: maxOvertimeHours, to: todayEnd) ?? todayEnd
            if currentTime < maxOvertimeEnd {
                return .overtime
            }
            return .finished
        }
        
        return .notStarted
    }
    
    func getWorkProgress(currentTime: Date, workSchedule: WorkSchedule) -> Double {
        let status = isWorkingTime(currentTime: currentTime, workSchedule: workSchedule)
        
        // Calculate progress based on actual work time
        let todayStart = getTodayTime(from: workSchedule.startTime, for: currentTime)
        let todayEnd = getTodayTime(from: workSchedule.endTime, for: currentTime)
        
        // Calculate total expected work time (simple: end - start)
        let totalExpectedWorkTime = todayEnd.timeIntervalSince(todayStart)
        
        // Calculate current work time
        var actualWorkTime: TimeInterval = 0
        
        if currentTime <= todayStart {
            // Before work starts
            actualWorkTime = 0
        } else if currentTime < todayEnd {
            // During work time
            actualWorkTime = currentTime.timeIntervalSince(todayStart)
        } else {
            // After work ends (including overtime)
            actualWorkTime = totalExpectedWorkTime
            
            // Add overtime if applicable
            if status == .overtime {
                let overtimeMinutes = currentTime.timeIntervalSince(todayEnd)
                actualWorkTime += overtimeMinutes
            }
        }
        
        // Calculate progress (work time completed / total expected work time)
        let progress: Double
        if status == .finished && currentTime >= todayEnd {
            progress = 1.0
        } else if totalExpectedWorkTime > 0 {
            progress = min(max(actualWorkTime / totalExpectedWorkTime, 0.0), 1.0)
        } else {
            progress = 0.0
        }
        
        DispatchQueue.main.async {
            self.workProgress = progress
        }
        
        return progress
    }
    
    func calculateTimeWorkedToday(currentTime: Date, workSchedule: WorkSchedule) -> Double {
        let weekday = getWeekdayFromDate(currentTime)
        
        // Check if today is a work day
        guard workSchedule.workdays.contains(weekday) else {
            return 0
        }
        
        let todayStart = getTodayTime(from: workSchedule.startTime, for: currentTime)
        let todayEnd = getTodayTime(from: workSchedule.endTime, for: currentTime)
        
        var workedMinutes = 0.0
        
        // Cap effective time at end of workday - NO automatic overtime!
        // Income should stop accumulating after work hours ("Take Profit")
        let effectiveCurrentTime = min(currentTime, todayEnd)
        
        // Simple calculation: current time - start time
        // No lunch break deduction - work time is simply (end - start)
        if effectiveCurrentTime > todayStart {
            workedMinutes = effectiveCurrentTime.timeIntervalSince(todayStart) / 60
        }
        
        workedMinutes = max(0, workedMinutes)
        
        DispatchQueue.main.async {
            self.todayWorkedMinutes = workedMinutes
        }
        
        return workedMinutes
    }
    
    // MARK: - Real-time Calculation
    func startRealTimeCalculation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            autoreleasepool {
                self?.updateRealTimeData()
            }
        }
        
        // Initial calculation
        updateRealTimeData()
    }
    
    func stopRealTimeCalculation() {
        timer?.invalidate()
    }
    
    public func updateRealTimeData() {
        guard let userProfile = currentUserProfile,
              let workSchedule = currentWorkSchedule else {
            return
        }
        
        let now = Date()
        let weekday = getWeekdayFromDate(now)
        let isWorkday = workSchedule.workdays.contains(weekday)
        let incomeData = calculateDailyIncome(currentTime: now, userProfile: userProfile, workSchedule: workSchedule)
        
        DispatchQueue.main.async {
            self.currentIncome = incomeData.finalIncome
            self.workStatus = incomeData.workStatus
            self.workProgress = self.getWorkProgress(currentTime: now, workSchedule: workSchedule)
        }
        
        // Save today's income data
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = dateFormatter.string(from: now)
        
        do {
            try repositoryManager.incomeDataRepository.save(incomeData, key: todayKey)
        } catch {
        }
    }
    
    // MARK: - User Data Management
    func updateUserProfile(_ userProfile: UserProfile) {
        currentUserProfile = userProfile
        
        // Save to repository
        do {
            try repositoryManager.userProfileRepository.save(userProfile, key: "current")
        } catch {
        }
        
        // Recalculate minute rate
        if let workSchedule = currentWorkSchedule {
            _ = calculateMinuteRate(userProfile: userProfile, workSchedule: workSchedule)
        }
        
        updateRealTimeData()
    }
    
    func updateWorkSchedule(_ workSchedule: WorkSchedule) {
        currentWorkSchedule = workSchedule
        
        // Save to repository
        do {
            try repositoryManager.workScheduleRepository.save(workSchedule, key: "current")
        } catch {
        }
        
        // Recalculate minute rate
        if let userProfile = currentUserProfile {
            _ = calculateMinuteRate(userProfile: userProfile, workSchedule: workSchedule)
        }
        
        updateRealTimeData()
    }
    
    private func loadUserData() {
        do {
            currentUserProfile = try repositoryManager.userProfileRepository.load(key: "current")
            currentWorkSchedule = try repositoryManager.workScheduleRepository.load(key: "current")
        } catch {
        }
    }
    
    // MARK: - Helper Methods
    private func getWeekdayFromDate(_ date: Date) -> Weekday {
        let weekday = calendar.component(.weekday, from: date)
        return Weekday.allCases.first { $0.calendarWeekday == weekday } ?? .monday
    }
    
    private func getTodayTime(from time: Date, for currentDate: Date) -> Date {
        // Extract hour/minute using calendar.component() which is safer than dateComponents(in:from:)
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        
        // Get today's date components
        let year = calendar.component(.year, from: currentDate)
        let month = calendar.component(.month, from: currentDate)
        let day = calendar.component(.day, from: currentDate)
        
        var finalComponents = DateComponents()
        finalComponents.year = year
        finalComponents.month = month
        finalComponents.day = day
        finalComponents.hour = hour
        finalComponents.minute = minute
        finalComponents.second = 0
        
        return calendar.date(from: finalComponents) ?? currentDate
    }
}

// MARK: - Income Statistics Service
class IncomeStatisticsService: ObservableObject {
    
    @Published var weeklyStats: WeeklyStats = WeeklyStats()
    @Published var monthlyStats: MonthlyStats = MonthlyStats()
    
    private let repositoryManager = RepositoryManager.shared
    private let calendar = Calendar.current
    
    func calculateWeeklyStats() {
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        var totalIncome = 0.0
        var totalMinutes = 0.0
        var workDays = 0
        
        for i in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                let dateKey = DateFormatter.dateKey.string(from: day)
                if let incomeData = try? repositoryManager.incomeDataRepository.load(key: dateKey) {
                    totalIncome += incomeData.finalIncome
                    totalMinutes += incomeData.totalMinutesWorked
                    workDays += 1
                }
            }
        }
        
        DispatchQueue.main.async {
            self.weeklyStats = WeeklyStats(
                totalIncome: totalIncome,
                totalMinutes: totalMinutes,
                workDays: workDays,
                averageDailyIncome: workDays > 0 ? totalIncome / Double(workDays) : 0
            )
        }
    }
    
    func calculateMonthlyStats() {
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        
        var totalIncome = 0.0
        var totalMinutes = 0.0
        var workDays = 0
        
        for i in 0..<daysInMonth {
            if let day = calendar.date(byAdding: .day, value: i, to: startOfMonth) {
                let dateKey = DateFormatter.dateKey.string(from: day)
                if let incomeData = try? repositoryManager.incomeDataRepository.load(key: dateKey) {
                    totalIncome += incomeData.finalIncome
                    totalMinutes += incomeData.totalMinutesWorked
                    workDays += 1
                }
            }
        }
        
        DispatchQueue.main.async {
            self.monthlyStats = MonthlyStats(
                totalIncome: totalIncome,
                totalMinutes: totalMinutes,
                workDays: workDays,
                averageDailyIncome: workDays > 0 ? totalIncome / Double(workDays) : 0,
                projectedMonthlyIncome: workDays > 0 ? (totalIncome / Double(workDays)) * 22 : 0 // Assume 22 work days per month
            )
        }
    }
}

// MARK: - Statistics Models
struct WeeklyStats {
    var totalIncome: Double = 0
    var totalMinutes: Double = 0
    var workDays: Int = 0
    var averageDailyIncome: Double = 0
}

struct MonthlyStats {
    var totalIncome: Double = 0
    var totalMinutes: Double = 0
    var workDays: Int = 0
    var averageDailyIncome: Double = 0
    var projectedMonthlyIncome: Double = 0
}

// MARK: - Extensions
extension DateFormatter {
    static let dateKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
