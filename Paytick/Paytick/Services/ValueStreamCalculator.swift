import Foundation
import Combine

// MARK: - Value Stream 核心计算器
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
    
    // 用户输入的配置
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
    
    // MARK: - Core Calculations (按照 Gemini 规格)
    private func calculateBaseValues() {
        // 计算每分钟价值 (Value/Min)
        let dailyIncome = monthlySalary / Double(workDaysPerMonth)
        valuePerMinute = dailyIncome / (dailyHours * 60)
    }
    
    private func updateRealTimeValues() {
        let now = Date()
        
        // 更新工作状态
        updateWorkStatus(now)
        
        // 计算今日实际工作时间
        timeElapsedInMinutes = calculateTodayWorkedMinutes(now)
        
        // 今日实时收入 = 今日工作分钟数 * 分钟价值
        liveTickerValue = calculateTodayIncome(now)
        
        // 今日进度计算
        todayProgress = calculateTodayProgress()
        
        // 计算加班时间和收入
        calculateOvertimeStatus(now)
    }
    
    // MARK: - Time Calculations
    private func calculateTodayWorkedMinutes(_ time: Date) -> Double {
        guard let schedule = workSchedule else { return 0.0 }
        
        let weekday = getCurrentWeekday(time)
        // 如果不是工作日，返回 0
        if !schedule.workdays.contains(weekday) {
            return 0.0
        }
        
        let currentTimeMinutes = getTimeInMinutes(time)
        let startTimeMinutes = getTimeInMinutes(schedule.startTime)
        let endTimeMinutes = getTimeInMinutes(schedule.endTime)
        let lunchStartMinutes = getTimeInMinutes(schedule.lunchStartTime)
        let lunchEndMinutes = getTimeInMinutes(schedule.lunchEndTime)
        
        // 如果还未开始工作
        if currentTimeMinutes < startTimeMinutes {
            return 0.0
        }
        
        // 计算实际工作时间，排除午餐
        var workedMinutes = 0.0
        
        if currentTimeMinutes <= endTimeMinutes {
            // 在正常工作时间内
            workedMinutes = currentTimeMinutes - startTimeMinutes
            
            // 减去午餐时间
            if currentTimeMinutes > lunchEndMinutes {
                workedMinutes -= (lunchEndMinutes - lunchStartMinutes)
            } else if currentTimeMinutes > lunchStartMinutes {
                workedMinutes -= (currentTimeMinutes - lunchStartMinutes)
            }
        } else {
            // 已过正常工作时间（在加班）
            workedMinutes = endTimeMinutes - startTimeMinutes - (lunchEndMinutes - lunchStartMinutes)
        }
        
        let result = max(0, workedMinutes)
        return result
    }
    
    private func calculateTodayIncome(_ time: Date) -> Double {
        let todayWorkedMinutes = calculateTodayWorkedMinutes(time)
        
        // 正常工作时间收入
        let normalIncome = todayWorkedMinutes * valuePerMinute
        
        // 如果在加班，加班部分收入可能不同（这里暂时用同样费率）
        // 如果需要可以设置不同的加班费率
        return normalIncome
    }
    
    private func calculateMinutesSinceStartOfMonth() -> Double {
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let elapsed = now.timeIntervalSince(startOfMonth)
        return elapsed / 60.0 // 转换为分钟
    }
    
    private func calculateTodayProgress() -> Double {
        guard let schedule = workSchedule else { return 0.0 }
        
        let now = Date()
        let weekday = getCurrentWeekday(now)
        
        // 如果不是工作日，返回 0
        if !schedule.workdays.contains(weekday) {
            return 0.0
        }
        
        let currentTimeMinutes = getTimeInMinutes(now)
        let startTimeMinutes = getTimeInMinutes(schedule.startTime)
        let endTimeMinutes = getTimeInMinutes(schedule.endTime)
        let lunchStartMinutes = getTimeInMinutes(schedule.lunchStartTime)
        let lunchEndMinutes = getTimeInMinutes(schedule.lunchEndTime)
        
        // 如果还未到工作时间，返回 0
        if currentTimeMinutes < startTimeMinutes {
            return 0.0
        }
        
        // 计算已工作时间（排除午餐时间）
        var workedMinutes = currentTimeMinutes - startTimeMinutes
        
        // 如果已过午餐时间，减去午餐时长
        if currentTimeMinutes > lunchEndMinutes {
            workedMinutes -= (lunchEndMinutes - lunchStartMinutes)
        } else if currentTimeMinutes >= lunchStartMinutes {
            workedMinutes -= (currentTimeMinutes - lunchStartMinutes)
        }
        
        // 总工作时长
        let totalWorkMinutes = schedule.totalWorkMinutesPerDay
        
        // 进度百分比
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
            // 在加班时间
            isOvertime = true
            overtimeMinutes = currentTimeMinutes - endTimeMinutes
            
            // 如果加班期间包含了晚餐时间，可能需要扣除
            // 这里暂时简单处理，直接计算加班收入
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
        // 高频更新 (每 100 毫秒) 产生数字持续跳动效果
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
        
        // 计算本月已完成的工作天数
        let completedWorkDays = calculateCompletedWorkDaysThisMonth(startOfMonth: startOfMonth, currentDate: now)
        
        // 每日收入
        let dailyIncome = monthlySalary / Double(workDaysPerMonth)
        
        // 已完成天数的收入
        let completedDaysIncome = Double(completedWorkDays) * dailyIncome
        
        // 今日实时收入
        let todayIncome = liveTickerValue
        
        return completedDaysIncome + todayIncome
    }
    
    private func calculateCompletedWorkDaysThisMonth(startOfMonth: Date, currentDate: Date) -> Int {
        guard let schedule = workSchedule else { return 0 }
        
        let calendar = Calendar.current
        var completedDays = 0
        var date = startOfMonth
        
        // 遍历从月初到昨天的每一天
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
    
    // 适配 Value Stream 的计算方法
    func getValueStreamIncome() -> Double {
        // 使用集成的 ValueStreamCalculator 或回退到现有逻辑
        let streamValue = getValueStreamCalculator()?.liveTickerValue ?? currentIncome
        return streamValue
    }
    
    func getValueStreamProgress() -> Double {
        // 使用集成的 ValueStreamCalculator 或回退到现有逻辑
        return getValueStreamCalculator()?.todayProgress ?? workProgress
    }
    
    func getValueStreamMinuteRate() -> Double {
        // 使用集成的 ValueStreamCalculator 或回退到现有逻辑
        let minuteRateValue = getValueStreamCalculator()?.valuePerMinute ?? minuteRate
        return minuteRateValue
    }
    
    func getOvertimeIncome() -> Double {
        // 从 ValueStreamCalculator 获取加班收入
        return getValueStreamCalculator()?.overtimeIncome ?? overtimeIncome
    }
    
    func getMonthlyAccumulatedIncome() -> Double {
        // 获取本月累计收入
        return getValueStreamCalculator()?.calculateMonthlyAccumulatedIncome() ?? 0.0
    }
}