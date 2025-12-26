//
//  CyberpunkDashboardView.swift
//  Paytick
//
//  Cyberpunk Terminal-style Dashboard - 100% Figma Replication
//

import SwiftUI
import Combine

// MARK: - Design System Constants
struct CyberpunkTheme {
    // Terminal Colors
    static let panelBackground = LinearGradient(
        colors: [
            Color(red: 0.1, green: 0.1, blue: 0.1),
            Color(red: 0.165, green: 0.165, blue: 0.165),
            Color(red: 0.122, green: 0.122, blue: 0.122)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let terminalSectionBackground = LinearGradient(
        colors: [
            Color(red: 0, green: 0.078, blue: 0).opacity(0.4),
            Color(red: 0, green: 0.039, blue: 0).opacity(0.6)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Accent Colors
    static let greenPrimary = Color(red: 0.133, green: 0.773, blue: 0.369) // #22C55E
    static let greenGlow = Color(red: 0, green: 1, blue: 0)
    static let cyanPrimary = Color(red: 0.133, green: 0.827, blue: 0.933) // #22D3EE
    static let purplePrimary = Color(red: 0.659, green: 0.333, blue: 0.969) // #A855F7
    static let yellowPrimary = Color(red: 0.918, green: 0.702, blue: 0.031) // #EAB308
    static let orangePrimary = Color(red: 0.984, green: 0.573, blue: 0.235) // #FB923C
    static let redPrimary = Color(red: 0.937, green: 0.267, blue: 0.267) // #EF4444
    static let bluePrimary = Color(red: 0.231, green: 0.510, blue: 0.965) // #3B82F6
    static let magentaPrimary = Color(red: 0.925, green: 0.282, blue: 0.600) // #EC4899
    
    // Traffic Light Colors
    static let trafficRed = Color(red: 0.937, green: 0.267, blue: 0.267).opacity(0.8)
    static let trafficYellow = Color(red: 0.918, green: 0.702, blue: 0.031).opacity(0.8)
    static let trafficGreen = Color(red: 0.133, green: 0.773, blue: 0.369).opacity(0.8)
    
    // Typography
    static let monoFont = Font.system(.body, design: .monospaced)
}

// MARK: - Animated Income Display (Smooth scrolling effect)
struct AnimatedIncomeText: View {
    let value: Double
    let fontSize: CGFloat
    let gradient: LinearGradient
    
    @State private var displayedValue: Double = 0
    @State private var animationTimer: Timer?
    
    var body: some View {
        Text(formatCurrency(displayedValue))
            .font(.system(size: fontSize, weight: .black, design: .monospaced))
            .foregroundStyle(gradient)
            .contentTransition(.numericText(value: displayedValue))
            .onChange(of: value) { oldValue, newValue in
                animateValue(from: oldValue, to: newValue)
            }
            .onAppear {
                displayedValue = value
            }
    }
    
    private func animateValue(from: Double, to: Double) {
        animationTimer?.invalidate()
        
        let steps = 15
        let duration = 0.4
        let stepDuration = duration / Double(steps)
        let diff = to - from
        
        var currentStep = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            currentStep += 1
            let progress = Double(currentStep) / Double(steps)
            // Ease-out cubic for smooth deceleration
            let easedProgress = 1 - pow(1 - progress, 3)
            
            withAnimation(.linear(duration: stepDuration)) {
                displayedValue = from + diff * easedProgress
            }
            
            if currentStep >= steps {
                timer.invalidate()
                displayedValue = to
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        return String(format: "¥%.2f", amount)
    }
}

// MARK: - Main Dashboard View
struct CyberpunkDashboardView: View {
    @ObservedObject var enhancedViewModel: EnhancedIncomeViewModel
    @ObservedObject var privacySettings: PrivacySettings
    @ObservedObject var iconSettings: PrivacyIconSettings
    
    @State private var showingSettings = false
    @State private var targetSection: DeepLinkSection? = nil
    @State private var glitchActive = false
    @State private var scanlinePhase: CGFloat = 0
    
    var body: some View {
        ZStack {
            // CRT Scanline Effect Overlay
            CRTScanlineOverlay(phase: scanlinePhase)
                .allowsHitTesting(false)
            
            // Main Content - Compact spacing
            VStack(spacing: 10) {
                // Hero Card - Earnings Display
                HeroEarningsCard(
                    enhancedViewModel: enhancedViewModel,
                    privacySettings: privacySettings,
                    glitchActive: glitchActive
                )
                
                // 2x2 Grid - Goals & Status
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ], spacing: 10) {
                    // Today's Goal
                    TerminalCard(
                        headerIcon: "chevron.left.forwardslash.chevron.right",
                        headerLabel: "QUEST.LOG",
                        headerColor: CyberpunkTheme.cyanPrimary
                    ) {
                        QuestLogContent(
                            showingSettings: $showingSettings,
                            targetSection: $targetSection,
                            enhancedViewModel: enhancedViewModel
                        )
                    }
                    
                    // Dream Item / Monthly Goal
                    TerminalCard(
                        headerIcon: "gift.fill",
                        headerLabel: "LOOT.ITEM",
                        headerColor: CyberpunkTheme.purplePrimary
                    ) {
                        LootItemContent(
                            showingSettings: $showingSettings,
                            targetSection: $targetSection,
                            enhancedViewModel: enhancedViewModel
                        )
                    }
                    
                    // Privacy Mode
                    TerminalCard(
                        headerIcon: "terminal.fill",
                        headerLabel: "PRIVACY.SYS",
                        headerColor: CyberpunkTheme.bluePrimary
                    ) {
                        PrivacySysContent(privacySettings: privacySettings)
                    }
                    
                    // Work Status
                    TerminalCard(
                        headerIcon: "externaldrive.fill",
                        headerLabel: "STATUS.LOG",
                        headerColor: CyberpunkTheme.greenPrimary
                    ) {
                        StatusLogContent(enhancedViewModel: enhancedViewModel)
                    }
                }
                
                // Bottom Info Cards - Compact height
                HStack(spacing: 10) {
                    // Personal Info
                    TerminalCard(
                        headerIcon: "person.fill",
                        headerLabel: "USER.DAT",
                        headerColor: CyberpunkTheme.cyanPrimary,
                        fixedHeight: 90
                    ) {
                        UserDatContent(
                            enhancedViewModel: enhancedViewModel,
                            privacySettings: privacySettings,
                            showingSettings: $showingSettings,
                            targetSection: $targetSection
                        )
                    }
                    
                    // Work Schedule
                    TerminalCard(
                        headerIcon: "calendar",
                        headerLabel: "SCHEDULE.CFG",
                        headerColor: CyberpunkTheme.purplePrimary,
                        fixedHeight: 90
                    ) {
                        ScheduleCfgContent(
                            enhancedViewModel: enhancedViewModel,
                            showingSettings: $showingSettings,
                            targetSection: $targetSection
                        )
                    }
                }
                
                // Footer - Settings & Quit
                TerminalFooter(showingSettings: $showingSettings, targetSection: $targetSection)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 400)
        .background(CyberpunkTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.8), radius: 15, x: 0, y: 10)
        .onAppear {
            startGlitchEffect()
            startScanlineAnimation()
        }
        .sheet(isPresented: $showingSettings) {
            CyberpunkSettingsView(
                enhancedViewModel: enhancedViewModel,
                privacySettings: privacySettings,
                iconSettings: iconSettings,
                initialSection: targetSection
            )
        }
        .onChange(of: showingSettings) { _, isShowing in
            // Reset target section when settings is dismissed
            if !isShowing {
                targetSection = nil
            }
        }
        // Close settings when popover closes
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopoverWillClose"))) { _ in
            showingSettings = false
        }
    }
    
    private func startGlitchEffect() {
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            glitchActive = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                glitchActive = false
            }
        }
    }
    
    private func startScanlineAnimation() {
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            scanlinePhase = 1
        }
    }
}

// MARK: - CRT Scanline Overlay
struct CRTScanlineOverlay: View {
    let phase: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for y in stride(from: 0, to: size.height, by: 4) {
                    let rect = CGRect(x: 0, y: y + 2, width: size.width, height: 2)
                    context.fill(
                        Path(rect),
                        with: .color(CyberpunkTheme.greenGlow.opacity(0.02))
                    )
                }
            }
        }
        .opacity(0.03)
    }
}

// MARK: - Hero Earnings Card (Supports Overtime Warning Mode)
struct HeroEarningsCard: View {
    @ObservedObject var enhancedViewModel: EnhancedIncomeViewModel
    @ObservedObject var privacySettings: PrivacySettings
    @ObservedObject private var notificationService = NotificationService.shared
    let glitchActive: Bool
    
    @State private var blinkPhase = false
    
    // Only show overtime UI if user has enabled overtime warning in settings
    private var shouldShowOvertimeMode: Bool {
        enhancedViewModel.isOvertime && notificationService.preferences.overtimeWarningEnabled
    }
    
    // Colors based on overtime state
    private var accentColor: Color {
        shouldShowOvertimeMode ? CyberpunkTheme.redPrimary : CyberpunkTheme.greenPrimary
    }
    
    private var secondaryAccent: Color {
        shouldShowOvertimeMode ? CyberpunkTheme.orangePrimary : CyberpunkTheme.cyanPrimary
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal Header with Traffic Lights
            HStack {
                HStack(spacing: 8) {
                    if shouldShowOvertimeMode {
                        // Overtime Alert Header
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(CyberpunkTheme.redPrimary)
                            .opacity(blinkPhase ? 1 : 0.6)
                        
                        Text("⚠️ OVERTIME ALERT")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(CyberpunkTheme.redPrimary)
                    } else {
                        // Normal Header
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(CyberpunkTheme.cyanPrimary)
                        
                        Text("Paytick")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(CyberpunkTheme.greenPrimary)
                        
                        Image(systemName: "bitcoinsign.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(CyberpunkTheme.yellowPrimary)
                    }
                }
                
                Spacer()
                
                // Traffic Lights - All red/orange/yellow when overtime
                HStack(spacing: 6) {
                    if shouldShowOvertimeMode {
                        Circle()
                            .fill(CyberpunkTheme.redPrimary)
                            .frame(width: 10, height: 10)
                            .shadow(color: CyberpunkTheme.redPrimary.opacity(0.8), radius: 6)
                            .opacity(blinkPhase ? 1 : 0.6)
                        Circle()
                            .fill(CyberpunkTheme.orangePrimary)
                            .frame(width: 10, height: 10)
                            .shadow(color: CyberpunkTheme.orangePrimary.opacity(0.8), radius: 6)
                            .opacity(blinkPhase ? 0.8 : 0.5)
                        Circle()
                            .fill(CyberpunkTheme.yellowPrimary)
                            .frame(width: 10, height: 10)
                            .shadow(color: CyberpunkTheme.yellowPrimary.opacity(0.8), radius: 6)
                            .opacity(blinkPhase ? 0.6 : 0.4)
                    } else {
                        Circle()
                            .fill(CyberpunkTheme.trafficRed)
                            .frame(width: 10, height: 10)
                            .shadow(color: CyberpunkTheme.redPrimary.opacity(0.6), radius: 4)
                        Circle()
                            .fill(CyberpunkTheme.trafficYellow)
                            .frame(width: 10, height: 10)
                            .shadow(color: CyberpunkTheme.yellowPrimary.opacity(0.6), radius: 4)
                        Circle()
                            .fill(CyberpunkTheme.trafficGreen)
                            .frame(width: 10, height: 10)
                            .shadow(color: CyberpunkTheme.greenPrimary.opacity(0.6), radius: 4)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                shouldShowOvertimeMode
                    ? Color(red: 0.2, green: 0.05, blue: 0.05).opacity(0.6)
                    : Color.black.opacity(0.4)
            )
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(accentColor.opacity(0.3)),
                alignment: .bottom
            )
            
            // Main Content Area
            VStack(spacing: 12) {
                // Status Indicators
                HStack {
                    HStack(spacing: 6) {
                        if shouldShowOvertimeMode {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(CyberpunkTheme.redPrimary.opacity(0.8))
                            Text("OVERTIME_DETECTED")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(CyberpunkTheme.redPrimary.opacity(0.8))
                        } else {
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 10))
                                .foregroundColor(CyberpunkTheme.greenPrimary.opacity(0.6))
                            Text("DAEMON_RUNNING")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(CyberpunkTheme.greenPrimary.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        if shouldShowOvertimeMode {
                            // Show current time when overtime
                            Text(currentTimeString)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(CyberpunkTheme.redPrimary.opacity(0.7))
                        } else {
                            Image(systemName: "centsign.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(CyberpunkTheme.yellowPrimary)
                            Image(systemName: "centsign.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(CyberpunkTheme.yellowPrimary)
                        }
                        Image(systemName: "wifi")
                            .font(.system(size: 12))
                            .foregroundColor(accentColor)
                            .opacity(blinkPhase ? 1 : 0.5)
                    }
                }
                
                // Main Display - Different for Normal vs Overtime mode
                if shouldShowOvertimeMode {
                    // === OVERTIME MODE: Show Loss Stats ===
                    overtimeStatsView
                } else {
                    // === NORMAL MODE: Show Income ===
                    VStack(spacing: 12) {
                        normalIncomeView
                        SegmentedProgressBar(progress: enhancedViewModel.workProgress)
                    }
                }
            }
            .padding(20)
            .background(
                shouldShowOvertimeMode
                    ? LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.02, blue: 0.02).opacity(0.4),
                            Color(red: 0.2, green: 0.05, blue: 0.02).opacity(0.3),
                            Color(red: 0.15, green: 0.02, blue: 0.02).opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : nil
            )
        }
        .background(
            ZStack {
                CyberpunkTheme.terminalSectionBackground
                
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        shouldShowOvertimeMode
                            ? CyberpunkTheme.redPrimary.opacity(0.5)
                            : CyberpunkTheme.greenPrimary.opacity(0.3),
                        lineWidth: shouldShowOvertimeMode ? 2 : 1
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(height: 260) // Fixed height to prevent jumping between modes
        .shadow(
            color: shouldShowOvertimeMode
                ? CyberpunkTheme.redPrimary.opacity(0.15)
                : CyberpunkTheme.greenGlow.opacity(0.05),
            radius: 20
        )
        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                blinkPhase = true
            }
        }
    }
    
    // MARK: - Normal Income View
    private var normalIncomeView: some View {
        VStack(spacing: 8) {
            // Main Amount Display
            Group {
                if privacySettings.isPrivacyModeEnabled {
                    switch privacySettings.displayMode {
                    case .dots:
                        Text("¥••,•••.••")
                            .font(.system(size: 48, weight: .black, design: .monospaced))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [CyberpunkTheme.cyanPrimary, CyberpunkTheme.bluePrimary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: CyberpunkTheme.cyanPrimary.opacity(0.6), radius: 15)
                    case .blur:
                        Text(formatCurrency(enhancedViewModel.currentIncome))
                            .font(.system(size: 48, weight: .black, design: .monospaced))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [CyberpunkTheme.bluePrimary, CyberpunkTheme.purplePrimary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .blur(radius: 12)
                            .shadow(color: CyberpunkTheme.bluePrimary.opacity(0.8), radius: 20)
                    case .emoji:
                        Text(privacySettings.getEmojiForAmount(enhancedViewModel.currentIncome))
                            .font(.system(size: 36))
                            .shadow(color: CyberpunkTheme.yellowPrimary.opacity(0.6), radius: 15)
                    }
                } else {
                    AnimatedIncomeText(
                        value: enhancedViewModel.currentIncome,
                        fontSize: 48,
                        gradient: LinearGradient(
                            colors: [CyberpunkTheme.greenPrimary, CyberpunkTheme.cyanPrimary, CyberpunkTheme.greenPrimary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: CyberpunkTheme.greenPrimary.opacity(0.8), radius: 20)
                    .shadow(color: CyberpunkTheme.greenPrimary.opacity(0.4), radius: 40)
                    .modifier(GlitchEffect(isActive: glitchActive))
                }
            }
            .frame(height: 56)
            
            // Rate & Monthly Stats
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundColor(CyberpunkTheme.cyanPrimary)
                    Text(maskAmount("¥\(String(format: "%.2f", enhancedViewModel.minuteRate))/min", privacyEnabled: privacySettings.isPrivacyModeEnabled))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(CyberpunkTheme.cyanPrimary)
                }
                
                Rectangle()
                    .fill(CyberpunkTheme.greenPrimary.opacity(0.2))
                    .frame(width: 1, height: 12)
                
                HStack(spacing: 4) {
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 10))
                        .foregroundColor(CyberpunkTheme.purplePrimary)
                    Text(maskAmount("Monthly ¥\(String(format: "%.0f", enhancedViewModel.getMonthlyAccumulatedIncome()))", privacyEnabled: privacySettings.isPrivacyModeEnabled))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(CyberpunkTheme.purplePrimary)
                }
            }
        }
    }
    
    // MARK: - Overtime Stats View
    private var overtimeStatsView: some View {
        VStack(spacing: 16) {
            // Overtime Stats Grid
            HStack(spacing: 12) {
                // Overtime Duration
                OvertimeStatBox(
                    label: "Overtime",
                    value: enhancedViewModel.formattedOvertimeDuration,
                    color: CyberpunkTheme.redPrimary
                )
                
                // Estimated Loss
                OvertimeStatBox(
                    label: "Est. Loss",
                    value: privacySettings.isPrivacyModeEnabled ? "¥•••" : "¥\(String(format: "%.0f", enhancedViewModel.overtimeLoss))",
                    color: CyberpunkTheme.orangePrimary
                )
                
                // Rate Loss
                OvertimeStatBox(
                    label: "Rate",
                    value: privacySettings.isPrivacyModeEnabled ? "¥•.••" : "¥\(String(format: "%.2f", enhancedViewModel.minuteRate))",
                    subValue: "/min",
                    color: CyberpunkTheme.yellowPrimary
                )
            }
            
            // Warning Message
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundColor(CyberpunkTheme.redPrimary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unpaid overtime detected")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberpunkTheme.redPrimary.opacity(0.9))
                    Text("Consider ending your work session")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(CyberpunkTheme.redPrimary.opacity(0.6))
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(CyberpunkTheme.redPrimary.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(CyberpunkTheme.redPrimary.opacity(0.3), lineWidth: 1)
                    )
            )
            
            // Today's Earned Amount (fixed, not increasing)
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(CyberpunkTheme.greenPrimary)
                
                Text("Today Earned:")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(privacySettings.isPrivacyModeEnabled ? "¥•••.••" : formatCurrency(enhancedViewModel.currentIncome))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberpunkTheme.greenPrimary)
            }
        }
    }
    
    // MARK: - Helpers
    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "0.00"
        return "¥\(formatted)"
    }
    
    private func maskAmount(_ text: String, privacyEnabled: Bool) -> String {
        if !privacyEnabled { return text }
        return text.replacingOccurrences(of: "[0-9]", with: "•", options: .regularExpression)
    }
}

// MARK: - Overtime Stat Box Component
struct OvertimeStatBox: View {
    let label: String
    let value: String
    var subValue: String? = nil
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(color.opacity(0.7))
            
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text(value)
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(color)
                
                if let sub = subValue {
                    Text(sub)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(color.opacity(0.6))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: color.opacity(0.3), radius: 8)
    }
}

// MARK: - Segmented Progress Bar
struct SegmentedProgressBar: View {
    let progress: Double
    let segmentCount = 20
    
    @State private var animatedSegments: [Bool] = Array(repeating: false, count: 20)
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("TODAY")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(CyberpunkTheme.greenPrimary.opacity(0.5))
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(CyberpunkTheme.greenPrimary.opacity(0.5))
            }
            
            GeometryReader { geometry in
                HStack(spacing: 1) {
                    ForEach(0..<segmentCount, id: \.self) { index in
                        let isFilled = Double(index) / Double(segmentCount) < progress
                        Rectangle()
                            .fill(
                                isFilled
                                    ? LinearGradient(
                                        colors: [CyberpunkTheme.greenPrimary, CyberpunkTheme.cyanPrimary],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                    : LinearGradient(
                                        colors: [Color.clear, Color.clear],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                            )
                            .opacity(animatedSegments[index] && isFilled ? 1 : (isFilled ? 0.8 : 1))
                            .animation(
                                .easeInOut(duration: 1.2)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.08),
                                value: animatedSegments[index]
                            )
                    }
                }
                .frame(height: 10)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.black.opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(CyberpunkTheme.greenPrimary.opacity(0.2), lineWidth: 1)
                )
            }
            .frame(height: 10)
        }
        .onAppear {
            for i in 0..<segmentCount {
                animatedSegments[i] = true
            }
        }
    }
}

// MARK: - Terminal Card Container (New Unified Layout)
struct TerminalCard<Content: View>: View {
    let headerIcon: String
    let headerLabel: String
    let headerColor: Color
    var fixedHeight: CGFloat? = 130 // Default fixed height for uniform cards (compact)
    @ViewBuilder let content: () -> Content
    
    @State private var isHovered = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            ZStack {
                CyberpunkTheme.terminalSectionBackground
                
                // Gradient overlay for some cards
                if headerColor == CyberpunkTheme.bluePrimary {
                    LinearGradient(
                        colors: [
                            CyberpunkTheme.bluePrimary.opacity(0.05),
                            CyberpunkTheme.purplePrimary.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isHovered ? headerColor.opacity(0.5) : CyberpunkTheme.greenPrimary.opacity(0.3),
                        lineWidth: 1
                    )
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(spacing: 4) {
                    Image(systemName: headerIcon)
                        .font(.system(size: 9))
                        .foregroundColor(headerColor.opacity(0.6))
                    Text(headerLabel)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(headerColor.opacity(0.6))
                }
                
                content()
                
                Spacer(minLength: 0)
            }
            .padding(12)
        }
        .frame(height: fixedHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: CyberpunkTheme.greenGlow.opacity(0.05), radius: 20)
        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Quest Log Content (Today's Goal) - New Layout
struct QuestLogContent: View {
    @Binding var showingSettings: Bool
    @Binding var targetSection: DeepLinkSection?
    @ObservedObject var enhancedViewModel: EnhancedIncomeViewModel
    
    @State private var rocketOffset: CGFloat = 0
    @State private var rocketScale: CGFloat = 1.0
    @State private var isHovered = false
    
    private var progressPercent: Int {
        Int(enhancedViewModel.workProgress * 100)
    }
    
    private var isComplete: Bool {
        enhancedViewModel.workProgress >= 1.0
    }
    
    var body: some View {
        ZStack {
            // Main content - left side with right padding for icon
            VStack(alignment: .leading, spacing: 8) {
                // Title row
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(CyberpunkTheme.orangePrimary)
                    Text("Today's Goal")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                // Progress Section - with padding right for icon
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(CyberpunkTheme.cyanPrimary.opacity(0.7))
                        Spacer()
                        Text("\(progressPercent)%")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    // Dynamic Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.black.opacity(0.6))
                                .frame(height: 12)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: isComplete ? [
                                            CyberpunkTheme.magentaPrimary,
                                            CyberpunkTheme.yellowPrimary,
                                            CyberpunkTheme.greenPrimary,
                                            CyberpunkTheme.cyanPrimary
                                        ] : [
                                            CyberpunkTheme.cyanPrimary,
                                            CyberpunkTheme.greenPrimary
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(min(enhancedViewModel.workProgress, 1.0)), height: 12)
                            
                            if isComplete {
                                Text("COMPLETE")
                                    .font(.system(size: 8, weight: .black, design: .monospaced))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(height: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(CyberpunkTheme.cyanPrimary.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.trailing, 56) // Space for icon
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // Icon - Fixed position bottom-right
            Image(systemName: "paperplane.fill")
                .font(.system(size: 36))
                .foregroundColor(CyberpunkTheme.orangePrimary)
                .rotationEffect(.degrees(-12))
                .shadow(color: CyberpunkTheme.orangePrimary.opacity(0.6), radius: 8)
                .opacity(isHovered ? 1 : 0.6)
                .offset(y: rocketOffset)
                .scaleEffect(rocketScale)
                .frame(width: 48, height: 48)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
            // Floating animation on hover
            if hovering {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    rocketOffset = -4
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    rocketOffset = 0
                }
            }
        }
        .onTapGesture {
            // Bounce animation on tap
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                rocketScale = 1.3
                rocketOffset = -8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    rocketScale = 1.0
                    rocketOffset = 0
                }
            }
            targetSection = .financialInfo
            showingSettings = true
        }
    }
}

// MARK: - Loot Item Content (Dream Item / Monthly Goal) - New Layout
struct LootItemContent: View {
    @Binding var showingSettings: Bool
    @Binding var targetSection: DeepLinkSection?
    @ObservedObject var enhancedViewModel: EnhancedIncomeViewModel
    
    @State private var chestScale: CGFloat = 1.0
    @State private var chestRotation: Double = 0
    @State private var isHovered = false
    
    // Goal settings from UserDefaults
    private var goalEnabled: Bool {
        UserDefaults.standard.bool(forKey: "monthlyGoalEnabled")
    }
    
    private var goalTitle: String {
        UserDefaults.standard.string(forKey: "monthlyGoalTitle") ?? "Dream Item"
    }
    
    private var goalTargetAmount: Double {
        Double(UserDefaults.standard.string(forKey: "monthlyGoalTargetAmount") ?? "8000") ?? 8000
    }
    
    private var goalProgress: Double {
        guard goalTargetAmount > 0 else { return 0 }
        return min(enhancedViewModel.getMonthlyAccumulatedIncome() / goalTargetAmount, 1.0)
    }
    
    var body: some View {
        ZStack {
            // Main content
            VStack(alignment: .leading, spacing: 8) {
                // Title row - show goal title if enabled
                HStack(spacing: 6) {
                    if goalEnabled && !goalTitle.isEmpty {
                        Text(goalTitle)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    } else {
                        Text("Monthly Goal")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                
                // Item Icons and percentage - with padding for icon
                VStack(alignment: .leading, spacing: 8) {
                    if goalEnabled {
                        // Show goal progress
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.system(size: 10))
                                .foregroundColor(CyberpunkTheme.orangePrimary)
                                .scaleEffect(isHovered ? 1.2 : 1.0)
                            Image(systemName: "gift.fill")
                                .font(.system(size: 10))
                                .foregroundColor(CyberpunkTheme.purplePrimary.opacity(0.8))
                                .scaleEffect(isHovered ? 1.2 : 1.0)
                            
                            Spacer()
                            
                            Text("\(Int(goalProgress * 100))%")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(goalProgress >= 1.0 ? CyberpunkTheme.greenPrimary : CyberpunkTheme.cyanPrimary)
                        }
                        
                        // Progress Bar
                        VStack(alignment: .leading, spacing: 2) {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.black.opacity(0.6))
                                    
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(
                                            LinearGradient(
                                                colors: goalProgress >= 1.0 
                                                    ? [CyberpunkTheme.greenPrimary, CyberpunkTheme.cyanPrimary]
                                                    : [CyberpunkTheme.orangePrimary, CyberpunkTheme.yellowPrimary],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * CGFloat(goalProgress))
                                        .shadow(color: CyberpunkTheme.orangePrimary.opacity(0.5), radius: 8)
                                }
                            }
                            .frame(height: 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(CyberpunkTheme.orangePrimary.opacity(0.2), lineWidth: 1)
                            )
                            
                            Text("¥\(String(format: "%.0f", enhancedViewModel.getMonthlyAccumulatedIncome())) / ¥\(String(format: "%.0f", goalTargetAmount))")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(CyberpunkTheme.cyanPrimary.opacity(0.7))
                        }
                    } else {
                        // Show "tap to set" message when goal is disabled
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(CyberpunkTheme.purplePrimary.opacity(0.6))
                                .scaleEffect(isHovered ? 1.2 : 1.0)
                            
                            Spacer()
                        }
                        
                        Text("Tap to set a goal")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(CyberpunkTheme.purplePrimary.opacity(0.6))
                        
                        Text("Track your monthly\nearnings target")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.5))
                            .lineSpacing(2)
                    }
                }
                .padding(.trailing, 56) // Space for icon
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // Treasure Chest Icon - Fixed position bottom-right
            TreasureChestIcon()
                .opacity(isHovered ? 1 : 0.6)
                .scaleEffect(chestScale)
                .rotationEffect(.degrees(chestRotation))
                .frame(width: 48, height: 48)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            // Shake and bounce animation on tap
            withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
                chestScale = 1.15
                chestRotation = -5
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
                    chestRotation = 5
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    chestScale = 1.0
                    chestRotation = 0
                }
            }
            targetSection = .monthlyGoal
            showingSettings = true
        }
    }
}

// MARK: - Treasure Chest Icon - New Design with Larger Size
struct TreasureChestIcon: View {
    @State private var sparkle = false
    
    var body: some View {
        ZStack {
            // Chest Body - Larger and more prominent
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.9, green: 0.7, blue: 0.2),
                            Color(red: 0.7, green: 0.5, blue: 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(CyberpunkTheme.yellowPrimary.opacity(0.8), lineWidth: 2)
                )
                .shadow(color: CyberpunkTheme.yellowPrimary.opacity(0.5), radius: 12)
            
            // Chest Line (middle seam)
            Rectangle()
                .fill(Color(red: 0.4, green: 0.3, blue: 0.1).opacity(0.6))
                .frame(width: 40, height: 2)
                .offset(y: -2)
            
            // Lock/Clasp
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.8))
                .frame(width: 12, height: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                )
                .offset(y: -2)
            
            // Sparkle indicator
            Circle()
                .fill(CyberpunkTheme.yellowPrimary)
                .frame(width: 8, height: 8)
                .offset(x: 18, y: -16)
                .opacity(sparkle ? 1 : 0.3)
                .shadow(color: CyberpunkTheme.yellowPrimary.opacity(0.8), radius: 6)
        }
        .frame(width: 48, height: 48)
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                sparkle = true
            }
        }
    }
}

// MARK: - Privacy System Content - New Layout with Eye Icon
struct PrivacySysContent: View {
    @ObservedObject var privacySettings: PrivacySettings
    
    @State private var iconScale: CGFloat = 1.0
    @State private var iconRotation: Double = 0
    @State private var isHovered = false
    @State private var sparkle = false
    
    var body: some View {
        ZStack {
            // Main content
            VStack(alignment: .leading, spacing: 6) {
                // Title row
                HStack(spacing: 6) {
                    Text("Privacy Mode")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                // Content area with padding for icon
                VStack(alignment: .leading, spacing: 8) {
                    // Toggle row
                    HStack(spacing: 6) {
                        Toggle("", isOn: $privacySettings.isPrivacyModeEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: CyberpunkTheme.bluePrimary))
                            .scaleEffect(0.7)
                            .frame(width: 36)
                            .onChange(of: privacySettings.isPrivacyModeEnabled) { _, _ in
                                // Bounce animation when toggled
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                    iconScale = 1.2
                                    iconRotation = privacySettings.isPrivacyModeEnabled ? 10 : -10
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        iconScale = 1.0
                                        iconRotation = 0
                                    }
                                }
                            }
                        
                        Text(privacySettings.isPrivacyModeEnabled ? "[ACTIVE]" : "[INACTIVE]")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(CyberpunkTheme.bluePrimary)
                    }
                    
                    // Status Text
                    HStack(spacing: 3) {
                        Image(systemName: privacySettings.isPrivacyModeEnabled ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 9))
                            .foregroundColor(CyberpunkTheme.cyanPrimary.opacity(0.8))
                        Text(privacySettings.isPrivacyModeEnabled ? "Amounts hidden" : "Visible")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(CyberpunkTheme.cyanPrimary.opacity(0.8))
                    }
                }
                .padding(.trailing, 56) // Space for icon
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // Eye Icon in Blue Square - Fixed position bottom-right
            ZStack {
                // Blue rounded square background
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                CyberpunkTheme.bluePrimary.opacity(0.9),
                                CyberpunkTheme.bluePrimary.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(CyberpunkTheme.cyanPrimary.opacity(0.6), lineWidth: 2)
                    )
                    .shadow(color: CyberpunkTheme.bluePrimary.opacity(privacySettings.isPrivacyModeEnabled ? 0.6 : 0.3), radius: privacySettings.isPrivacyModeEnabled ? 16 : 8)
                    .opacity(privacySettings.isPrivacyModeEnabled ? 1 : 0.5)
                
                // Eye icon
                Image(systemName: privacySettings.isPrivacyModeEnabled ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(red: 0.1, green: 0.2, blue: 0.4))
                
                // Sparkle indicator when active
                if privacySettings.isPrivacyModeEnabled {
                    Circle()
                        .fill(CyberpunkTheme.cyanPrimary)
                        .frame(width: 8, height: 8)
                        .offset(x: 18, y: -18)
                        .opacity(sparkle ? 1 : 0.5)
                        .shadow(color: CyberpunkTheme.cyanPrimary.opacity(0.8), radius: 6)
                }
            }
            .scaleEffect(iconScale)
            .rotationEffect(.degrees(iconRotation))
            .opacity(isHovered ? 1 : 0.6)
            .frame(width: 48, height: 48)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                sparkle = true
            }
        }
    }
}

// MARK: - Status Log Content (Work Status) - New Layout
struct StatusLogContent: View {
    @ObservedObject var enhancedViewModel: EnhancedIncomeViewModel
    
    @State private var statusPulse = false
    @State private var isHovered = false
    
    private var statusText: String {
        switch enhancedViewModel.workStatus {
        case .working: return "Working"
        case .lunch: return "Lunch"
        case .overtime: return "Overtime"
        case .finished: return "Finished"
        case .notStarted: return "Not Started"
        case .absent: return "Absent"
        case .holiday: return "Holiday"
        }
    }
    
    private var statusIndicator: String {
        switch enhancedViewModel.workStatus {
        case .working: return "ONLINE"
        case .lunch: return "BREAK"
        case .overtime: return "OVERTIME"
        case .finished: return "OFFLINE"
        case .notStarted: return "STANDBY"
        case .absent: return "AWAY"
        case .holiday: return "HOLIDAY"
        }
    }
    
    private var statusColor: Color {
        switch enhancedViewModel.workStatus {
        case .working: return CyberpunkTheme.greenPrimary
        case .lunch: return CyberpunkTheme.orangePrimary
        case .overtime: return CyberpunkTheme.redPrimary
        case .finished: return CyberpunkTheme.bluePrimary
        case .notStarted: return .gray
        case .absent: return CyberpunkTheme.redPrimary
        case .holiday: return CyberpunkTheme.purplePrimary
        }
    }
    
    var body: some View {
        ZStack {
            // Main content
            VStack(alignment: .leading, spacing: 8) {
                // Title row with status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: statusColor.opacity(0.8), radius: 4)
                        .opacity(statusPulse ? 1 : 0.5)
                    
                    Text(statusText)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                // Content with padding for icon
                VStack(alignment: .leading, spacing: 4) {
                    // Status Text
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(statusColor.opacity(0.8))
                        Text(statusIndicator)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(statusColor.opacity(0.8))
                    }
                    
                    // Session time - Real data
                    Text("Session: \(enhancedViewModel.formattedSessionDuration)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(CyberpunkTheme.cyanPrimary.opacity(0.7))
                }
                .padding(.trailing, 56) // Space for icon
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // Clock Icon in Cyan Square - Fixed position bottom-right
            ZStack {
                // Cyan rounded square background
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                CyberpunkTheme.cyanPrimary.opacity(0.9),
                                CyberpunkTheme.cyanPrimary.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(CyberpunkTheme.cyanPrimary.opacity(0.8), lineWidth: 2)
                    )
                    .shadow(color: CyberpunkTheme.cyanPrimary.opacity(0.5), radius: 12)
                
                // Clock icon
                Image(systemName: "clock.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(red: 0.1, green: 0.3, blue: 0.35))
                
                // Green status indicator
                Circle()
                    .fill(CyberpunkTheme.greenPrimary)
                    .frame(width: 8, height: 8)
                    .offset(x: 18, y: -18)
                    .opacity(statusPulse ? 1 : 0.5)
                    .shadow(color: CyberpunkTheme.greenPrimary.opacity(0.8), radius: 6)
            }
            .opacity(isHovered ? 1 : 0.6)
            .frame(width: 48, height: 48)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                statusPulse = true
            }
        }
    }
}

// MARK: - User Data Content - New Layout
struct UserDatContent: View {
    @ObservedObject var enhancedViewModel: EnhancedIncomeViewModel
    @ObservedObject var privacySettings: PrivacySettings
    @Binding var showingSettings: Bool
    @Binding var targetSection: DeepLinkSection?
    
    @State private var isHovered = false
    
    private var workDays: Int {
        enhancedViewModel.userProfile?.workdaysPerMonth ?? 22
    }
    
    var body: some View {
        ZStack {
            // Main content
            VStack(alignment: .leading, spacing: 2) {
                let salary = enhancedViewModel.userProfile?.monthlySalary ?? 4200
                Text(maskAmount("¥\(String(format: "%.0f", salary))", privacyEnabled: privacySettings.isPrivacyModeEnabled))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text("\(workDays) days active")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(CyberpunkTheme.cyanPrimary.opacity(0.7))
                
                Spacer()
            }
            .padding(.trailing, 56) // Space for icon
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // User Avatar Icon - Fixed position bottom-right
            UserAvatarIcon()
                .opacity(isHovered ? 1 : 0.6)
                .frame(width: 48, height: 48)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            targetSection = .financialInfo
            showingSettings = true
        }
    }
    
    private func maskAmount(_ text: String, privacyEnabled: Bool) -> String {
        if !privacyEnabled { return text }
        return text.replacingOccurrences(of: "[0-9]", with: "•", options: .regularExpression)
    }
}

// MARK: - User Avatar Icon - New Design with Cyan Square
struct UserAvatarIcon: View {
    @State private var onlinePulse = false
    
    var body: some View {
        ZStack {
            // Cyan/Blue rounded square background
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            CyberpunkTheme.cyanPrimary.opacity(0.9),
                            CyberpunkTheme.bluePrimary.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(CyberpunkTheme.cyanPrimary.opacity(0.8), lineWidth: 2)
                )
                .shadow(color: CyberpunkTheme.cyanPrimary.opacity(0.5), radius: 12)
            
            // User Icon
            Image(systemName: "person.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(red: 0.1, green: 0.3, blue: 0.4))
            
            // Highlight Dots
            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
                .offset(x: -10, y: -10)
            
            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
                .offset(x: 10, y: -10)
            
            // Online Indicator
            Circle()
                .fill(CyberpunkTheme.greenPrimary)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(CyberpunkTheme.greenPrimary.opacity(0.6), lineWidth: 1)
                )
                .offset(x: 18, y: -18)
                .opacity(onlinePulse ? 1 : 0.5)
                .shadow(color: CyberpunkTheme.greenPrimary.opacity(0.8), radius: 6)
        }
        .frame(width: 48, height: 48)
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                onlinePulse = true
            }
        }
    }
}

// MARK: - Schedule Config Content - New Layout
struct ScheduleCfgContent: View {
    @ObservedObject var enhancedViewModel: EnhancedIncomeViewModel
    @Binding var showingSettings: Bool
    @Binding var targetSection: DeepLinkSection?
    
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            // Main content
            VStack(alignment: .leading, spacing: 2) {
                Text(enhancedViewModel.formattedWorkSchedule)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberpunkTheme.purplePrimary.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(enhancedViewModel.formattedWorkDays)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(CyberpunkTheme.purplePrimary.opacity(0.7))
                
                Spacer()
            }
            .padding(.trailing, 56) // Space for icon
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // Calendar Icon - Fixed position bottom-right
            CalendarIcon()
                .opacity(isHovered ? 1 : 0.6)
                .frame(width: 48, height: 48)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            targetSection = .workSchedule
            showingSettings = true
        }
    }
}

// MARK: - Calendar Icon - New Design with Purple Square
struct CalendarIcon: View {
    private var currentDay: Int {
        Calendar.current.component(.day, from: Date())
    }
    
    var body: some View {
        ZStack {
            // Purple/Pink rounded square background
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            CyberpunkTheme.purplePrimary.opacity(0.9),
                            CyberpunkTheme.magentaPrimary.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(CyberpunkTheme.purplePrimary.opacity(0.8), lineWidth: 2)
                )
                .shadow(color: CyberpunkTheme.purplePrimary.opacity(0.5), radius: 12)
            
            // Calendar icon
            Image(systemName: "calendar")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(red: 0.25, green: 0.15, blue: 0.35))
            
            // Date number overlay - shows current day
            Text("\(currentDay)")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .offset(y: 2)
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
        }
        .frame(width: 48, height: 48)
    }
}

// MARK: - Terminal Footer with Hover Animations
struct TerminalFooter: View {
    @Binding var showingSettings: Bool
    @Binding var targetSection: DeepLinkSection?
    @State private var cursorBlink = false
    @State private var gearRotation: Double = 0
    @State private var isSettingsHovered = false
    @State private var isQuitHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Text("$")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(CyberpunkTheme.greenPrimary.opacity(0.6))
            
            Button(action: { 
                targetSection = nil  // Open settings without specific section
                showingSettings = true 
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12))
                        .foregroundColor(isSettingsHovered ? CyberpunkTheme.cyanPrimary.opacity(0.8) : CyberpunkTheme.cyanPrimary)
                        .rotationEffect(.degrees(gearRotation))
                    Text("Settings")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(isSettingsHovered ? CyberpunkTheme.cyanPrimary.opacity(0.8) : CyberpunkTheme.cyanPrimary)
                }
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isSettingsHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                    // Rotate gear 90 degrees on hover
                    withAnimation(.easeInOut(duration: 0.3)) {
                        gearRotation = 90
                    }
                } else {
                    NSCursor.pop()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        gearRotation = 0
                    }
                }
            }
            
            Rectangle()
                .fill(CyberpunkTheme.greenPrimary.opacity(0.2))
                .frame(width: 1, height: 12)
            
            Button(action: { NSApplication.shared.terminate(nil) }) {
                HStack(spacing: 6) {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                        .foregroundColor(isQuitHovered ? CyberpunkTheme.redPrimary.opacity(0.8) : CyberpunkTheme.redPrimary)
                        .scaleEffect(isQuitHovered ? 1.1 : 1.0)
                    Text("Quit")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(isQuitHovered ? CyberpunkTheme.redPrimary.opacity(0.8) : CyberpunkTheme.redPrimary)
                }
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isQuitHovered = hovering
                withAnimation(.easeInOut(duration: 0.15)) {
                    // Animation is handled by scaleEffect above
                }
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            
            Spacer()
            
            // Blinking Cursor
            Text("_")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(CyberpunkTheme.greenPrimary.opacity(0.6))
                .opacity(cursorBlink ? 1 : 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                CyberpunkTheme.terminalSectionBackground
                
                RoundedRectangle(cornerRadius: 8)
                    .stroke(CyberpunkTheme.greenPrimary.opacity(0.3), lineWidth: 1)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                cursorBlink = true
            }
        }
    }
}

// MARK: - Weekly Stats Mini Bar
struct WeeklyStatsMiniBar: View {
    @ObservedObject private var historyService = IncomeHistoryService.shared
    
    var body: some View {
        HStack(spacing: 0) {
            // Weekly mini chart
            HStack(spacing: 2) {
                ForEach(0..<7, id: \.self) { dayIndex in
                    let data = getDataForDay(dayIndex)
                    VStack(spacing: 2) {
                        // Bar
                        RoundedRectangle(cornerRadius: 2)
                            .fill(data.hasData ? barColor(for: data.percentage) : Color.gray.opacity(0.2))
                            .frame(width: 8, height: max(4, CGFloat(data.percentage) * 24))
                        
                        // Day label
                        Text(dayLabel(for: dayIndex))
                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                            .foregroundColor(isToday(dayIndex) ? CyberpunkTheme.greenPrimary : .gray.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 8)
            
            // Divider
            Rectangle()
                .fill(CyberpunkTheme.greenPrimary.opacity(0.2))
                .frame(width: 1, height: 28)
            
            // Stats Summary
            HStack(spacing: 16) {
                // Week Total
                VStack(alignment: .leading, spacing: 0) {
                    Text("WEEK")
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(CyberpunkTheme.cyanPrimary.opacity(0.5))
                    Text("¥\(formatAmount(historyService.statistics.weekIncome))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberpunkTheme.cyanPrimary)
                }
                
                // Trend
                HStack(spacing: 2) {
                    Image(systemName: historyService.statistics.weekTrend.icon)
                        .font(.system(size: 10))
                    Text(trendText)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
                .foregroundColor(trendColor)
                
                // Days worked
                VStack(alignment: .leading, spacing: 0) {
                    Text("DAYS")
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(CyberpunkTheme.purplePrimary.opacity(0.5))
                    Text("\(historyService.statistics.weekWorkedDays)/5")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberpunkTheme.purplePrimary)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(
            ZStack {
                CyberpunkTheme.terminalSectionBackground
                
                RoundedRectangle(cornerRadius: 8)
                    .stroke(CyberpunkTheme.greenPrimary.opacity(0.2), lineWidth: 1)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private struct DayData {
        var income: Double = 0
        var percentage: Double = 0
        var hasData: Bool = false
    }
    
    private func getDataForDay(_ daysAgo: Int) -> DayData {
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: -(6 - daysAgo), to: Date()) ?? Date()
        
        if let record = historyService.records.first(where: { 
            calendar.isDate($0.date, inSameDayAs: targetDate) && $0.isWorkday 
        }) {
            // Calculate percentage based on max income in week
            let maxIncome = historyService.weeklyData.map { $0.income }.max() ?? 1
            let percentage = maxIncome > 0 ? record.income / maxIncome : 0
            return DayData(income: record.income, percentage: percentage, hasData: true)
        }
        
        return DayData()
    }
    
    private func dayLabel(for index: Int) -> String {
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: -(6 - index), to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: targetDate).prefix(1))
    }
    
    private func isToday(_ index: Int) -> Bool {
        return index == 6 // Last index is today
    }
    
    private func barColor(for percentage: Double) -> Color {
        if percentage >= 0.8 {
            return CyberpunkTheme.greenPrimary
        } else if percentage >= 0.5 {
            return CyberpunkTheme.cyanPrimary
        } else {
            return CyberpunkTheme.yellowPrimary
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        if amount >= 10000 {
            return String(format: "%.1fk", amount / 1000)
        } else if amount >= 1000 {
            return String(format: "%.0f", amount)
        } else {
            return String(format: "%.0f", amount)
        }
    }
    
    private var trendText: String {
        switch historyService.statistics.weekTrend {
        case .up: return "UP"
        case .down: return "DOWN"
        case .stable: return "STEADY"
        }
    }
    
    private var trendColor: Color {
        switch historyService.statistics.weekTrend {
        case .up: return CyberpunkTheme.greenPrimary
        case .down: return CyberpunkTheme.redPrimary
        case .stable: return CyberpunkTheme.yellowPrimary
        }
    }
}

// MARK: - Glitch Effect Modifier
struct GlitchEffect: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if isActive {
            content
                .overlay(
                    content
                        .foregroundStyle(CyberpunkTheme.redPrimary.opacity(0.75))
                        .offset(x: 0.5)
                        .blendMode(.screen)
                )
                .overlay(
                    content
                        .foregroundStyle(CyberpunkTheme.cyanPrimary.opacity(0.75))
                        .offset(x: -0.5)
                        .blendMode(.screen)
                )
        } else {
            content
        }
    }
}


