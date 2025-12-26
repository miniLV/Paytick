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
    
    // MARK: - Private Properties
    private var timer: Timer?
    private let calendar = Calendar.current
    
    // User Input Configuration
    private var monthlySalary: Double = 0
    private var workDaysPerMonth: Int = 22
    private var dailyHours: Double = 8
    private var workSchedule: WorkSchedule?
    
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
        
        if let schedule = workSchedule {
            self.dailyHours = schedule.totalWorkMinutesPerDay / 60.0
        }
        
        calculateBaseValues()
        updateRealTimeValues()
    }
    
    // MARK: - Core Calculations (per Gemini specification)
    private func calculateBaseValues() {
        // Calculate value per minute (Value/Min)
        let dailyIncome = monthlySalary / Double(workDaysPerMonth)
        valuePerMinute = dailyIncome / (dailyHours * 60)
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
        let lunchStartMinutes = getTimeInMinutes(schedule.lunchStartTime)
        let lunchEndMinutes = getTimeInMinutes(schedule.lunchEndTime)
        
        // If work hasn't started yet
        if currentTimeMinutes < startTimeMinutes {
            return 0.0
        }
        
        // Calculate actual worked minutes, excluding lunch
        var workedMinutes = 0.0
        
        if currentTimeMinutes <= endTimeMinutes {
            // Within normal work hours
            workedMinutes = currentTimeMinutes - startTimeMinutes
            
            // Deduct lunch time
            if currentTimeMinutes > lunchEndMinutes {
                workedMinutes -= (lunchEndMinutes - lunchStartMinutes)
            } else if currentTimeMinutes > lunchStartMinutes {
                workedMinutes -= (currentTimeMinutes - lunchStartMinutes)
            }
        } else {
            // Past normal work hours (overtime)
            workedMinutes = endTimeMinutes - startTimeMinutes - (lunchEndMinutes - lunchStartMinutes)
        }
        
        let result = max(0, workedMinutes)
        return result
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
        let lunchStartMinutes = getTimeInMinutes(schedule.lunchStartTime)
        let lunchEndMinutes = getTimeInMinutes(schedule.lunchEndTime)
        
        // If work hasn't started yet, return 0
        if currentTimeMinutes < startTimeMinutes {
            return 0.0
        }
        
        // Calculate worked time (excluding lunch)
        var workedMinutes = currentTimeMinutes - startTimeMinutes
        
        // Deduct lunch duration if lunch time has passed
        if currentTimeMinutes > lunchEndMinutes {
            workedMinutes -= (lunchEndMinutes - lunchStartMinutes)
        } else if currentTimeMinutes >= lunchStartMinutes {
            workedMinutes -= (currentTimeMinutes - lunchStartMinutes)
        }
        
        // Total work duration
        let totalWorkMinutes = schedule.totalWorkMinutesPerDay
        
        // Progress percentage
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
        let lunchStartMinutes = getTimeInMinutes(schedule.lunchStartTime)
        let lunchEndMinutes = getTimeInMinutes(schedule.lunchEndTime)
        
        if currentTimeMinutes < startTimeMinutes {
            currentWorkStatus = .notStarted
            isWorkTime = false
        } else if currentTimeMinutes >= lunchStartMinutes && currentTimeMinutes < lunchEndMinutes {
            currentWorkStatus = .lunch
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
        let lunchStartMinutes = getTimeInMinutes(schedule.lunchStartTime)
        let lunchEndMinutes = getTimeInMinutes(schedule.lunchEndTime)
        
        if currentTimeMinutes > endTimeMinutes {
            // During overtime
            isOvertime = true
            overtimeMinutes = currentTimeMinutes - endTimeMinutes
            
            // Deduct dinner time during overtime if needed
            // Simplified handling: calculate overtime income directly
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
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return Double(hour * 60 + minute)
    }
    
    private func checkIsWorkTime(_ time: Date) -> Bool {
        return isWorkTime
    }
    
    // MARK: - Real-time Updates
    private func startRealTimeCalculation() {
        // High-frequency update (every 100ms) for ticking effect
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateRealTimeValues()
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
    func calculateMonthlyAccumulatedIncome() -> Double {
        guard let schedule = workSchedule else { return 0.0 }
        
        let now = Date()
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        // Calculate completed workdays this month
        let completedWorkDays = calculateCompletedWorkDaysThisMonth(startOfMonth: startOfMonth, currentDate: now)
        
        // Daily income
        let dailyIncome = monthlySalary / Double(workDaysPerMonth)
        
        // Income from completed days
        let completedDaysIncome = Double(completedWorkDays) * dailyIncome
        
        // Today's live income
        let todayIncome = liveTickerValue
        
        return completedDaysIncome + todayIncome
    }
    
    private func calculateCompletedWorkDaysThisMonth(startOfMonth: Date, currentDate: Date) -> Int {
        guard let schedule = workSchedule else { return 0 }
        
        let calendar = Calendar.current
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
        
        return completedDays
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
        return getValueStreamCalculator()?.todayProgress ?? workProgress
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
    
    func getMonthlyAccumulatedIncome() -> Double {
        // Get monthly accumulated income
        return getValueStreamCalculator()?.calculateMonthlyAccumulatedIncome() ?? 0.0
    }
}