import Foundation
import UserNotifications
import AppKit
import Combine

// MARK: - Notification Service Protocol
protocol NotificationServiceProtocol {
    func requestPermissions() async -> Bool
    func scheduleWorkEndReminder(endTime: Date, userProfile: UserProfile)
    func scheduleOvertimeWarning(currentWorkTime: TimeInterval, normalWorkTime: TimeInterval)
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
    var overtimeWarningEnabled: Bool = true
    var rewardAchievementEnabled: Bool = true
    var monthlyGoalEnabled: Bool = true
    var dailyIncomeEnabled: Bool = false
    var soundEnabled: Bool = true
    var badgeEnabled: Bool = true
    
    var overtimeThreshold: TimeInterval = 3600 // 1 hour
    var workEndReminderMinutes: Int = 15 // 15 minutes before end time
    var dailyIncomeInterval: TimeInterval = 3600 // 1 hour
    
    init() {}
}

// MARK: - Notification Types
enum NotificationType: String, CaseIterable {
    case workEnd = "work_end"
    case overtime = "overtime"
    case rewardAchieved = "reward_achieved"
    case dailyIncome = "daily_income"
    case lunchBreak = "lunch_break"
    case workStart = "work_start"
    
    var title: String {
        switch self {
        case .workEnd:
            return "Time to get off work!"
        case .overtime:
            return "Overtime Alert"
        case .rewardAchieved:
            return "Congratulations! Reward Achieved"
        case .dailyIncome:
            return "Today's Income Update"
        case .lunchBreak:
            return "Lunch Break"
        case .workStart:
            return "Work Started"
        }
    }
    
    var sound: String {
        switch self {
        case .workEnd:
            return "work_end.wav"
        case .overtime:
            return "warning.wav"
        case .rewardAchieved:
            return "achievement.wav"
        case .dailyIncome:
            return "income_update.wav"
        case .lunchBreak:
            return "gentle.wav"
        case .workStart:
            return "start.wav"
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
    private let repositoryManager = RepositoryManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Notification sent flags to prevent duplicates
    private var workStartNotificationSentToday: Date?
    private var workEndNotificationSentToday: Date?
    private var scheduleUpdateNotificationSent: Date?
    
    
    override init() {
        super.init()
        loadPreferences()
        setupNotificationCenter()
        checkPermissionStatus()
    }
    
    // MARK: - Permission Management
    func requestPermissions() async -> Bool {
        // Remove .provisional to force system permission dialog
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
    
    /// Open System Settings to notification preferences
    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Check if permission was denied (not just not determined)
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
                UNNotificationAction(identifier: "extend_work", title: "Continue Working", options: []),
                UNNotificationAction(identifier: "end_work", title: "End Work", options: [.destructive])
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let overtimeCategory = UNNotificationCategory(
            identifier: NotificationType.overtime.rawValue,
            actions: [
                UNNotificationAction(identifier: "continue_overtime", title: "Continue Overtime", options: []),
                UNNotificationAction(identifier: "end_overtime", title: "Stop Overtime", options: [.destructive])
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
        
        notificationCenter.setNotificationCategories([workEndCategory, overtimeCategory, rewardCategory])
    }
    
    // MARK: - Fun Work Notification Messages
    private let workStartMessages = [
        "☕️ A new day begins! Time to grind~",
        "🚀 Work hard, earn hard! How much are we making today?",
        "💪 Good morning! Your wallet is waiting to be filled!",
        "🎯 Timer started! Every minute counts towards your goals~",
        "⏰ Work time! Let's have a productive day!",
        "🔥 Let the coins roll in!",
        "💰 Drip, drip... the income ticker is live!",
        "🌟 Another day to invest in your dreams!"
    ]
    
    private let workEndMessages = [
        "🎉 Work's done! Take a well-deserved break~",
        "🌙 Clocked out! You did amazing today!",
        "🍻 It's time to enjoy life!",
        "🏠 Time to head home and relax!",
        "✨ Great job today, give yourself a pat on the back!",
        "🎊 Mission accomplished! Today's tasks are done~",
        "🌈 See you tomorrow! Keep up the great work!",
        "🍜 You've earned it! Go have a delicious dinner~"
    ]
    
    // MARK: - Notification Scheduling
    
    /// Schedule work start reminder notification
    func scheduleWorkStartReminder(startTime: Date) {
        guard preferences.workStartEnabled && permissionGranted else { return }
        
        // Schedule for 5 minutes before work starts
        let reminderTime = Calendar.current.date(
            byAdding: .minute,
            value: -5,
            to: startTime
        ) ?? startTime
        
        guard reminderTime > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🌅 Prepare for Work"
        content.body = workStartMessages.randomElement() ?? workStartMessages[0]
        content.sound = preferences.soundEnabled ? UNNotificationSound.default : nil
        content.badge = preferences.badgeEnabled ? 1 : nil
        
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "workStart_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
            } else {
            }
        }
    }
    
    func scheduleWorkEndReminder(endTime: Date, userProfile: UserProfile) {
        guard preferences.workEndEnabled && permissionGranted else { return }
        
        let reminderTime = Calendar.current.date(
            byAdding: .minute,
            value: -preferences.workEndReminderMinutes,
            to: endTime
        ) ?? endTime
        
        guard reminderTime > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = NotificationType.workEnd.title
        content.body = workEndMessages.randomElement() ?? "Only \(preferences.workEndReminderMinutes) minutes left until the end of the work day. Great job today!"
        content.categoryIdentifier = NotificationType.workEnd.rawValue
        content.sound = preferences.soundEnabled ? UNNotificationSound.default : nil
        content.badge = preferences.badgeEnabled ? 1 : nil
        
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "\(NotificationType.workEnd.rawValue)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
            } else {
            }
        }
    }
    
    func scheduleOvertimeWarning(currentWorkTime: TimeInterval, normalWorkTime: TimeInterval) {
        guard preferences.overtimeWarningEnabled && permissionGranted else { return }
        
        let overtimeMinutes = (currentWorkTime - normalWorkTime) / 60
        guard overtimeMinutes > 0 && Int(overtimeMinutes) % 30 == 0 else { return } // Every 30 minutes
        
        let content = UNMutableNotificationContent()
        content.title = NotificationType.overtime.title
        content.body = "You have been working overtime for \(Int(overtimeMinutes)) minutes. Please take a break!"
        content.categoryIdentifier = NotificationType.overtime.rawValue
        content.sound = preferences.soundEnabled ? UNNotificationSound.default : nil
        
        let request = UNNotificationRequest(
            identifier: "\(NotificationType.overtime.rawValue)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
            }
        }
    }
    
    func showRewardAchievedNotification(reward: Reward) {
        guard preferences.rewardAchievementEnabled && permissionGranted else { return }
        
        let content = UNMutableNotificationContent()
        content.title = NotificationType.rewardAchieved.title
        content.body = "Congratulations! You have completed the \"\(reward.title)\" reward!"
        content.categoryIdentifier = NotificationType.rewardAchieved.rawValue
        content.sound = preferences.soundEnabled ? UNNotificationSound.default : nil
        content.badge = preferences.badgeEnabled ? 1 : nil
        
        // Add reward emoji based on type
        content.body += " \(reward.rewardType.emoji)"
        
        let request = UNNotificationRequest(
            identifier: "\(NotificationType.rewardAchieved.rawValue)_\(reward.id)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
            }
        }
    }
    
    func showDailyIncomeUpdate(income: Double, privacyEnabled: Bool, formatter: PrivacyIconSettings?) {
        guard preferences.dailyIncomeEnabled && permissionGranted else { return }
        
        let content = UNMutableNotificationContent()
        content.title = NotificationType.dailyIncome.title
        
        if privacyEnabled, let formatter = formatter {
            content.body = "Today's Income: \(formatter.formatAmount(income))"
        } else {
            content.body = "Today's Income: ¥\(String(format: "%.2f", income))"
        }
        
        content.sound = preferences.soundEnabled ? UNNotificationSound.default : nil
        
        let request = UNNotificationRequest(
            identifier: "\(NotificationType.dailyIncome.rawValue)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
            }
        }
    }
    
    func scheduleLunchBreakReminder(lunchTime: Date) {
        guard permissionGranted else { return }
        
        let content = UNMutableNotificationContent()
        content.title = NotificationType.lunchBreak.title
        content.body = "It's lunch break time, remember to take a rest!"
        content.sound = preferences.soundEnabled ? UNNotificationSound(named: UNNotificationSoundName("gentle.wav")) : nil
        
        let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: lunchTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "daily_lunch_reminder",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
            }
        }
    }
    
    /// Schedule daily work notifications based on work schedule
    func scheduleDailyWorkNotifications(startTime: Date, endTime: Date, workdays: Set<Weekday>) {
        // Cancel existing daily notifications first
        print("🔄 [Notification] Rescheduling daily work notifications (cancelling old ones first)")
        cancelDailyWorkNotifications()
        
        guard permissionGranted else {
            print("⚠️ [Notification] Cannot schedule notifications - permission not granted")
            return
        }
        
        let calendar = Calendar.current
        
        // Debug: Log the input times
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        print("📅 [Notification] Scheduling daily notifications:")
        print("   Start time: \(formatter.string(from: startTime))")
        print("   End time: \(formatter.string(from: endTime))")
        print("   Workdays: \(workdays.map { $0.rawValue }.joined(separator: ", "))")
        
        // Schedule work start notification for each workday (5 minutes before start)
        if preferences.workStartEnabled {
            for weekday in workdays {
                let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
                var triggerComponents = DateComponents()
                triggerComponents.weekday = weekday.calendarWeekday
                
                // 5 minutes before start time
                let totalMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0) - 5
                triggerComponents.hour = max(0, totalMinutes / 60)
                triggerComponents.minute = max(0, totalMinutes % 60)
                
                print("   🌅 Work START notification for \(weekday.rawValue): \(String(format: "%02d:%02d", triggerComponents.hour ?? 0, triggerComponents.minute ?? 0)) (5 min before start)")
                
                let content = UNMutableNotificationContent()
                content.title = "🌅 Prepare for Work"
                content.body = workStartMessages.randomElement() ?? workStartMessages[0]
                content.sound = preferences.soundEnabled ? UNNotificationSound.default : nil
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "daily_work_start_\(weekday.rawValue)",
                    content: content,
                    trigger: trigger
                )
                
                notificationCenter.add(request) { error in
                    if let error = error {
                    } else {
                    }
                }
            }
        }
        
        // Schedule work end notification for each workday (N minutes before end, configurable)
        if preferences.workEndEnabled {
            print("   ⏰ Work END reminder offset: \(preferences.workEndReminderMinutes) minutes before end time")
            for weekday in workdays {
                let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
                var triggerComponents = DateComponents()
                triggerComponents.weekday = weekday.calendarWeekday
                
                // Calculate reminder time (N minutes before end based on user setting)
                let totalMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0) - preferences.workEndReminderMinutes
                triggerComponents.hour = max(0, totalMinutes / 60)
                triggerComponents.minute = max(0, totalMinutes % 60)
                
                print("   🌙 Scheduling Work END for \(weekday.rawValue) at \(String(format: "%02d:%02d", triggerComponents.hour ?? 0, triggerComponents.minute ?? 0))")
                
                let content = UNMutableNotificationContent()
                content.title = NotificationType.workEnd.title
                content.body = preferences.workEndReminderMinutes > 0
                    ? "Only \(preferences.workEndReminderMinutes) minutes left until the end of the work day! \(workEndMessages.randomElement() ?? "")"
                    : workEndMessages.randomElement() ?? "Time to get off work! Great job today!"
                content.categoryIdentifier = NotificationType.workEnd.rawValue
                content.sound = preferences.soundEnabled ? UNNotificationSound.default : nil
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "daily_work_end_\(weekday.rawValue)",
                    content: content,
                    trigger: trigger
                )
                
                notificationCenter.add(request) { error in
                    if let error = error {
                        print("      ❌ Failed to schedule work END notification for \(weekday.rawValue): \(error.localizedDescription)")
                    } else {
                        print("      ✅ Successfully scheduled work END notification for \(weekday.rawValue) with ID: \(request.identifier)")
                        
                        // Check if trigger time has passed today
                        let now = Date()
                        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
                        let nowMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
                        
                        if totalMinutes < nowMinutes {
                            print("      ⚠️ Trigger time (\(String(format: "%02d:%02d", triggerComponents.hour ?? 0, triggerComponents.minute ?? 0))) has passed today (current: \(String(format: "%02d:%02d", nowComponents.hour ?? 0, nowComponents.minute ?? 0)))")
                            print("      📅 Next notification will fire: Next \(weekday.rawValue)")
                        } else {
                            let minutesUntilTrigger = totalMinutes - nowMinutes
                            print("      ✅ Trigger time is in the future - will fire in \(minutesUntilTrigger) minutes")
                            
                            // If trigger is within next 30 minutes, also schedule an immediate one-time notification
                            // This ensures notification fires even if recurring trigger misses due to timing
                            if minutesUntilTrigger <= 30 && minutesUntilTrigger > 0 {
                                // Calculate exact trigger time (e.g., 4:17:00, not 4:17:30)
                                var exactTriggerComponents = DateComponents()
                                exactTriggerComponents.hour = triggerComponents.hour
                                exactTriggerComponents.minute = triggerComponents.minute
                                exactTriggerComponents.second = 0
                                
                                let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
                                exactTriggerComponents.year = todayComponents.year
                                exactTriggerComponents.month = todayComponents.month
                                exactTriggerComponents.day = todayComponents.day
                                
                                if let exactTriggerTime = calendar.date(from: exactTriggerComponents) {
                                    let secondsUntilTrigger = exactTriggerTime.timeIntervalSince(now)
                                    
                                    if secondsUntilTrigger > 0 {
                                        print("      🚀 Triggering immediate notification in \(Int(secondsUntilTrigger))s")
                                        
                                        let immediateContent = UNMutableNotificationContent()
                                        immediateContent.title = content.title
                                        immediateContent.body = content.body
                                        immediateContent.categoryIdentifier = content.categoryIdentifier
                                        immediateContent.sound = content.sound
                                        
                                        // Fire at exact trigger time
                                        let immediateTrigger = UNTimeIntervalNotificationTrigger(
                                            timeInterval: secondsUntilTrigger,
                                            repeats: false
                                        )
                                        
                                        let immediateRequest = UNNotificationRequest(
                                            identifier: "immediate_work_end_\(weekday.rawValue)_\(Date().timeIntervalSince1970)",
                                            content: immediateContent,
                                            trigger: immediateTrigger
                                        )
                                        
                                        self.notificationCenter.add(immediateRequest) { immediateError in
                                            if let immediateError = immediateError {
                                                print("      ❌ Failed to schedule immediate notification: \(immediateError.localizedDescription)")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Debug: List all pending notifications after scheduling
        notificationCenter.getPendingNotificationRequests { requests in
            print("📋 [Notification] Total pending notifications: \(requests.count)")
            for request in requests.sorted(by: { $0.identifier < $1.identifier }) {
                if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                   let nextTriggerDate = trigger.nextTriggerDate() {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    print("   📌 \(request.identifier): \(formatter.string(from: nextTriggerDate))")
                } else {
                    print("   📌 \(request.identifier): (no calendar trigger)")
                }
            }
        }
    }
    
    /// Cancel all daily work notifications
    func cancelDailyWorkNotifications() {
        var identifiers: [String] = []
        for weekday in Weekday.allCases {
            identifiers.append("daily_work_start_\(weekday.rawValue)")
            identifiers.append("daily_work_end_\(weekday.rawValue)")
        }
        print("🗑️ [Notification] Cancelling \(identifiers.count) daily work notifications: \(identifiers.joined(separator: ", "))")
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    /// Reset notification sent flags (call when schedule changes)
    func resetNotificationFlags() {
        print("🔄 [Notification] Resetting notification sent flags")
        scheduleUpdateNotificationSent = nil
        // Note: Don't reset workStart/workEnd flags as they should only fire once per day
    }
    
    /// Send immediate notification when work schedule is updated
    func sendScheduleUpdateNotification(endTime: Date, reminderMinutes: Int) {
        guard permissionGranted else {
            print("⚠️ [Notification] Cannot send schedule update notification - permission not granted")
            return
        }
        
        // Check if we already sent a schedule update notification recently (within 5 seconds)
        let now = Date()
        if let lastSent = scheduleUpdateNotificationSent,
           now.timeIntervalSince(lastSent) < 5 {
            return
        }
        
        // Mark as sent
        scheduleUpdateNotificationSent = now
        
        // Cancel any previous schedule update notifications to avoid duplicates
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let oldScheduleUpdates = requests.filter { $0.identifier.hasPrefix("schedule_update_") }
            if !oldScheduleUpdates.isEmpty {
                let identifiers = oldScheduleUpdates.map { $0.identifier }
                self?.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
            }
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let calendar = Calendar.current
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        let totalMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0) - reminderMinutes
        
        var reminderComponents = DateComponents()
        reminderComponents.hour = max(0, totalMinutes / 60)
        reminderComponents.minute = max(0, totalMinutes % 60)
        
        let reminderTime = calendar.date(from: reminderComponents) ?? endTime
        
        let content = UNMutableNotificationContent()
        content.title = "✅ Work Schedule Updated"
        content.body = "Work end reminder set for \(formatter.string(from: reminderTime)) (\(reminderMinutes) min before \(formatter.string(from: endTime)))"
        content.sound = preferences.soundEnabled ? UNNotificationSound.default : nil
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "schedule_update_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ [Notification] Failed to send schedule update notification: \(error.localizedDescription)")
            } else {
                print("✅ [Notification] Sent schedule update confirmation notification")
            }
        }
    }

    
    /// Show monthly goal completion notification
    func showMonthlyGoalCompletedNotification(goalTitle: String, targetAmount: Double) {
        guard preferences.monthlyGoalEnabled && permissionGranted else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🎉 Monthly Goal Achieved!"
        content.body = goalTitle.isEmpty 
            ? "Congratulations! You have completed this month's income goal of ¥\(String(format: "%.0f", targetAmount))!"
            : "Congratulations! You've earned enough for \(goalTitle)! (¥\(String(format: "%.0f", targetAmount)))"
        content.sound = UNNotificationSound.default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "monthly_goal_completed_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
            }
        }
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
        let oldOvertimeValue = self.preferences.overtimeWarningEnabled
        // Explicitly notify observers before changing
        objectWillChange.send()
        self.preferences = preferences
        savePreferences()
        // Only log when overtime setting changes
        if oldOvertimeValue != preferences.overtimeWarningEnabled {
        }
        
        // Reschedule notifications if needed
        if !preferences.workEndEnabled {
            cancelNotificationsOfType(.workEnd)
        }
        
        if !preferences.overtimeWarningEnabled {
            cancelNotificationsOfType(.overtime)
        }
        
        if !preferences.rewardAchievementEnabled {
            cancelNotificationsOfType(.rewardAchieved)
        }
    }
    
    private func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: "notificationPreferences") {
            do {
                self.preferences = try JSONDecoder().decode(NotificationPreferences.self, from: data)
            } catch {
            }
        }
    }
    
    private func savePreferences() {
        do {
            let data = try JSONEncoder().encode(preferences)
            UserDefaults.standard.set(data, forKey: "notificationPreferences")
        } catch {
        }
    }
    
    // MARK: - Setup
    private func setupNotificationCenter() {
        notificationCenter.delegate = self
        
        // Update pending notifications list
        updatePendingNotifications()
        
        // Set up periodic updates
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.updatePendingNotifications()
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
        // Show notifications even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let actionIdentifier = response.actionIdentifier
        let notificationIdentifier = response.notification.request.identifier
        
        switch actionIdentifier {
        case "extend_work":
            handleExtendWork()
        case "end_work":
            handleEndWork()
        case "continue_overtime":
            handleContinueOvertime()
        case "end_overtime":
            handleEndOvertime()
        case "view_reward":
            handleViewReward(notificationIdentifier: notificationIdentifier)
        case UNNotificationDefaultActionIdentifier:
            handleDefaultAction(notificationIdentifier: notificationIdentifier)
        default:
            break
        }
        
        completionHandler()
    }
    
    // MARK: - Action Handlers
    private func handleExtendWork() {
        NotificationCenter.default.post(name: NSNotification.Name("ExtendWorkTime"), object: nil)
    }
    
    private func handleEndWork() {
        NotificationCenter.default.post(name: NSNotification.Name("EndWorkTime"), object: nil)
    }
    
    private func handleContinueOvertime() {
        NotificationCenter.default.post(name: NSNotification.Name("ContinueOvertime"), object: nil)
    }
    
    private func handleEndOvertime() {
        NotificationCenter.default.post(name: NSNotification.Name("EndOvertime"), object: nil)
    }
    
    private func handleViewReward(notificationIdentifier: String) {
        let rewardId = String(notificationIdentifier.suffix(notificationIdentifier.count - "reward_achieved_".count))
        NotificationCenter.default.post(
            name: NSNotification.Name("ViewReward"),
            object: nil,
            userInfo: ["rewardId": rewardId]
        )
    }
    
    private func handleDefaultAction(notificationIdentifier: String) {
        // Open main window
        NotificationCenter.default.post(name: NSNotification.Name("OpenMainWindow"), object: nil)
    }
}

// MARK: - Smart Notification Scheduler
// MARK: - Smart Notification Scheduler
// Simplified: Only handles work start/end notifications via scheduleDailyWorkNotifications()
// Removed: Income milestone notifications (too frequent/annoying)
// Removed: Work status change auto-notifications (handled by scheduled notifications instead)
class SmartNotificationScheduler: ObservableObject {
    private let notificationService: NotificationService
    private let incomeCalculationService: IncomeCalculationService
    
    init(notificationService: NotificationService, incomeCalculationService: IncomeCalculationService) {
        self.notificationService = notificationService
        self.incomeCalculationService = incomeCalculationService
        // No auto-observers needed - notifications are scheduled when work schedule is saved
    }
}