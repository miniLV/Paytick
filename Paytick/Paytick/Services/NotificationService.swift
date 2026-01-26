import Foundation
import UserNotifications
import AppKit
import Combine

// MARK: - Notification Service Protocol
protocol NotificationServiceProtocol {
    func requestPermissions() async -> Bool
    func showRewardAchievedNotification(reward: Reward)
    func showDailyIncomeUpdate(income: Double, privacyEnabled: Bool, formatter: PrivacyIconSettings?)
    func cancelAllNotifications()
    func cancelNotification(with identifier: String)
    func setNotificationPreferences(_ preferences: NotificationPreferences)
}

// MARK: - Notification Preferences
struct NotificationPreferences: Codable {
    var workStartEnabled: Bool = true
    var workEndEnabled: Bool = true
    var rewardAchievementEnabled: Bool = true
    var monthlyGoalEnabled: Bool = true
    var dailyIncomeEnabled: Bool = false
    var soundEnabled: Bool = true
    var badgeEnabled: Bool = true
    
    /// Minutes before work end time to send reminder (default: 5)
    var workEndReminderMinutes: Int = 5
    
    // Legacy property (kept for compatibility, not actively used)
    var overtimeWarningEnabled: Bool = false
    
    init() {}
}

// MARK: - Notification Types
enum NotificationType: String, CaseIterable {
    case workStart = "work_start"
    case workEnd = "work_end"
    case rewardAchieved = "reward_achieved"
    case dailyIncome = "daily_income"
    case scheduleUpdate = "schedule_update"
    case monthlyGoal = "monthly_goal"
    
    var title: String {
        switch self {
        case .workStart: return "Prepare for Work"
        case .workEnd: return "Time to get off work!"
        case .rewardAchieved: return "Congratulations! Reward Achieved"
        case .dailyIncome: return "Today's Income Update"
        case .scheduleUpdate: return "Work Schedule Updated"
        case .monthlyGoal: return "Monthly Goal Achieved!"
        }
    }
}

// MARK: - Notification Service Implementation
class NotificationService: NSObject, NotificationServiceProtocol, ObservableObject {
    
    static let shared = NotificationService()
    
    @Published var preferences: NotificationPreferences = NotificationPreferences()
    @Published var permissionGranted: Bool = false
    @Published var pendingNotifications: [UNNotificationRequest] = []
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private var cancellables = Set<AnyCancellable>()
    
    // Timer-based notification system (most reliable approach)
    private var notificationTimer: Timer?
    private var targetStartNotifyTime: Date?
    private var targetEndNotifyTime: Date?
    private var currentWorkdays: Set<Weekday> = []
    
    // Prevent duplicate notifications
    private var workStartNotificationSentToday: Date?
    private var workEndNotificationSentToday: Date?
    private var scheduleUpdateNotificationSent: Date?
    
    // MARK: - Fun Messages
    private let workStartMessages = [
        "☕️ A new day begins! Time to grind~",
        "🚀 Work hard, earn hard!",
        "💪 Good morning! Your wallet is waiting!",
        "🎯 Timer started! Every minute counts~",
        "⏰ Work time! Let's be productive!",
        "🔥 Let the coins roll in!",
        "💰 The income ticker is live!",
        "🌟 Another day to invest in your dreams!"
    ]
    
    private let workEndMessages = [
        "🎉 Work's done! Take a break~",
        "🌙 Clocked out! You did amazing!",
        "🍻 Time to enjoy life!",
        "🏠 Time to head home!",
        "✨ Great job today!",
        "🎊 Mission accomplished!",
        "🌈 See you tomorrow!",
        "🍜 Go have a delicious dinner~"
    ]
    
    // MARK: - Initialization
    override init() {
        super.init()
        loadPreferences()
        setupNotificationCenter()
        checkPermissionStatus()
        setupSystemObservers()
        clearAllOldNotifications()
    }
    
    private func clearAllOldNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
    
    // MARK: - System Observers
    private func setupSystemObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemTimeChanged),
            name: NSNotification.Name.NSSystemClockDidChange,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemTimeChanged),
            name: NSNotification.Name.NSSystemTimeZoneDidChange,
            object: nil
        )
    }
    
    @objc private func systemTimeChanged() {
        NotificationCenter.default.post(name: NSNotification.Name("RequestNotificationReschedule"), object: nil)
    }
    
    // MARK: - Permission Management
    func requestPermissions() async -> Bool {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        
        do {
            let granted = try await notificationCenter.requestAuthorization(options: options)
            await MainActor.run {
                self.permissionGranted = granted
            }
            
            if granted {
                await registerNotificationCategories()
            }
            
            return granted
        } catch {
            await MainActor.run {
                self.permissionGranted = false
            }
            return false
        }
    }
    
    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func checkIfDenied() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus == .denied
    }
    
    private func checkPermissionStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.permissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func registerNotificationCategories() async {
        let workEndCategory = UNNotificationCategory(
            identifier: NotificationType.workEnd.rawValue,
            actions: [
                UNNotificationAction(identifier: "end_work", title: "End Work", options: [.destructive])
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let rewardCategory = UNNotificationCategory(
            identifier: NotificationType.rewardAchieved.rawValue,
            actions: [
                UNNotificationAction(identifier: "view_reward", title: "View Reward", options: [.foreground])
            ],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([workEndCategory, rewardCategory])
    }
    
    // MARK: - Work Notifications (Timer-based)
    
    /// Schedule work notifications using Timer (most reliable approach)
    func scheduleDailyWorkNotifications(startTime: Date, endTime: Date, workdays: Set<Weekday>) {
        stopNotificationTimer()
        clearAllOldNotifications()
        currentWorkdays = workdays
        
        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self = self, settings.authorizationStatus == .authorized else { return }
            
            DispatchQueue.main.async {
                self.setupNotificationTimes(startTime: startTime, endTime: endTime, workdays: workdays)
            }
        }
    }
    
    private func setupNotificationTimes(startTime: Date, endTime: Date, workdays: Set<Weekday>) {
        // Use a calendar with explicit local timezone to avoid timezone issues
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let now = Date()
        
        // Check if today is a workday
        let currentWeekday = calendar.component(.weekday, from: now)
        guard let todayWeekday = Weekday.allCases.first(where: { $0.calendarWeekday == currentWeekday }),
              workdays.contains(todayWeekday) else {
            targetStartNotifyTime = nil
            targetEndNotifyTime = nil
            return
        }
        
        let todayDate = calendar.startOfDay(for: now)
        
        // Work START notification (5 minutes before)
        if preferences.workStartEnabled {
            // Extract hour and minute using local calendar (NOT dateComponents(in:from:) which can have timezone issues)
            let startHour = calendar.component(.hour, from: startTime)
            let startMinute = calendar.component(.minute, from: startTime)
            
            if let todayStartTime = calendar.date(bySettingHour: startHour,
                                                   minute: startMinute,
                                                   second: 0,
                                                   of: todayDate) {
                let notifyTime = calendar.date(byAdding: .minute, value: -5, to: todayStartTime)!
                targetStartNotifyTime = notifyTime > now ? notifyTime : nil
                
                #if DEBUG
                print("[NotificationService] Start time configured: \(startHour):\(String(format: "%02d", startMinute)), notify at: \(notifyTime), now: \(now)")
                #endif
            }
        } else {
            targetStartNotifyTime = nil
        }
        
        // Work END notification (N minutes before)
        if preferences.workEndEnabled {
            // Extract hour and minute using local calendar (NOT dateComponents(in:from:) which can have timezone issues)
            let endHour = calendar.component(.hour, from: endTime)
            let endMinute = calendar.component(.minute, from: endTime)
            
            // Sanity check: if endHour is before typical work hours (e.g., < 12), it might be a timezone bug
            // Log a warning but still proceed
            #if DEBUG
            if endHour < 12 {
                print("[NotificationService] WARNING: End hour (\(endHour)) is before noon. Possible timezone issue with stored endTime: \(endTime)")
            }
            #endif
            
            if let todayEndTime = calendar.date(bySettingHour: endHour,
                                                 minute: endMinute,
                                                 second: 0,
                                                 of: todayDate) {
                let notifyTime = calendar.date(byAdding: .minute, value: -preferences.workEndReminderMinutes, to: todayEndTime)!
                targetEndNotifyTime = notifyTime > now ? notifyTime : nil
                
                #if DEBUG
                print("[NotificationService] End time configured: \(endHour):\(String(format: "%02d", endMinute)), notify at: \(notifyTime), now: \(now)")
                #endif
            }
        } else {
            targetEndNotifyTime = nil
        }
        
        // Start timer if we have targets
        if targetStartNotifyTime != nil || targetEndNotifyTime != nil {
            startNotificationTimer()
        }
    }
    
    private func startNotificationTimer() {
        stopNotificationTimer()
        
        notificationTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            autoreleasepool {
                self?.checkAndFireNotifications()
            }
        }
        
        // Delay the first check by 2 seconds to avoid immediate triggering when settings change
        // This prevents false positives when the user is actively adjusting notification times
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.checkAndFireNotifications()
        }
    }
    
    private func stopNotificationTimer() {
        notificationTimer?.invalidate()
        notificationTimer = nil
    }
    
    private func checkAndFireNotifications() {
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        // Verify today is still a workday
        let currentWeekday = calendar.component(.weekday, from: now)
        guard let todayWeekday = Weekday.allCases.first(where: { $0.calendarWeekday == currentWeekday }),
              currentWorkdays.contains(todayWeekday) else {
            return
        }
        
        // Check work START notification
        if let targetStart = targetStartNotifyTime,
           !hasNotificationBeenSentToday(flag: workStartNotificationSentToday) {
            let diff = now.timeIntervalSince(targetStart)
            if diff >= -5 && diff <= 60 {
                fireNotification(
                    id: NotificationType.workStart.rawValue,
                    title: "🌅 \(NotificationType.workStart.title)",
                    body: workStartMessages.randomElement() ?? "Time to start work!"
                )
                workStartNotificationSentToday = now
                targetStartNotifyTime = nil
            }
        }
        
        // Check work END notification
        if let targetEnd = targetEndNotifyTime,
           !hasNotificationBeenSentToday(flag: workEndNotificationSentToday) {
            let diff = now.timeIntervalSince(targetEnd)
            if diff >= -5 && diff <= 60 {
                fireNotification(
                    id: NotificationType.workEnd.rawValue,
                    title: "🌙 \(NotificationType.workEnd.title)",
                    body: "Only \(preferences.workEndReminderMinutes) minutes left! \(workEndMessages.randomElement() ?? "")"
                )
                workEndNotificationSentToday = now
                targetEndNotifyTime = nil
            }
        }
        
        // Stop timer if no more targets
        if targetStartNotifyTime == nil && targetEndNotifyTime == nil {
            stopNotificationTimer()
        }
    }
    
    private func hasNotificationBeenSentToday(flag: Date?) -> Bool {
        guard let sentDate = flag else { return false }
        return Calendar.current.isDateInToday(sentDate)
    }
    
    /// Fire an instant notification
    private func fireNotification(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = preferences.soundEnabled ? UNNotificationSound.default : nil
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        notificationCenter.add(request)
    }
    
    /// Reset notification flags (call when schedule changes)
    /// Note: Only resets the schedule update flag, NOT the daily work notification flags
    /// This prevents duplicate work start/end notifications when settings are changed
    func resetNotificationFlags() {
        scheduleUpdateNotificationSent = nil
        // Do NOT reset workStartNotificationSentToday and workEndNotificationSentToday here
        // These should only reset at midnight (when isDateInToday returns false)
        // Resetting them here causes duplicate notifications when settings are changed
    }
    
    /// Force reset all notification flags including daily work notifications
    /// Use this only when you explicitly want to re-enable notifications for today
    func forceResetAllNotificationFlags() {
        scheduleUpdateNotificationSent = nil
        workStartNotificationSentToday = nil
        workEndNotificationSentToday = nil
    }
    
    /// Send schedule update confirmation
    func sendScheduleUpdateNotification(endTime: Date, reminderMinutes: Int) {
        guard permissionGranted else { return }
        
        // Prevent duplicate within 5 seconds
        let now = Date()
        if let lastSent = scheduleUpdateNotificationSent, now.timeIntervalSince(lastSent) < 5 {
            return
        }
        scheduleUpdateNotificationSent = now
        
        // Use calendar with explicit local timezone
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        // Extract hour and minute using local calendar component method (safer than dateComponents(in:from:))
        let endHour = calendar.component(.hour, from: endTime)
        let endMinute = calendar.component(.minute, from: endTime)
        
        // Calculate reminder time
        let totalMinutes = endHour * 60 + endMinute - reminderMinutes
        let reminderHour = max(0, totalMinutes / 60)
        let reminderMinute = max(0, totalMinutes % 60)
        
        // Format times for display
        let endTimeStr = String(format: "%d:%02d %@", endHour > 12 ? endHour - 12 : (endHour == 0 ? 12 : endHour), endMinute, endHour >= 12 ? "PM" : "AM")
        let reminderTimeStr = String(format: "%d:%02d %@", reminderHour > 12 ? reminderHour - 12 : (reminderHour == 0 ? 12 : reminderHour), reminderMinute, reminderHour >= 12 ? "PM" : "AM")
        
        #if DEBUG
        print("[NotificationService] Schedule update - End time: \(endHour):\(String(format: "%02d", endMinute)), Reminder: \(reminderMinutes) min before, raw endTime: \(endTime)")
        #endif
        
        fireNotification(
            id: "\(NotificationType.scheduleUpdate.rawValue)_\(now.timeIntervalSince1970)",
            title: "✅ \(NotificationType.scheduleUpdate.title)",
            body: "Work end reminder set for \(reminderTimeStr) (\(reminderMinutes) min before \(endTimeStr))"
        )
    }
    
    // MARK: - Other Notifications
    
    func showRewardAchievedNotification(reward: Reward) {
        guard preferences.rewardAchievementEnabled && permissionGranted else { return }
        
        fireNotification(
            id: "\(NotificationType.rewardAchieved.rawValue)_\(reward.id)",
            title: "🎉 \(NotificationType.rewardAchieved.title)",
            body: "You have completed \"\(reward.title)\"! \(reward.rewardType.emoji)"
        )
    }
    
    func showDailyIncomeUpdate(income: Double, privacyEnabled: Bool, formatter: PrivacyIconSettings?) {
        guard preferences.dailyIncomeEnabled && permissionGranted else { return }
        
        let incomeText = privacyEnabled && formatter != nil
            ? formatter!.formatAmount(income)
            : "¥\(String(format: "%.2f", income))"
        
        fireNotification(
            id: "\(NotificationType.dailyIncome.rawValue)_\(Date().timeIntervalSince1970)",
            title: "💰 \(NotificationType.dailyIncome.title)",
            body: "Today's Income: \(incomeText)"
        )
    }
    
    func showMonthlyGoalCompletedNotification(goalTitle: String, targetAmount: Double) {
        guard preferences.monthlyGoalEnabled && permissionGranted else { return }
        
        let body = goalTitle.isEmpty
            ? "Congratulations! You completed this month's income goal of ¥\(String(format: "%.0f", targetAmount))!"
            : "Congratulations! You've earned enough for \(goalTitle)! (¥\(String(format: "%.0f", targetAmount)))"
        
        fireNotification(
            id: "\(NotificationType.monthlyGoal.rawValue)_\(Date().timeIntervalSince1970)",
            title: "🎉 \(NotificationType.monthlyGoal.title)",
            body: body
        )
    }
    
    // MARK: - Notification Management
    
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
    
    func cancelNotification(with identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    func cancelNotificationsOfType(_ type: NotificationType) {
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let identifiers = requests.filter { $0.identifier.hasPrefix(type.rawValue) }.map { $0.identifier }
            self?.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
    
    // MARK: - Preferences Management
    
    func setNotificationPreferences(_ preferences: NotificationPreferences) {
        objectWillChange.send()
        self.preferences = preferences
        savePreferences()
        
        if !preferences.workEndEnabled {
            cancelNotificationsOfType(.workEnd)
        }
        
        if !preferences.rewardAchievementEnabled {
            cancelNotificationsOfType(.rewardAchieved)
        }
    }
    
    private func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: "notificationPreferences"),
           let prefs = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            self.preferences = prefs
        }
    }
    
    private func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: "notificationPreferences")
        }
    }
    
    // MARK: - Setup
    
    // Timer for updating pending notifications - stored to allow cleanup
    private var pendingNotificationsTimer: Timer?
    
    private func setupNotificationCenter() {
        notificationCenter.delegate = self
        updatePendingNotifications()
        
        pendingNotificationsTimer?.invalidate()
        pendingNotificationsTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            autoreleasepool {
                self?.updatePendingNotifications()
            }
        }
    }
    
    private func updatePendingNotifications() {
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            DispatchQueue.main.async {
                self?.pendingNotifications = requests
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionIdentifier = response.actionIdentifier
        let notificationIdentifier = response.notification.request.identifier
        
        switch actionIdentifier {
        case "end_work":
            NotificationCenter.default.post(name: NSNotification.Name("EndWorkTime"), object: nil)
        case "view_reward":
            let rewardId = String(notificationIdentifier.suffix(notificationIdentifier.count - "reward_achieved_".count))
            NotificationCenter.default.post(
                name: NSNotification.Name("ViewReward"),
                object: nil,
                userInfo: ["rewardId": rewardId]
            )
        case UNNotificationDefaultActionIdentifier:
            NotificationCenter.default.post(name: NSNotification.Name("OpenMainWindow"), object: nil)
        default:
            break
        }
        
        completionHandler()
    }
}

// MARK: - Smart Notification Scheduler (Simplified)
class SmartNotificationScheduler: ObservableObject {
    private let notificationService: NotificationService
    private let incomeCalculationService: IncomeCalculationService
    
    init(notificationService: NotificationService, incomeCalculationService: IncomeCalculationService) {
        self.notificationService = notificationService
        self.incomeCalculationService = incomeCalculationService
    }
}
