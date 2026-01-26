import Foundation
import Combine

// MARK: - Value Stream Core Calculator
class ValueStreamCalculator: ObservableObject {
    
    // MARK: - Published Properties
    @Published var liveTickerValue: Double = 0.0
    @Published var valuePerMinute: Double = 0.0
    @Published var todayProgress: Double = 0.0
    @Published var timeElapsedInMinutes: Double = 0.0
    @Published var isWorkTime: Bool = false
    @Published var isOvertime: Bool = false
    @Published var currentWorkStatus: WorkStatus = .notStarted
    @Published var overtimeMinutes: Double = 0.0
    @Published var overtimeIncome: Double = 0.0
    @Published var monthlyAccumulatedIncome: Double = 0.0
    
    // MARK: - Private Properties
    private var timer: Timer?
    // Use a calendar with explicit timezone to avoid timezone issues
    private var calendar: Calendar = {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal
    }()
    
    // User Input Configuration
    private var monthlySalary: Double = 0
    private var workDaysPerMonth: Int = 22
    private var workSchedule: WorkSchedule?
    private var dailyIncome: Double = 0.0
    
    // Caching to avoid repeated expensive calculations
    private var cachedCompletedWorkDays: Int = 0
    private var cachedCompletedWorkDaysDate: Date?
    private var cachedTotalWorkDaysInMonth: Int = 0
    private var cachedTotalWorkDaysMonth: Int = 0
    
    init() {
        startRealTimeCalculation()
    }
    
    deinit {
        stopRealTimeCalculation()
    }
    
    // MARK: - Configuration
    func configure(
        monthlySalary: Double,
        workDaysPerMonth: Int,
        workSchedule: WorkSchedule?
    ) {
        self.monthlySalary = monthlySalary
        self.workDaysPerMonth = workDaysPerMonth
        self.workSchedule = workSchedule
        
        // Clear caches when configuration changes
        invalidateCaches()
        
        calculateBaseValues()
        updateRealTimeValues()
    }
    
    /// Invalidate all caches - call when work schedule or salary changes
    private func invalidateCaches() {
        cachedCompletedWorkDays = 0
        cachedCompletedWorkDaysDate = nil
        cachedTotalWorkDaysInMonth = 0
        cachedTotalWorkDaysMonth = 0
    }
    
    // MARK: - Core Calculations (per Gemini specification)
    private func calculateBaseValues() {
        // Calculate daily income based on actual workdays in current month
        // This ensures monthly accumulated income ≈ monthly salary at month end
        dailyIncome = calculateDailyIncomeForCurrentMonth()
        
        // Calculate value per minute based on daily income and actual daily work minutes from schedule
        // Uses workSchedule.totalWorkMinutesPerDay which is (endTime - startTime - lunchDuration)
        // NOT a hardcoded 8 hours!
        let dailyWorkMinutes = workSchedule?.totalWorkMinutesPerDay ?? 480.0 // Fallback to 8 hours only if no schedule
        guard dailyWorkMinutes > 0 else {
            valuePerMinute = 0
            return
        }
        valuePerMinute = dailyIncome / dailyWorkMinutes
    }
    
    /// Calculates daily income by dividing monthly salary by actual workdays in current month
    private func calculateDailyIncomeForCurrentMonth() -> Double {
        let totalWorkDaysThisMonth = calculateTotalWorkDaysInMonth(for: Date())
        guard totalWorkDaysThisMonth > 0 else {
            // Fallback: use workDaysPerMonth setting or default to 22
            let fallbackDays = workDaysPerMonth > 0 ? workDaysPerMonth : 22
            return monthlySalary / Double(fallbackDays)
        }
        return monthlySalary / Double(totalWorkDaysThisMonth)
    }
    
    private func updateRealTimeValues() {
        let now = Date()
        
        // Update work status
        updateWorkStatus(now)
        
        // Calculate actual work time today
        timeElapsedInMinutes = calculateTodayWorkedMinutes(now)
        
        // Today's live income = today's worked minutes * value per minute
        liveTickerValue = calculateTodayIncome(now)
        
        // Today's progress calculation
        todayProgress = calculateTodayProgress()
        
        // Calculate overtime duration and income
        calculateOvertimeStatus(now)
        
        // Update monthly accumulated income
        updateMonthlyAccumulatedIncome(now)
    }
    
    // MARK: - Time Calculations
    private func calculateTodayWorkedMinutes(_ time: Date) -> Double {
        guard let schedule = workSchedule else { return 0.0 }
        
        let weekday = getCurrentWeekday(time)
        // If not a workday, return 0
        if !schedule.workdays.contains(weekday) {
            return 0.0
        }
        
        let currentTimeMinutes = getTimeInMinutes(time)
        let startTimeMinutes = getTimeInMinutes(schedule.startTime)
        let endTimeMinutes = getTimeInMinutes(schedule.endTime)
        
        // If work hasn't started yet
        if currentTimeMinutes < startTimeMinutes {
            return 0.0
        }
        
        // Simple calculation: current time - start time
        // No lunch break deduction - work time is simply (end - start)
        var workedMinutes = 0.0
        
        if currentTimeMinutes <= endTimeMinutes {
            // Within normal work hours
            workedMinutes = currentTimeMinutes - startTimeMinutes
        } else {
            // Past normal work hours - cap at full day
            workedMinutes = endTimeMinutes - startTimeMinutes
        }
        
        return max(0, workedMinutes)
    }
    
    private func calculateTodayIncome(_ time: Date) -> Double {
        let todayWorkedMinutes = calculateTodayWorkedMinutes(time)
        
        // Income from normal work hours
        let normalIncome = todayWorkedMinutes * valuePerMinute
        
        // If overtime, overtime income rate might differ (currently using same rate)
        // Optionally set different overtime rates here
        return normalIncome
    }
    
    private func calculateMinutesSinceStartOfMonth() -> Double {
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let elapsed = now.timeIntervalSince(startOfMonth)
        return elapsed / 60.0 // Convert to minutes
    }
    
    private func calculateTodayProgress() -> Double {
        guard let schedule = workSchedule else { return 0.0 }
        
        let now = Date()
        let weekday = getCurrentWeekday(now)
        
        // If not a workday, return 0
        if !schedule.workdays.contains(weekday) {
            return 0.0
        }
        
        let currentTimeMinutes = getTimeInMinutes(now)
        let startTimeMinutes = getTimeInMinutes(schedule.startTime)
        let endTimeMinutes = getTimeInMinutes(schedule.endTime)
        
        // If work hasn't started yet, return 0
        if currentTimeMinutes < startTimeMinutes {
            return 0.0
        }
        
        // Simple calculation: current time - start time
        // No lunch break deduction
        var workedMinutes = currentTimeMinutes - startTimeMinutes
        
        // Cap at end of work day
        if currentTimeMinutes > endTimeMinutes {
            workedMinutes = endTimeMinutes - startTimeMinutes
        }
        
        // Total work duration (end - start)
        let totalWorkMinutes = schedule.totalWorkMinutesPerDay
        
        // Progress percentage
        guard totalWorkMinutes > 0 else { return 0.0 }
        let progress = max(0, workedMinutes) / totalWorkMinutes
        return min(progress, 1.0)
    }
    
    // MARK: - Work Status Detection
    private func updateWorkStatus(_ time: Date) {
        guard let schedule = workSchedule else {
            currentWorkStatus = .notStarted
            isWorkTime = false
            return
        }
        
        let weekday = getCurrentWeekday(time)
        let isWorkday = schedule.workdays.contains(weekday)
        
        if !isWorkday {
            currentWorkStatus = .holiday
            isWorkTime = false
            return
        }
        
        let currentTimeMinutes = getTimeInMinutes(time)
        let startTimeMinutes = getTimeInMinutes(schedule.startTime)
        let endTimeMinutes = getTimeInMinutes(schedule.endTime)
        
        // Simple work status: before start / working / overtime
        // No lunch break status
        if currentTimeMinutes < startTimeMinutes {
            currentWorkStatus = .notStarted
            isWorkTime = false
        } else if currentTimeMinutes >= startTimeMinutes && currentTimeMinutes < endTimeMinutes {
            currentWorkStatus = .working
            isWorkTime = true
        } else if currentTimeMinutes >= endTimeMinutes {
            currentWorkStatus = .overtime
            isWorkTime = true
        } else {
            currentWorkStatus = .finished
            isWorkTime = false
        }
    }
    
    private func calculateOvertimeStatus(_ time: Date) {
        guard let schedule = workSchedule else {
            isOvertime = false
            overtimeMinutes = 0.0
            overtimeIncome = 0.0
            return
        }
        
        let weekday = getCurrentWeekday(time)
        if !schedule.workdays.contains(weekday) {
            isOvertime = false
            overtimeMinutes = 0.0
            overtimeIncome = 0.0
            return
        }
        
        let currentTimeMinutes = getTimeInMinutes(time)
        let endTimeMinutes = getTimeInMinutes(schedule.endTime)
        
        if currentTimeMinutes > endTimeMinutes {
            // During overtime
            isOvertime = true
            overtimeMinutes = currentTimeMinutes - endTimeMinutes
            overtimeIncome = overtimeMinutes * valuePerMinute
        } else {
            isOvertime = false
            overtimeMinutes = 0.0
            overtimeIncome = 0.0
        }
    }
    
    // MARK: - Helper Methods
    private func getCurrentWeekday(_ date: Date) -> Weekday {
        let weekday = calendar.component(.weekday, from: date)
        switch weekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .monday
        }
    }
    
    private func getTimeInMinutes(_ date: Date) -> Double {
        // Use calendar.component() which is safer than dateComponents(in:from:)
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return Double(hour * 60 + minute)
    }
    
    private func checkIsWorkTime(_ time: Date) -> Bool {
        return isWorkTime
    }
    
    // MARK: - Real-time Updates
    private func startRealTimeCalculation() {
        // Update every 1 second - balances UI responsiveness with memory efficiency
        // Previous 100ms (0.1s) caused excessive memory growth from:
        // - Frequent @Published updates triggering Combine pipelines
        // - Repeated Date object allocations
        // - Monthly calculation loops running 10x per second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            autoreleasepool {
                self?.updateRealTimeValues()
            }
        }
    }
    
    private func stopRealTimeCalculation() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Utility Methods
    func getFormattedIncome() -> String {
        return String(format: "%.2f", liveTickerValue)
    }
    
    func getFormattedValuePerMinute() -> String {
        return String(format: "%.2f", valuePerMinute)
    }
    
    func getTodayProgressPercentage() -> Int {
        return Int(todayProgress * 100)
    }
    
    // MARK: - Monthly Income Calculation
    private func updateMonthlyAccumulatedIncome(_ now: Date) {
        guard workSchedule != nil else {
            monthlyAccumulatedIncome = 0.0
            return
        }
        
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        // Count completed workdays (from month start to yesterday)
        let completedWorkDays = calculateCompletedWorkDaysThisMonth(startOfMonth: startOfMonth, currentDate: now)
        
        // Accumulate: completed days at full daily rate + today's partial income
        monthlyAccumulatedIncome = Double(completedWorkDays) * dailyIncome + liveTickerValue
    }
    
    /// Legacy support method, now just returns the published property
    func calculateMonthlyAccumulatedIncome() -> Double {
        return monthlyAccumulatedIncome
    }
    
    private func calculateCompletedWorkDaysThisMonth(startOfMonth: Date, currentDate: Date) -> Int {
        guard let schedule = workSchedule else { return 0 }
        
        // Cache check: only recalculate if the date has changed
        // This prevents expensive loop from running every second
        if let cachedDate = cachedCompletedWorkDaysDate,
           calendar.isDate(cachedDate, inSameDayAs: currentDate) {
            return cachedCompletedWorkDays
        }
        
        // Use the instance calendar (which has proper timezone set)
        var completedDays = 0
        var date = startOfMonth
        
        // Iterate through every day from start of month to yesterday
        let yesterday = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        
        while date <= yesterday {
            let weekday = getCurrentWeekday(date)
            if schedule.workdays.contains(weekday) {
                completedDays += 1
            }
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        
        // Update cache
        cachedCompletedWorkDays = completedDays
        cachedCompletedWorkDaysDate = currentDate
        
        return completedDays
    }
    
    private func calculateTotalWorkDaysInMonth(for date: Date) -> Int {
        guard let schedule = workSchedule else { return 0 }
        
        let currentMonth = calendar.component(.month, from: date)
        
        // Cache check: only recalculate if month changed
        if cachedTotalWorkDaysMonth == currentMonth && cachedTotalWorkDaysInMonth > 0 {
            return cachedTotalWorkDaysInMonth
        }
        
        let startOfMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
        let range = calendar.range(of: .day, in: .month, for: date)!
        let daysInMonth = range.count
        
        var workDays = 0
        for day in 0..<daysInMonth {
            if let dateToCheck = calendar.date(byAdding: .day, value: day, to: startOfMonth) {
                let weekday = getCurrentWeekday(dateToCheck)
                if schedule.workdays.contains(weekday) {
                    workDays += 1
                }
            }
        }
        
        // Update cache
        cachedTotalWorkDaysInMonth = workDays
        cachedTotalWorkDaysMonth = currentMonth
        
        return workDays
    }
    
    // MARK: - Goal Progress (Future Enhancement)
    func calculateGoalProgress(goalAmount: Double) -> Double {
        guard goalAmount > 0 else { return 0 }
        return min(liveTickerValue / goalAmount, 1.0)
    }
}

// MARK: - Enhanced Income ViewModel Integration
extension EnhancedIncomeViewModel {
    
    // Adapter methods for Value Stream calculations
    func getValueStreamIncome() -> Double {
        // Use integrated ValueStreamCalculator or fallback to existing logic
        let streamValue = getValueStreamCalculator()?.liveTickerValue ?? currentIncome
        return streamValue
    }
    
    func getValueStreamProgress() -> Double {
        // Use integrated ValueStreamCalculator or fallback to existing logic
        return getValueStreamCalculator()?.todayProgress ?? dailyGoalProgress
    }
    
    func getValueStreamMinuteRate() -> Double {
        // Use integrated ValueStreamCalculator or fallback to existing logic
        let minuteRateValue = getValueStreamCalculator()?.valuePerMinute ?? minuteRate
        return minuteRateValue
    }
    
    func getOvertimeIncome() -> Double {
        // Get overtime income from ValueStreamCalculator
        return getValueStreamCalculator()?.overtimeIncome ?? overtimeIncome
    }
}