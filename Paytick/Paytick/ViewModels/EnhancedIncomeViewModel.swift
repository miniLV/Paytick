import Foundation
import Combine
import SwiftUI

// MARK: - Enhanced Income View Model
class EnhancedIncomeViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var userProfile: UserProfile?
    @Published var workSchedule: WorkSchedule?
    @Published var currentIncome: Double = 0
    @Published var workStatus: WorkStatus = .notStarted
    @Published var workProgress: Double = 0
    @Published var isConfigured: Bool = false
    @Published var isLoading: Bool = false
    
    // Statistics
    @Published var weeklyStats: WeeklyStats = WeeklyStats()
    @Published var monthlyStats: MonthlyStats = MonthlyStats()
    
    // Performance metrics
    @Published var minuteRate: Double = 0
    @Published var todayWorkedMinutes: Double = 0
    @Published var estimatedEndTime: Date?
    @Published var overtimeMinutes: Double = 0
    @Published var overtimeIncome: Double = 0
    @Published var isOvertime: Bool = false
    
    // Overtime loss calculation (working for free = money lost)
    var overtimeLoss: Double {
        return overtimeMinutes * minuteRate
    }
    
    var formattedOvertimeDuration: String {
        guard overtimeMinutes > 0 else { return "0m" }
        let hours = Int(overtimeMinutes / 60)
        let minutes = Int(overtimeMinutes.truncatingRemainder(dividingBy: 60))
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    // Session tracking
    @Published var sessionStartTime: Date?
    @Published var sessionDuration: TimeInterval = 0
    
    // MARK: - Private Properties
    private let incomeCalculationService: IncomeCalculationService
    private let statisticsService: IncomeStatisticsService
    private let notificationService: NotificationService
    private let smartScheduler: SmartNotificationScheduler
    private let timerManager: TimerManager
    private let repositoryManager = RepositoryManager.shared
    
    // Value Stream Calculator for real-time overtime detection
    private var valueStreamCalculator: ValueStreamCalculator?
    
    private var cancellables = Set<AnyCancellable>()
    
    // Track previous values to detect changes
    private var lastKnownReminderMinutes: Int = 15
    
    // MARK: - Compatibility with original ViewModel
    private weak var originalViewModel: IncomeViewModel?
    
    // MARK: - Initialization
    init() {
        self.incomeCalculationService = IncomeCalculationService()
        self.statisticsService = IncomeStatisticsService()
        self.notificationService = NotificationService.shared
        self.smartScheduler = SmartNotificationScheduler(
            notificationService: notificationService,
            incomeCalculationService: incomeCalculationService
        )
        
        // Initialize timer manager with placeholder callback, will be set later
        self.timerManager = TimerManager.createRealTimeTimer { }
        
        // Initialize Value Stream Calculator
        self.valueStreamCalculator = ValueStreamCalculator()
        
        // Now set the proper callback
        self.timerManager.setCallback { [weak self] in
            self?.updateRealTimeData()
        }
        
        // Observe notification preferences changes to trigger rescheduling when settings change
        notificationService.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleNotificationPreferencesChanged()
            }
            .store(in: &cancellables)
            
        setupBindings()
        loadUserConfiguration()
        startRealTimeUpdates()
        setupValueStreamBindings()
    }
    
    // Compatibility initializer for legacy IncomeViewModel
    convenience init(originalViewModel: IncomeViewModel) {
        self.init()
        self.originalViewModel = originalViewModel
        syncFromOriginalViewModel()
        setupOriginalViewModelBinding()
    }
    
    deinit {
        timerManager.stop()
    }
    
    // MARK: - Public Methods
    func updateUserProfile(_ profile: UserProfile) {
        userProfile = profile
        incomeCalculationService.updateUserProfile(profile)
        saveUserProfile()
        updateConfiguration()
    }
    
    func updateWorkSchedule(_ schedule: WorkSchedule) {
        // Check if schedule actually changed
        let scheduleChanged = workSchedule == nil || 
            !Calendar.current.isDate(workSchedule!.startTime, equalTo: schedule.startTime, toGranularity: .minute) ||
            !Calendar.current.isDate(workSchedule!.endTime, equalTo: schedule.endTime, toGranularity: .minute) ||
            workSchedule!.workdays != schedule.workdays
        
        workSchedule = schedule
        incomeCalculationService.updateWorkSchedule(schedule)
        saveWorkSchedule()
        updateConfiguration()
        
        // Only reschedule and notify if schedule actually changed
        if scheduleChanged {
            // Reset notification flags to allow new notifications
            notificationService.resetNotificationFlags()
            
            scheduleWorkNotifications()
            
            // Send immediate confirmation notification
            notificationService.sendScheduleUpdateNotification(
                endTime: schedule.endTime,
                reminderMinutes: notificationService.preferences.workEndReminderMinutes
            )
        }
    }
    
    func refreshStatistics() {
        statisticsService.calculateWeeklyStats()
        statisticsService.calculateMonthlyStats()
    }
    
    func getCurrentIncomeData() -> IncomeData? {
        guard let profile = userProfile, let schedule = workSchedule else { return nil }
        return incomeCalculationService.calculateDailyIncome(
            currentTime: Date(),
            userProfile: profile,
            workSchedule: schedule
        )
    }
    
    func getEstimatedDailyIncome() -> Double {
        guard let profile = userProfile, let schedule = workSchedule else { return 0 }
        let dailyMinutes = schedule.totalWorkMinutesPerDay
        let minuteRate = incomeCalculationService.calculateMinuteRate(
            userProfile: profile,
            workSchedule: schedule
        )
        return dailyMinutes * minuteRate
    }
    
    // MARK: - Notification Handling
    
    private func handleNotificationPreferencesChanged() {
        let currentReminderMinutes = notificationService.preferences.workEndReminderMinutes
        
        // Detect if reminder time changed
        if currentReminderMinutes != lastKnownReminderMinutes {
            lastKnownReminderMinutes = currentReminderMinutes
            
            // If we have a valid schedule, trigger rescheduling
            if let schedule = workSchedule {
                // Reset notification flags to allow new notifications
                notificationService.resetNotificationFlags()
                
                // Reschedule with new settings
                scheduleWorkNotifications()
                
                // Send immediate confirmation notification
                notificationService.sendScheduleUpdateNotification(
                    endTime: schedule.endTime,
                    reminderMinutes: currentReminderMinutes
                )
            }
        }
    }
    
    func requestNotificationPermissions() async {
        _ = await notificationService.requestPermissions()
    }
    
    // MARK: - Value Stream Integration
    func getValueStreamCalculator() -> ValueStreamCalculator? {
        return valueStreamCalculator
    }
    
    
    // MARK: - Private Methods
    private func setupBindings() {
        // Bind income calculation service
        incomeCalculationService.$currentIncome
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentIncome, on: self)
            .store(in: &cancellables)
        
        incomeCalculationService.$workStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.workStatus, on: self)
            .store(in: &cancellables)
        
        incomeCalculationService.$workProgress
            .receive(on: DispatchQueue.main)
            .assign(to: \.workProgress, on: self)
            .store(in: &cancellables)
        
        incomeCalculationService.$minuteRate
            .receive(on: DispatchQueue.main)
            .assign(to: \.minuteRate, on: self)
            .store(in: &cancellables)
        
        incomeCalculationService.$todayWorkedMinutes
            .receive(on: DispatchQueue.main)
            .assign(to: \.todayWorkedMinutes, on: self)
            .store(in: &cancellables)
        
        // Bind statistics service
        statisticsService.$weeklyStats
            .receive(on: DispatchQueue.main)
            .assign(to: \.weeklyStats, on: self)
            .store(in: &cancellables)
        
        statisticsService.$monthlyStats
            .receive(on: DispatchQueue.main)
            .assign(to: \.monthlyStats, on: self)
            .store(in: &cancellables)
        
        // Calculate estimated end time when work status changes
        $workStatus
            .combineLatest($workProgress)
            .map { [weak self] status, progress -> Date? in
                self?.calculateEstimatedEndTime(status: status, progress: progress)
            }
            .assign(to: \.estimatedEndTime, on: self)
            .store(in: &cancellables)
    }
    
    private func setupValueStreamBindings() {
        guard let calculator = valueStreamCalculator else { return }
        
        // Bind key Value Stream Calculator outputs to ViewModel
        calculator.$isOvertime
            .receive(on: DispatchQueue.main)
            .assign(to: \.isOvertime, on: self)
            .store(in: &cancellables)
        
        calculator.$overtimeMinutes
            .receive(on: DispatchQueue.main)
            .assign(to: \.overtimeMinutes, on: self)
            .store(in: &cancellables)
        
        calculator.$overtimeIncome
            .receive(on: DispatchQueue.main)
            .assign(to: \.overtimeIncome, on: self)
            .store(in: &cancellables)
        
        // Note: Other bindings can be added gradually after testing
    }
    
    private func loadUserConfiguration() {
        isLoading = true
        
        do {
            userProfile = try repositoryManager.userProfileRepository.load(key: "current")
            workSchedule = try repositoryManager.workScheduleRepository.load(key: "current")
            updateConfiguration()
        } catch {
        }
        
        // Check for monthly goal reset
        checkMonthlyGoalReset()
        
        isLoading = false
    }
    
    /// Check if we need to reset monthly goal for a new month
    private func checkMonthlyGoalReset() {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        
        let lastResetMonth = UserDefaults.standard.integer(forKey: "lastGoalResetMonth")
        let lastResetYear = UserDefaults.standard.integer(forKey: "lastGoalResetYear")
        
        // If it's a new month (or first run), reset the tracking
        if lastResetMonth != currentMonth || lastResetYear != currentYear {
            // Save the current month/year
            UserDefaults.standard.set(currentMonth, forKey: "lastGoalResetMonth")
            UserDefaults.standard.set(currentYear, forKey: "lastGoalResetYear")
            
            // Note: We don't reset the goal settings (enabled, amount, title)
            // We only track when we last checked, as the actual income is calculated fresh each day
            // The monthly accumulated income is calculated from actual work days in the month
            
        }
    }
    
    private func updateConfiguration() {
        isConfigured = userProfile != nil && workSchedule != nil
        
        if let profile = userProfile, let schedule = workSchedule {
            incomeCalculationService.updateUserProfile(profile)
            incomeCalculationService.updateWorkSchedule(schedule)
            
            // Update Value Stream Calculator with new configuration
            valueStreamCalculator?.configure(
                monthlySalary: profile.monthlySalary,
                workDaysPerMonth: profile.workdaysPerMonth,
                workSchedule: schedule
            )
        }
    }
    
    private func startRealTimeUpdates() {
        timerManager.start()
        
        // Immediate initial update to show data right away
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateRealTimeData()
        }
        
        // Start session tracking
        startSessionTracking()
        
        // Start statistics updates
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.refreshStatistics()
        }
    }
    
    private func startSessionTracking() {
        // Start session when work begins
        if sessionStartTime == nil && workStatus == .working {
            sessionStartTime = Date()
        }
        
        // Update session duration every second
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateSessionDuration()
        }
    }
    
    private func updateSessionDuration() {
        // Only count session time during working hours
        if workStatus == .working || workStatus == .overtime {
            if sessionStartTime == nil {
                sessionStartTime = Date()
            }
            if let start = sessionStartTime {
                sessionDuration = Date().timeIntervalSince(start)
            }
        }
    }
    
    private func updateRealTimeData() {
        guard isConfigured else {
            return
        }
        
        // Always update the income calculation service to get fresh data
        // This fixes the issue where workStatus never updates because calculations never run
        incomeCalculationService.updateRealTimeData()
        
        // Record daily income at end of day (once per minute check)
        recordDailyIncomeIfNeeded()
    }
    
    private var lastRecordedDate: Date?
    
    private func recordDailyIncomeIfNeeded() {
        let calendar = Calendar.current
        let now = Date()
        
        // Only record once per day and near end of work hours
        if let lastDate = lastRecordedDate, calendar.isDate(lastDate, inSameDayAs: now) {
            return
        }
        
        // Check if we're near end of work day (within 30 minutes of end time)
        if let schedule = workSchedule {
            let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
            let endComponents = calendar.dateComponents([.hour, .minute], from: schedule.endTime)
            
            let nowMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
            let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
            
            // Record if within 30 minutes of end time or past end time
            if nowMinutes >= endMinutes - 30 || workStatus == .finished {
                IncomeHistoryService.shared.recordDailyIncome(
                    income: currentIncome,
                    workedMinutes: todayWorkedMinutes,
                    isWorkday: isWorkingTime || workStatus == .finished
                )
                lastRecordedDate = now
            }
        }
    }
    
    private func calculateEstimatedEndTime(status: WorkStatus, progress: Double) -> Date? {
        guard let schedule = workSchedule, status == .working || status == .overtime else {
            return nil
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        // Get today's end time
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        let todayEndComponents = calendar.dateComponents([.hour, .minute], from: schedule.endTime)
        
        var endComponents = DateComponents()
        endComponents.year = components.year
        endComponents.month = components.month
        endComponents.day = components.day
        endComponents.hour = todayEndComponents.hour
        endComponents.minute = todayEndComponents.minute
        
        return calendar.date(from: endComponents)
    }
    
    private func saveUserProfile() {
        guard let profile = userProfile else { return }
        do {
            try repositoryManager.userProfileRepository.save(profile, key: "current")
        } catch {
        }
    }
    
    private func saveWorkSchedule() {
        guard let schedule = workSchedule else { return }
        do {
            try repositoryManager.workScheduleRepository.save(schedule, key: "current")
        } catch {
        }
    }
    
    private func scheduleWorkNotifications() {
        guard let schedule = workSchedule else { return }
        
        // Schedule recurring daily work start/end notifications
        notificationService.scheduleDailyWorkNotifications(
            startTime: schedule.startTime,
            endTime: schedule.endTime,
            workdays: schedule.workdays
        )
    }
}

// MARK: - Convenience Extensions
extension EnhancedIncomeViewModel {
    
    var isWorkingTime: Bool {
        return workStatus == .working
    }
    
    var isOnBreak: Bool {
        return workStatus == .lunch
    }
    
    
    var isDayFinished: Bool {
        return workStatus == .finished
    }
    
    var hasCompletedWorkToday: Bool {
        guard let schedule = workSchedule else { return false }
        return todayWorkedMinutes >= schedule.totalWorkMinutesPerDay
    }
    
    var timeUntilEnd: TimeInterval? {
        guard let endTime = estimatedEndTime else { return nil }
        let remaining = endTime.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }
    
    var formattedTimeUntilEnd: String {
        guard let timeRemaining = timeUntilEnd else { return "Finished" }
        
        let hours = Int(timeRemaining / 3600)
        let minutes = Int((timeRemaining.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var formattedWorkedTime: String {
        let hours = Int(todayWorkedMinutes / 60)
        let minutes = Int(todayWorkedMinutes.truncatingRemainder(dividingBy: 60))
        
        return "\(hours)h \(minutes)m"
    }
    
    var formattedOvertimeTime: String {
        guard overtimeMinutes > 0 else { return "" }
        
        let hours = Int(overtimeMinutes / 60)
        let minutes = Int(overtimeMinutes.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return "Overtime \(hours)h \(minutes)m"
        } else {
            return "Overtime \(minutes)m"
        }
    }
    
    /// Formatted session duration (e.g., "2h 34m")
    var formattedSessionDuration: String {
        let hours = Int(sessionDuration / 3600)
        let minutes = Int((sessionDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Formatted work schedule time range (e.g., "08:30 - 17:30")
    var formattedWorkSchedule: String {
        guard let schedule = workSchedule else { return "Not Set" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let start = formatter.string(from: schedule.startTime)
        let end = formatter.string(from: schedule.endTime)
        
        return "\(start) - \(end)"
    }
    
    /// Formatted working days (e.g., "Mon-Fri")
    var formattedWorkDays: String {
        guard let schedule = workSchedule else { return "Not Set" }
        
        let sortedDays = schedule.workdays.sorted { $0.calendarWeekday < $1.calendarWeekday }
        
        if sortedDays.count == 0 {
            return "No days set"
        }
        
        // Check if it's a continuous range (Mon-Fri style)
        if sortedDays.count >= 3 {
            let weekdayValues = sortedDays.map { $0.calendarWeekday }
            let isContinuous = weekdayValues.enumerated().allSatisfy { index, value in
                index == 0 || value == weekdayValues[index - 1] + 1
            }
            
            if isContinuous, let first = sortedDays.first, let last = sortedDays.last {
                return "\(first.shortName)-\(last.shortName)"
            }
        }
        
        // Otherwise list all days
        return sortedDays.map { $0.shortName }.joined(separator: ", ")
    }
    
    func getWorkStatusIcon() -> String {
        switch workStatus {
        case .notStarted:
            return "clock"
        case .working:
            return "person.fill.viewfinder"
        case .lunch:
            return "fork.knife"
        case .overtime:
            return "exclamationmark.triangle.fill"
        case .finished:
            return "checkmark.circle.fill"
        case .absent:
            return "xmark.circle"
        case .holiday:
            return "sun.max.fill"
        }
    }
    
    func getWorkStatusColor() -> Color {
        switch workStatus {
        case .notStarted:
            return .gray
        case .working:
            return .green
        case .lunch:
            return .orange
        case .overtime:
            return .red
        case .finished:
            return .blue
        case .absent:
            return .red
        case .holiday:
            return .purple
        }
    }
}

// MARK: - Input Validation
extension EnhancedIncomeViewModel {
    
    struct ValidationError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    
    /// Validates salary input (1,000 - 10,000,000)
    static func validateSalary(_ value: String) -> Result<Double, ValidationError> {
        guard let salary = Double(value.replacingOccurrences(of: ",", with: "")) else {
            return .failure(ValidationError(message: "Invalid number format"))
        }
        
        if salary < 1000 {
            return .failure(ValidationError(message: "Salary must be at least ¥1,000"))
        }
        
        if salary > 10_000_000 {
            return .failure(ValidationError(message: "Salary exceeds maximum (¥10,000,000)"))
        }
        
        return .success(salary)
    }
    
    /// Validates work days per month (1 - 31)
    static func validateWorkDays(_ value: Int) -> Result<Int, ValidationError> {
        if value < 1 {
            return .failure(ValidationError(message: "Work days must be at least 1"))
        }
        
        if value > 31 {
            return .failure(ValidationError(message: "Work days cannot exceed 31"))
        }
        
        return .success(value)
    }
    
    /// Validates goal amount (100 - 100,000,000)
    static func validateGoalAmount(_ value: String) -> Result<Double, ValidationError> {
        guard let amount = Double(value.replacingOccurrences(of: ",", with: "")) else {
            return .failure(ValidationError(message: "Invalid number format"))
        }
        
        if amount < 100 {
            return .failure(ValidationError(message: "Goal must be at least ¥100"))
        }
        
        if amount > 100_000_000 {
            return .failure(ValidationError(message: "Goal exceeds maximum"))
        }
        
        return .success(amount)
    }
    
    /// Validates work schedule times (start < end)
    static func validateWorkTimes(start: Date, end: Date) -> Result<Bool, ValidationError> {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: start)
        let endComponents = calendar.dateComponents([.hour, .minute], from: end)
        
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        
        if endMinutes <= startMinutes {
            return .failure(ValidationError(message: "End time must be after start time"))
        }
        
        let workHours = Double(endMinutes - startMinutes) / 60.0
        if workHours < 1 {
            return .failure(ValidationError(message: "Work day must be at least 1 hour"))
        }
        
        if workHours > 24 {
            return .failure(ValidationError(message: "Work day cannot exceed 24 hours"))
        }
        
        return .success(true)
    }
}

// MARK: - Compatibility with Original IncomeViewModel
extension EnhancedIncomeViewModel {
    
    func syncFromOriginalViewModel() {
        guard let original = originalViewModel else { return }
        
        // Convert original data to new format
        if original.isConfigured {
            let profile = UserProfile(
                name: "User",
                monthlySalary: original.monthlySalary,
                workdaysPerMonth: original.workdaysPerMonth,
                currency: "CNY"
            )
            
            let schedule = WorkSchedule(
                startTime: original.startTime,
                endTime: original.endTime,
                lunchStartTime: original.lunchStartTime,
                lunchEndTime: original.lunchEndTime,
                workdays: [.monday, .tuesday, .wednesday, .thursday, .friday]
            )
            
            updateUserProfile(profile)
            updateWorkSchedule(schedule)
            
            // Note: Do NOT sync currentIncome from originalViewModel
            // currentIncome should be managed solely by IncomeCalculationService
            // to avoid double-updating from two sources
        }
    }
    
    private func setupOriginalViewModelBinding() {
        guard let original = originalViewModel else { return }
        
        // Only listen to configuration changes, NOT income updates
        // This prevents currentIncome from being overwritten by legacy calculator
        original.$isConfigured
            .sink { [weak self] configured in
                if configured {
                    self?.syncFromOriginalViewModel()
                }
            }
            .store(in: &cancellables)
    }
}