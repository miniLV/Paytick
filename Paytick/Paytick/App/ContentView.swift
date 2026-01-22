//
//  ContentView.swift
//  Paytick
//
//  Created by miniLV on 2024/9/25.
//

import SwiftUI
import Foundation
import Combine

// MARK: - StatusBarController
class StatusBarController: ObservableObject {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    let incomeViewModel: IncomeViewModel
    let privacySettings: PrivacySettings
    let iconSettings: PrivacyIconSettings
    private var enhancedViewModel: EnhancedIncomeViewModel
    private var popover: NSPopover
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private let shortcutManager = KeyboardShortcutManager.shared
    
    @Published var showPopover = false {
        didSet {
            if showPopover {
                showPopoverWindow()
            } else {
                hidePopoverWindow()
            }
        }
    }
    
    // Fixed width for status bar item to prevent shifting when content changes
    private static let statusBarWidth: CGFloat = 90
    
    // Smooth animation properties for menu bar amount
    private var displayedIncome: Double = 0
    private var targetIncome: Double = 0
    private var animationTimer: Timer?
    private let animationSteps = 10
    private let animationInterval: TimeInterval = 0.05
    
    init(incomeViewModel: IncomeViewModel, privacySettings: PrivacySettings, iconSettings: PrivacyIconSettings) {
        self.statusBar = NSStatusBar.system
        self.statusItem = statusBar.statusItem(withLength: Self.statusBarWidth)
        self.incomeViewModel = incomeViewModel
        self.privacySettings = privacySettings
        self.iconSettings = iconSettings
        
        // Create EnhancedIncomeViewModel and retain reference
        self.enhancedViewModel = EnhancedIncomeViewModel(originalViewModel: incomeViewModel)
        
        // Initialize popover with Cyberpunk terminal-style UI
        self.popover = NSPopover()
        let popoverView = CyberpunkDashboardView(
            enhancedViewModel: enhancedViewModel,
            privacySettings: privacySettings,
            iconSettings: iconSettings
        )
        let hostingController = NSHostingController(rootView: popoverView)
        // Match exact content size to eliminate gray border
        hostingController.preferredContentSize = NSSize(width: 400, height: 700)
        self.popover.contentViewController = hostingController
        self.popover.contentSize = NSSize(width: 400, height: 700)
        self.popover.behavior = .transient
        
        if let statusBarButton = statusItem.button {
            statusBarButton.image = NSImage(systemSymbolName: "bitcoinsign.circle.fill", accessibilityDescription: "Paytick")
            statusBarButton.image?.isTemplate = true
            statusBarButton.action = #selector(togglePopover)
            statusBarButton.target = self
            statusBarButton.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Listen for real-time income changes
        enhancedViewModel.$currentIncome
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusBarDisplay()
            }
            .store(in: &cancellables)
            
        // Listen for privacy mode changes
        privacySettings.$isPrivacyModeEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusBarDisplay()
            }
            .store(in: &cancellables)
        
        // Listen for privacy display mode changes
        privacySettings.$displayMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusBarDisplay()
            }
            .store(in: &cancellables)
        
        // Listen for emoji preset changes
        privacySettings.$emojiPreset
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusBarDisplay()
            }
            .store(in: &cancellables)
        
        // Initial display update
        updateStatusBarDisplay()
        
        // Listen for clicks outside to close popover
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.showPopover else { return }
            self.showPopover = false
        }
        
        // Setup keyboard shortcuts
        setupKeyboardShortcuts()
    }
    
    private func setupKeyboardShortcuts() {
        // Toggle privacy mode with keyboard shortcut (⌃⌥P by default)
        shortcutManager.onTogglePrivacy = { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.privacySettings.isPrivacyModeEnabled.toggle()
            }
        }
    }
    
    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    @objc func togglePopover(_ sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent {
            if event.type == .rightMouseUp {
                let menu = NSMenu()
                menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
                statusItem.menu = menu
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: statusItem.button?.bounds.height ?? 0), in: statusItem.button)
                statusItem.menu = nil
            } else {
                if popover.isShown {
                    hidePopoverWindow()
                    showPopover = false
                } else {
                    showPopoverWindow()
                    showPopover = true
                }
            }
        }
    }
    
    private func showPopoverWindow() {
        guard let button = statusItem.button else { return }
        
        // Ensure the button's window is available and on screen
        guard let window = button.window, window.isOnActiveSpace else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.showPopoverWindow()
            }
            return
        }
        
        // Pre-calculate the button's screen position to validate it's reasonable
        let buttonFrame = button.bounds
        let buttonScreenFrame = window.convertToScreen(button.convert(buttonFrame, to: nil))
        
        // Validate screen position - ensure button is actually visible on a screen
        let screens = NSScreen.screens
        let isButtonOnValidScreen = screens.contains { screen in
            screen.frame.intersects(buttonScreenFrame)
        }
        
        guard isButtonOnValidScreen else {
            // Button is not on any visible screen, wait and retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.showPopoverWindow()
            }
            return
        }
        
        // Force the content view to layout before showing
        popover.contentViewController?.view.layoutSubtreeIfNeeded()
        
        // Show popover using a fresh reference to avoid stale coordinates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Get fresh button reference
            guard let freshButton = self.statusItem.button else { return }
            guard let buttonWindow = freshButton.window else { return }
            
            // Use the standardized bounds for consistent positioning
            let bounds = CGRect(x: 0, y: 0, width: freshButton.bounds.width, height: freshButton.bounds.height)
            
            // Log position for debugging off-screen popover issue
            let screenPos = buttonWindow.convertToScreen(freshButton.convert(freshButton.bounds, to: nil))
            
            self.popover.show(relativeTo: bounds, of: freshButton, preferredEdge: .minY)
            
            // Log final popover position
            if let popoverWindow = self.popover.contentViewController?.view.window {
            }
        }
    }
    
    private func hidePopoverWindow() {
        // Notify that popover is closing so Settings sheet can close too
        NotificationCenter.default.post(name: NSNotification.Name("PopoverWillClose"), object: nil)
        self.popover.performClose(nil)
    }
    
    
    private func updateStatusBarDisplay() {
        guard let statusBarButton = statusItem.button else { return }
        
        // Get current income from EnhancedIncomeViewModel
        let newIncome = enhancedViewModel.currentIncome
        
        // Check if we need smooth animation (only for non-privacy numerical display)
        if !privacySettings.isPrivacyModeEnabled && abs(newIncome - displayedIncome) > 0.01 {
            // Start smooth animation to new value
            animateToIncome(newIncome, statusBarButton: statusBarButton)
        } else {
            // Direct update for privacy mode or no change
            updateStatusBarText(with: newIncome, statusBarButton: statusBarButton)
        }
    }
    
    private func animateToIncome(_ target: Double, statusBarButton: NSStatusBarButton) {
        // Cancel any existing animation
        animationTimer?.invalidate()
        
        targetIncome = target
        let startIncome = displayedIncome
        let difference = target - startIncome
        
        // Skip animation for very small changes or initial state
        if abs(difference) < 1 || displayedIncome == 0 {
            displayedIncome = target
            updateStatusBarText(with: target, statusBarButton: statusBarButton)
            return
        }
        
        var currentStep = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: animationInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            let progress = Double(currentStep) / Double(self.animationSteps)
            
            // Use ease-out easing for smoother end
            let easedProgress = 1 - pow(1 - progress, 3)
            self.displayedIncome = startIncome + difference * easedProgress
            
            self.updateStatusBarText(with: self.displayedIncome, statusBarButton: statusBarButton)
            
            if currentStep >= self.animationSteps {
                timer.invalidate()
                self.animationTimer = nil
                self.displayedIncome = target
                self.updateStatusBarText(with: target, statusBarButton: statusBarButton)
            }
        }
    }
    
    private func updateStatusBarText(with income: Double, statusBarButton: NSStatusBarButton) {
        // Build display text based on privacy mode and display mode
        let displayText: String
        if privacySettings.isPrivacyModeEnabled {
            switch privacySettings.displayMode {
            case .emoji:
                // Emoji mode: show emoji level
                displayText = privacySettings.getEmojiForAmount(income)
            case .dots, .blur:
                // Dots or Blur mode: show masked amount (menu bar can't blur, use dots)
                displayText = formatMaskedAmount(income)
            }
        } else {
            // Normal mode: show real-time income
            displayText = formatStatusBarAmount(income)
        }
        
        // Update button title (text next to icon)
        statusBarButton.title = " \(displayText)"
        statusBarButton.imagePosition = .imageLeading
        
        // Style the text with monospaced digits for stable width
        statusBarButton.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    }
    
    private func formatStatusBarAmount(_ amount: Double) -> String {
        if amount >= 10000 {
            return String(format: "¥%.1fk", amount / 1000)
        } else if amount >= 1000 {
            return String(format: "¥%.0f", amount)
        } else {
            return String(format: "¥%.2f", amount)
        }
    }
    
    private func formatMaskedAmount(_ amount: Double) -> String {
        // Show fixed dots pattern to hide amount magnitude
        // Don't reveal amount range - always show same pattern
        return "¥••••.••"
    }
}

// MARK: - IncomeViewModel
class IncomeViewModel: ObservableObject {
    // MARK: Published properties
    @Published var monthlySalary: Double = 0
    @Published var workdaysPerMonth: Int = 0
    @Published var startTime: Date = Date()
    @Published var endTime: Date = Date()
    @Published var lunchStartTime: Date = Date()
    @Published var lunchEndTime: Date = Date()
    @Published var todayIncome: Double = 0
    @Published var isConfigured: Bool = false
    
    // MARK: Private properties
    private var minuteRate: Double = 0
    private var timer: Timer?
    private let calendar = Calendar.current

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    // MARK: UserDefaults keys
    private let monthlySalaryKey = "monthlySalary"
    private let workdaysPerMonthKey = "workdaysPerMonth"
    private let startTimeKey = "startTime"
    private let endTimeKey = "endTime"
    private let lunchStartTimeKey = "lunchStartTime"
    private let lunchEndTimeKey = "lunchEndTime"
    private let isConfiguredKey = "isConfigured"
    
    init() {
        loadSavedData()
        startIncomeCalculation()
    }
    
    // MARK: Public methods
     /// Calculates the minute rate based on monthly salary and work minutes
     func calculateMinuteRate() {
         let workMinutesPerDay = calculateWorkMinutes()
         let workMinutesPerMonth = Double(workdaysPerMonth) * workMinutesPerDay
         minuteRate = monthlySalary / workMinutesPerMonth
         
         isConfigured = true
         updateTodayIncome() // Immediately update today's income
         startIncomeCalculation() // Start the timer
     }
    
    /// Saves the current data to UserDefaults
    func saveData() {
        UserDefaults.standard.set(monthlySalary, forKey: monthlySalaryKey)
        UserDefaults.standard.set(workdaysPerMonth, forKey: workdaysPerMonthKey)
        UserDefaults.standard.set(startTime, forKey: startTimeKey)
        UserDefaults.standard.set(endTime, forKey: endTimeKey)
        UserDefaults.standard.set(lunchStartTime, forKey: lunchStartTimeKey)
        UserDefaults.standard.set(lunchEndTime, forKey: lunchEndTimeKey)
        UserDefaults.standard.set(isConfigured, forKey: isConfiguredKey)
    }
    
    /// Loads saved data from UserDefaults
    func loadSavedData() {
        monthlySalary = UserDefaults.standard.double(forKey: monthlySalaryKey)
        workdaysPerMonth = UserDefaults.standard.integer(forKey: workdaysPerMonthKey)
        startTime = UserDefaults.standard.object(forKey: startTimeKey) as? Date ?? Date()
        endTime = UserDefaults.standard.object(forKey: endTimeKey) as? Date ?? Date()
        lunchStartTime = UserDefaults.standard.object(forKey: lunchStartTimeKey) as? Date ?? Date()
        lunchEndTime = UserDefaults.standard.object(forKey: lunchEndTimeKey) as? Date ?? Date()
        isConfigured = UserDefaults.standard.bool(forKey: isConfiguredKey)
        
        if isConfigured {
            calculateMinuteRate()
        }
    }
    
    // MARK: Private methods
        /// Calculates total work minutes per day, excluding lunch break
        private func calculateWorkMinutes() -> Double {
            let totalMinutes = endTime.timeIntervalSince(startTime) / 60
            let lunchMinutes = lunchEndTime.timeIntervalSince(lunchStartTime) / 60
            let result = totalMinutes - lunchMinutes
            return result
        }
        
        /// Starts the timer to update income calculation every second
        private func startIncomeCalculation() {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
                self?.updateTodayIncome()
            }
        }
        
        /// Updates the income earned today based on current time and work schedule
    func updateTodayIncome() {
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        
        // Only calculate income on workdays (Monday to Friday)
        guard (2...6).contains(weekday) else {
            DispatchQueue.main.async {
                self.todayIncome = 0
            }
            return
        }
        
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        let today = calendar.date(from: components)!
        
        let todayStart = calendar.date(bySettingHour: calendar.component(.hour, from: startTime),
                                       minute: calendar.component(.minute, from: startTime),
                                       second: 0, of: today)!
        
        let todayEnd = calendar.date(bySettingHour: calendar.component(.hour, from: endTime),
                                     minute: calendar.component(.minute, from: endTime),
                                     second: 0, of: today)!
        
        let todayLunchStart = calendar.date(bySettingHour: calendar.component(.hour, from: lunchStartTime),
                                            minute: calendar.component(.minute, from: lunchStartTime),
                                            second: 0, of: today)!
        
        let todayLunchEnd = calendar.date(bySettingHour: calendar.component(.hour, from: lunchEndTime),
                                          minute: calendar.component(.minute, from: lunchEndTime),
                                          second: 0, of: today)!
        
        var workedMinutes = 0.0
        
        if now > todayStart && now <= todayEnd {
            if now <= todayLunchStart {
                workedMinutes = now.timeIntervalSince(todayStart) / 60
            } else if now > todayLunchEnd {
                workedMinutes = (now.timeIntervalSince(todayStart) - todayLunchEnd.timeIntervalSince(todayLunchStart)) / 60
            } else {
                workedMinutes = todayLunchStart.timeIntervalSince(todayStart) / 60
            }
        } else if now > todayEnd {
            workedMinutes = (todayEnd.timeIntervalSince(todayStart) - todayLunchEnd.timeIntervalSince(todayLunchStart)) / 60
        }
        
        let newIncome = workedMinutes * minuteRate
        
        DispatchQueue.main.async {
            self.todayIncome = newIncome
        }
    }
}

