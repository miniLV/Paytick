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
            return "下班时间到了！"
        case .overtime:
            return "加班提醒"
        case .rewardAchieved:
            return "恭喜！奖励达成"
        case .dailyIncome:
            return "今日收入更新"
        case .lunchBreak:
            return "午休时间"
        case .workStart:
            return "工作开始"
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
                UNNotificationAction(identifier: "extend_work", title: "继续工作", options: []),
                UNNotificationAction(identifier: "end_work", title: "结束工作", options: [.destructive])
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let overtimeCategory = UNNotificationCategory(
            identifier: NotificationType.overtime.rawValue,
            actions: [
                UNNotificationAction(identifier: "continue_overtime", title: "继续加班", options: []),
                UNNotificationAction(identifier: "end_overtime", title: "停止加班", options: [.destructive])
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let rewardCategory = UNNotificationCategory(
            identifier: NotificationType.rewardAchieved.rawValue,
            actions: [
                UNNotificationAction(identifier: "view_reward", title: "查看奖励", options: [.foreground])
            ],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([workEndCategory, overtimeCategory, rewardCategory])
    }
    
    // MARK: - Fun Work Notification Messages
    private let workStartMessages = [
        "☕️ 新的一天开始啦！今天也是努力搬砖的一天~",
        "🚀 打工人打工魂！今天要赚多少钱呢？",
        "💪 早安，打工人！今天的钱包等着你去填满！",
        "🎯 开始计时！每一分钟都在变现~",
        "⏰ 上班啦！又是元气满满的一天！",
        "🔥 工作时间到！让金币飞起来~",
        "💰 滴滴滴～收入计时器已启动！",
        "🌟 今天又是为梦想充值的一天！"
    ]
    
    private let workEndMessages = [
        "🎉 下班啦！今天辛苦了，好好休息~",
        "🌙 打卡下班！今天的你超棒的！",
        "🍻 下班时间到！该享受生活了~",
        "🏠 收工！快回家躺平吧~",
        "✨ 一天的努力结束了，给自己点赞！",
        "🎊 叮！今日份的搬砖任务已完成~",
        "🌈 下班啦！明天继续加油！",
        "🍜 辛苦啦！记得好好吃晚饭~"
    ]
    
    // MARK: - Notification Scheduling
    
    /// Schedule work start reminder notification
    func scheduleWorkStartReminder(startTime: Date) {
        guard preferences.workEndEnabled && permissionGranted else { return }
        
        // Schedule for 5 minutes before work starts
        let reminderTime = Calendar.current.date(
            byAdding: .minute,
            value: -5,
            to: startTime
        ) ?? startTime
        
        guard reminderTime > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🌅 准备上班"
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
        content.body = workEndMessages.randomElement() ?? "还有 \(preferences.workEndReminderMinutes) 分钟就到下班时间了。今天辛苦了！"
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
        content.body = "您已经加班 \(Int(overtimeMinutes)) 分钟了。注意休息！"
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
        content.body = "恭喜！您已完成「\(reward.title)」奖励！"
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
            content.body = "今日收入：\(formatter.formatAmount(income))"
        } else {
            content.body = "今日收入：¥\(String(format: "%.2f", income))"
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
        content.body = "午休时间到了，记得休息一下！"
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
        cancelDailyWorkNotifications()
        
        guard permissionGranted else {
            return
        }
        
        let calendar = Calendar.current
        
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
                
                let content = UNMutableNotificationContent()
                content.title = "🌅 准备上班"
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
            for weekday in workdays {
                let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
                var triggerComponents = DateComponents()
                triggerComponents.weekday = weekday.calendarWeekday
                
                // Calculate reminder time (N minutes before end based on user setting)
                let totalMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0) - preferences.workEndReminderMinutes
                triggerComponents.hour = max(0, totalMinutes / 60)
                triggerComponents.minute = max(0, totalMinutes % 60)
                
                let content = UNMutableNotificationContent()
                content.title = NotificationType.workEnd.title
                content.body = preferences.workEndReminderMinutes > 0
                    ? "还有 \(preferences.workEndReminderMinutes) 分钟就到下班时间了！\(workEndMessages.randomElement() ?? "")"
                    : workEndMessages.randomElement() ?? "下班时间到了！今天辛苦了！"
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
                    } else {
                    }
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
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    /// Show monthly goal completion notification
    func showMonthlyGoalCompletedNotification(goalTitle: String, targetAmount: Double) {
        guard preferences.monthlyGoalEnabled && permissionGranted else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🎉 月度目标达成！"
        content.body = goalTitle.isEmpty 
            ? "恭喜！你已完成本月 ¥\(String(format: "%.0f", targetAmount)) 的收入目标！"
            : "恭喜！你已赚够 \(goalTitle) 的钱啦！(¥\(String(format: "%.0f", targetAmount)))"
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