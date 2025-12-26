import Foundation
import Combine
import AppKit
import SwiftUI

// MARK: - Timer Manager Protocol
protocol TimerManagerProtocol {
    var isRunning: Bool { get }
    var interval: TimeInterval { get set }
    var isBackgroundEnabled: Bool { get set }
    
    func start()
    func stop()
    func pause()
    func resume()
    func setInterval(_ interval: TimeInterval)
    func setCallback(_ callback: @escaping () -> Void)
}

// MARK: - Timer Manager Implementation
class TimerManager: TimerManagerProtocol, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    @Published var interval: TimeInterval = 10.0 {
        didSet {
            if isRunning {
                restart()
            }
        }
    }
    @Published var isBackgroundEnabled: Bool = true
    @Published var lastUpdateTime: Date = Date()
    @Published var totalRunTime: TimeInterval = 0
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var pausedTime: Date?
    private var startTime: Date?
    private var callback: (() -> Void)?
    private var cancellables = Set<AnyCancellable>()
    
    // Background and foreground handling for macOS
    private var wasRunningBeforeBackground = false
    
    // Performance monitoring
    private var executionTimes: [TimeInterval] = []
    private let maxExecutionTimeHistory = 100
    
    // MARK: - Initialization
    init(interval: TimeInterval = 10.0, isBackgroundEnabled: Bool = true) {
        self.interval = interval
        self.isBackgroundEnabled = isBackgroundEnabled
        setupNotificationObservers()
    }
    
    deinit {
        stop()
        removeNotificationObservers()
    }
    
    // MARK: - Public Methods
    func start() {
        guard !isRunning else { return }
        
        createTimer()
        isRunning = true
        isPaused = false
        startTime = Date()
        lastUpdateTime = Date()
    }
    
    func stop() {
        invalidateTimer()
        isRunning = false
        isPaused = false
        
        if let start = startTime {
            totalRunTime += Date().timeIntervalSince(start)
        }
        startTime = nil
        pausedTime = nil
    }
    
    func pause() {
        guard isRunning && !isPaused else { return }
        
        invalidateTimer()
        isPaused = true
        pausedTime = Date()
    }
    
    func resume() {
        guard isRunning && isPaused else { return }
        
        createTimer()
        isPaused = false
        
        // Adjust start time to account for paused duration
        if let pausedAt = pausedTime, let start = startTime {
            let pausedDuration = Date().timeIntervalSince(pausedAt)
            startTime = start.addingTimeInterval(pausedDuration)
        }
        pausedTime = nil
    }
    
    func setInterval(_ newInterval: TimeInterval) {
        interval = max(1.0, newInterval) // Minimum 1 second
    }
    
    func setCallback(_ callback: @escaping () -> Void) {
        self.callback = callback
    }
    
    func restart() {
        stop()
        start()
    }
    
    // MARK: - Performance Monitoring
    func getAverageExecutionTime() -> TimeInterval {
        guard !executionTimes.isEmpty else { return 0 }
        return executionTimes.reduce(0, +) / Double(executionTimes.count)
    }
    
    func getMaxExecutionTime() -> TimeInterval {
        return executionTimes.max() ?? 0
    }
    
    func clearExecutionHistory() {
        executionTimes.removeAll()
    }
    
    // MARK: - Private Methods
    private func createTimer() {
        invalidateTimer()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.executeCallback()
        }
        
        // Add to main run loop for better responsiveness
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func executeCallback() {
        let executionStart = Date()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.lastUpdateTime = Date()
            self.callback?()
            
            // Track execution time for performance monitoring
            let executionTime = Date().timeIntervalSince(executionStart)
            self.recordExecutionTime(executionTime)
        }
    }
    
    private func recordExecutionTime(_ time: TimeInterval) {
        executionTimes.append(time)
        if executionTimes.count > maxExecutionTimeHistory {
            executionTimes.removeFirst()
        }
    }
    
    // MARK: - Background Handling
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterBackground),
            name: NSApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterForeground),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func appWillEnterBackground() {
        guard isBackgroundEnabled else {
            if isRunning && !isPaused {
                pause()
                wasRunningBeforeBackground = true
            }
            return
        }
    }
    
    @objc private func appDidEnterForeground() {
        if !isBackgroundEnabled && wasRunningBeforeBackground {
            resume()
            wasRunningBeforeBackground = false
        }
    }
}

// MARK: - Advanced Timer Manager for Multiple Timers
class MultiTimerManager: ObservableObject {
    
    @Published var timers: [String: TimerManager] = [:]
    @Published var globalConfig: TimerConfiguration = TimerConfiguration()
    
    private var cancellables = Set<AnyCancellable>()
    
    struct TimerConfiguration {
        var defaultInterval: TimeInterval = 10.0
        var maxConcurrentTimers: Int = 10
        var isGlobalBackgroundEnabled: Bool = true
        var performanceMonitoringEnabled: Bool = true
    }
    
    init() {
        setupGlobalObservers()
    }
    
    func createTimer(id: String, interval: TimeInterval? = nil, callback: @escaping () -> Void) -> TimerManager? {
        guard timers.count < globalConfig.maxConcurrentTimers else {
            return nil
        }
        
        let timerInterval = interval ?? globalConfig.defaultInterval
        let timer = TimerManager(interval: timerInterval, isBackgroundEnabled: globalConfig.isGlobalBackgroundEnabled)
        timer.setCallback(callback)
        
        timers[id] = timer
        
        // Subscribe to timer updates for performance monitoring
        if globalConfig.performanceMonitoringEnabled {
            timer.$lastUpdateTime
                .sink { [weak self] _ in
                    self?.monitorTimerPerformance(id: id)
                }
                .store(in: &cancellables)
        }
        
        return timer
    }
    
    func startTimer(id: String) {
        timers[id]?.start()
    }
    
    func stopTimer(id: String) {
        timers[id]?.stop()
    }
    
    func pauseTimer(id: String) {
        timers[id]?.pause()
    }
    
    func resumeTimer(id: String) {
        timers[id]?.resume()
    }
    
    func removeTimer(id: String) {
        timers[id]?.stop()
        timers.removeValue(forKey: id)
    }
    
    func startAllTimers() {
        timers.values.forEach { $0.start() }
    }
    
    func stopAllTimers() {
        timers.values.forEach { $0.stop() }
    }
    
    func pauseAllTimers() {
        timers.values.forEach { $0.pause() }
    }
    
    func resumeAllTimers() {
        timers.values.forEach { $0.resume() }
    }
    
    private func setupGlobalObservers() {
        // Global app state monitoring for macOS
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeOcclusionStateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppStateChange()
        }
    }
    
    private func handleAppStateChange() {
        // Pause timers that haven't been updated recently
        let cutoffTime = Date().addingTimeInterval(-60) // 1 minute ago
        
        for (_, timer) in timers {
            if timer.lastUpdateTime < cutoffTime && timer.isRunning {
                timer.pause()
            }
        }
    }
    
    private func monitorTimerPerformance(id: String) {
        // Performance monitoring is done silently
        // Can add alerts/notifications here if needed
    }
    
    deinit {
        stopAllTimers()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Timer Manager Extensions
extension TimerManager {
    
    // Convenience methods for common intervals
    static func createRealTimeTimer(callback: @escaping () -> Void) -> TimerManager {
        let timer = TimerManager(interval: 10.0) // 10 seconds for real-time income
        timer.setCallback(callback)
        return timer
    }
    
    static func createNotificationTimer(callback: @escaping () -> Void) -> TimerManager {
        let timer = TimerManager(interval: 60.0) // 1 minute for notifications
        timer.setCallback(callback)
        return timer
    }
    
    static func createStatisticsTimer(callback: @escaping () -> Void) -> TimerManager {
        let timer = TimerManager(interval: 300.0) // 5 minutes for statistics
        timer.setCallback(callback)
        return timer
    }
    
    // Adaptive interval based on app state
    func setAdaptiveInterval(foregroundInterval: TimeInterval, backgroundInterval: TimeInterval) {
        let isInBackground = !NSApp.isActive
        setInterval(isInBackground ? backgroundInterval : foregroundInterval)
    }
}

// MARK: - Timer Health Monitor
class TimerHealthMonitor: ObservableObject {
    @Published var healthStatus: HealthStatus = .good
    @Published var recommendations: [String] = []
    
    enum HealthStatus {
        case good
        case warning
        case critical
        
        var color: Color {
            switch self {
            case .good: return .green
            case .warning: return .orange
            case .critical: return .red
            }
        }
    }
    
    func analyzeTimer(_ timer: TimerManager) {
        let avgExecution = timer.getAverageExecutionTime()
        let maxExecution = timer.getMaxExecutionTime()
        let interval = timer.interval
        
        var newRecommendations: [String] = []
        var status: HealthStatus = .good
        
        // Analyze execution time vs interval
        if avgExecution > interval * 0.1 {
            status = .warning
            newRecommendations.append("Consider optimizing callback execution time")
        }
        
        if maxExecution > interval * 0.3 {
            status = .critical
            newRecommendations.append("Critical: Callback execution time too long")
        }
        
        // Check for consistent execution
        if timer.totalRunTime > 300 && avgExecution > interval * 0.05 {
            newRecommendations.append("Consider increasing timer interval")
        }
        
        DispatchQueue.main.async {
            self.healthStatus = status
            self.recommendations = newRecommendations
        }
    }
}