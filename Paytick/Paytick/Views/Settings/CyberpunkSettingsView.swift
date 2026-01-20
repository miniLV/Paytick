//
//  CyberpunkSettingsView.swift
//  Paytick
//
//  Cyberpunk Terminal-style Settings - 100% Figma Replication
//

import SwiftUI

// MARK: - Cyberpunk Settings View
struct CyberpunkSettingsView: View {
    @ObservedObject var enhancedViewModel: EnhancedIncomeViewModel
    @ObservedObject var privacySettings: PrivacySettings
    @ObservedObject var iconSettings: PrivacyIconSettings
    @Environment(\.dismiss) var dismiss
    
    @State private var activeTab: CyberpunkSettingsTab
    let initialSection: DeepLinkSection?
    
    init(
        enhancedViewModel: EnhancedIncomeViewModel,
        privacySettings: PrivacySettings,
        iconSettings: PrivacyIconSettings,
        initialTab: CyberpunkSettingsTab = .personal,
        initialSection: DeepLinkSection? = nil
    ) {
        self.enhancedViewModel = enhancedViewModel
        self.privacySettings = privacySettings
        self.iconSettings = iconSettings
        self._activeTab = State(initialValue: initialTab)
        self.initialSection = initialSection
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            CyberpunkSettingsSidebar(activeTab: $activeTab)
                .frame(width: 256)
            
            // Main Content
            ZStack {
                // CRT Scanlines
                CRTScanlineOverlay(phase: 0)
                    .opacity(0.03)
                    .allowsHitTesting(false)
                
                VStack(spacing: 0) {
                    // Header
                    CyberpunkSettingsHeader(
                        activeTab: activeTab,
                        onClose: { dismiss() }
                    )
                    
                    // Content Area
                    ScrollViewReader { proxy in
                        ScrollView {
                            Group {
                                switch activeTab {
                                case .personal:
                                    CyberpunkPersonalInfoContent(
                                        enhancedViewModel: enhancedViewModel,
                                        scrollProxy: proxy,
                                        initialSection: initialSection
                                    )
                                case .privacy:
                                    CyberpunkPrivacyContent(privacySettings: privacySettings)
                                case .notifications:
                                    CyberpunkNotificationsContent()
                                case .advanced:
                                    CyberpunkAdvancedContent()
                                }
                            }
                            .padding(32)
                        }
                    }
                    
                    // Footer
                    CyberpunkSettingsFooter()
                }
            }
            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        }
        .frame(width: 896, height: 600)
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(CyberpunkTheme.greenPrimary.opacity(0.4), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.9), radius: 60)
        .shadow(color: CyberpunkTheme.greenPrimary.opacity(0.2), radius: 30)
    }
}

// MARK: - Settings Tab Enum
enum CyberpunkSettingsTab: String, CaseIterable {
    case personal = "Personal Info"
    case privacy = "Privacy"
    case notifications = "Notifications"
    case advanced = "Advanced"
    
    var icon: String {
        switch self {
        case .personal: return "person.fill"
        case .privacy: return "shield.fill"
        case .notifications: return "bell.fill"
        case .advanced: return "terminal.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .personal: return CyberpunkTheme.greenPrimary
        case .privacy: return CyberpunkTheme.bluePrimary
        case .notifications: return CyberpunkTheme.yellowPrimary
        case .advanced: return CyberpunkTheme.purplePrimary
        }
    }
    
    var headerTitle: String {
        switch self {
        case .personal: return "Personal Information"
        case .privacy: return "Privacy Settings"
        case .notifications: return "Notifications"
        case .advanced: return "Advanced Settings"
        }
    }
    
    var headerSubtitle: String {
        switch self {
        case .personal: return "Configure your salary, work schedule, and income tracking preferences"
        case .privacy: return "Control how your financial data is displayed and protected"
        case .notifications: return "Manage alerts and notification preferences"
        case .advanced: return "Advanced configuration options for power users"
        }
    }
}

// MARK: - Deep Link Section Enum (for settings navigation)
enum DeepLinkSection: String, CaseIterable {
    case financialInfo = "financial_info"      // Monthly salary, work days
    case workSchedule = "work_schedule"        // Start/end time, working days
    case monthlyGoal = "monthly_goal"          // Monthly goal settings
}

// MARK: - Sidebar
struct CyberpunkSettingsSidebar: View {
    @Binding var activeTab: CyberpunkSettingsTab
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [CyberpunkTheme.greenPrimary, CyberpunkTheme.cyanPrimary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Configure your income\ntracking preferences")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(CyberpunkTheme.greenPrimary.opacity(0.5))
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .overlay(
                Rectangle()
                    .fill(CyberpunkTheme.greenPrimary.opacity(0.2))
                    .frame(height: 1),
                alignment: .bottom
            )
            
            // Tab List
            VStack(spacing: 4) {
                ForEach(CyberpunkSettingsTab.allCases, id: \.self) { tab in
                    CyberpunkSidebarItem(
                        tab: tab,
                        isActive: activeTab == tab,
                        action: { activeTab = tab }
                    )
                }
            }
            .padding(12)
            
            Spacer()
            
            // Footer - App Info & GitHub
            VStack(spacing: 8) {
                // App Name & Version
                HStack(spacing: 6) {
                    Text("Paytick")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberpunkTheme.greenPrimary)
                    Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.6))
                }
                
                // GitHub Link
                Button(action: {
                    if let url = URL(string: "https://github.com/miniLV/Paytick") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 6) {
                        // GitHub Icon (using SF Symbol that looks like GitHub)
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(CyberpunkTheme.cyanPrimary.opacity(0.8))
                        Text("GitHub")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(CyberpunkTheme.cyanPrimary.opacity(0.8))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(CyberpunkTheme.cyanPrimary.opacity(0.6))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(CyberpunkTheme.cyanPrimary.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(CyberpunkTheme.cyanPrimary.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { isHovering in
                    if isHovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .padding(.bottom, 16)
            .overlay(
                Rectangle()
                    .fill(CyberpunkTheme.greenPrimary.opacity(0.2))
                    .frame(height: 1),
                alignment: .top
            )
        }
        .background(Color.black.opacity(0.6))
        .overlay(
            Rectangle()
                .fill(CyberpunkTheme.greenPrimary.opacity(0.2))
                .frame(width: 1),
            alignment: .trailing
        )
    }
}

// MARK: - Sidebar Item
struct CyberpunkSidebarItem: View {
    let tab: CyberpunkSettingsTab
    let isActive: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Active Indicator
                if isActive {
                    Rectangle()
                        .fill(CyberpunkTheme.greenPrimary)
                        .frame(width: 3, height: 32)
                        .cornerRadius(2)
                        .shadow(color: CyberpunkTheme.greenPrimary.opacity(0.6), radius: 10)
                }
                
                Image(systemName: tab.icon)
                    .font(.system(size: 14))
                    .foregroundColor(isActive ? tab.color : .gray.opacity(0.5))
                    .opacity(isActive ? 1 : 0.8)
                    .animation(isActive ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: isActive)
                
                Text(tab.rawValue)
                    .font(.system(size: 14, weight: isActive ? .bold : .medium, design: .monospaced))
                    .foregroundColor(isActive ? .white : .gray.opacity(0.6))
                
                Spacer()
                
                if isActive {
                    Text(">")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(CyberpunkTheme.greenPrimary)
                }
            }
            .padding(.horizontal, isActive ? 0 : 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? CyberpunkTheme.greenPrimary.opacity(0.1) : (isHovered ? CyberpunkTheme.greenPrimary.opacity(0.05) : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isActive ? CyberpunkTheme.greenPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Settings Header
struct CyberpunkSettingsHeader: View {
    let activeTab: CyberpunkSettingsTab
    let onClose: () -> Void
    
    @State private var isCloseHovered = false
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(activeTab.headerTitle)
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(activeTab.headerSubtitle)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.6))
            }
            
            Spacer()
            
            // Close Button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isCloseHovered ? CyberpunkTheme.redPrimary : .gray.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isCloseHovered ? CyberpunkTheme.redPrimary.opacity(0.1) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isCloseHovered ? CyberpunkTheme.redPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isCloseHovered = hovering
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .overlay(
            Rectangle()
                .fill(CyberpunkTheme.greenPrimary.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Settings Footer
struct CyberpunkSettingsFooter: View {
    @State private var runningPulse = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 12))
                .foregroundColor(CyberpunkTheme.greenPrimary.opacity(0.5))
            
            Text("$")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(CyberpunkTheme.greenPrimary.opacity(0.5))
            
            Text("./auto_save.sh --realtime")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(CyberpunkTheme.cyanPrimary)
            
            HStack(spacing: 4) {
                Circle()
                    .fill(CyberpunkTheme.greenPrimary)
                    .frame(width: 6, height: 6)
                    .opacity(runningPulse ? 1 : 0.5)
                
                Text("RUNNING")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberpunkTheme.greenPrimary)
            }
            .padding(.leading, 8)
            
            Spacer()
            
            Text("All changes saved automatically")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .fill(CyberpunkTheme.greenPrimary.opacity(0.2))
                .frame(height: 1),
            alignment: .top
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                runningPulse = true
            }
        }
    }
}

// MARK: - Personal Info Content
struct CyberpunkPersonalInfoContent: View {
    @ObservedObject var enhancedViewModel: EnhancedIncomeViewModel
    let scrollProxy: ScrollViewProxy
    let initialSection: DeepLinkSection?
    
    @State private var monthlySalary: String = "8000"
    @State private var workDays: Int = 22
    @State private var startTime = Date.createTime(hour: 8, minute: 30)
    @State private var endTime = Date.createTime(hour: 17, minute: 30)
    @State private var selectedDays: Set<String> = ["Mon", "Tue", "Wed", "Thu", "Fri"]
    
    // Monthly Goal States
    @State private var goalTitle: String = ""
    @State private var goalTargetAmount: String = "8000"
    @State private var goalEnabled: Bool = false
    
    // Validation States
    @State private var salaryError: String?
    @State private var goalAmountError: String?
    @State private var scheduleError: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Financial Information Section
            CyberpunkDeepLinkSection(
                icon: "dollarsign.circle.fill",
                title: "Financial Information",
                color: CyberpunkTheme.greenPrimary
            ) {
                VStack(spacing: 16) {
                    // Monthly Salary
                    CyberpunkSettingsCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                CyberpunkIconBadge(
                                    icon: "dollarsign.circle.fill",
                                    color: CyberpunkTheme.greenPrimary
                                )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Monthly Salary")
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    Text("Your gross monthly salary before taxes")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundColor(.gray.opacity(0.6))
                                }
                                
                                Spacer()
                                
                                CyberpunkTextInput(
                                    text: $monthlySalary,
                                    placeholder: "8000",
                                    suffix: "¥",
                                    color: salaryError != nil ? CyberpunkTheme.redPrimary : CyberpunkTheme.cyanPrimary
                                )
                                .frame(width: 128)
                            }
                            
                            // Validation error message
                            if let error = salaryError {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 10))
                                    Text(error)
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                }
                                .foregroundColor(CyberpunkTheme.redPrimary)
                                .padding(.leading, 44)
                            }
                        }
                    }
                    
                    // Work Days per Month
                    CyberpunkSettingsCard {
                        HStack(spacing: 12) {
                            CyberpunkIconBadge(
                                icon: "calendar.circle.fill",
                                color: CyberpunkTheme.bluePrimary
                            )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Work Days per Month")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("Average number of working days")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            CyberpunkStepper(value: $workDays, range: 10...31, unit: "Days")
                        }
                    }
                }
            }
            .id(DeepLinkSection.financialInfo)
            
            // Work Schedule Section
            CyberpunkDeepLinkSection(
                icon: "clock.fill",
                title: "Work Schedule",
                color: CyberpunkTheme.greenPrimary
            ) {
                CyberpunkSettingsCard {
                    VStack(spacing: 20) {
                        // Time Inputs
                        HStack(spacing: 16) {
                            // Start Time
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    CyberpunkMiniIconBadge(emoji: "🌅", color: CyberpunkTheme.yellowPrimary)
                                    Text("Start Time")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                
                                CyberpunkTimePicker(time: $startTime, color: scheduleError != nil ? CyberpunkTheme.redPrimary : CyberpunkTheme.yellowPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            
                            // End Time
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    CyberpunkMiniIconBadge(emoji: "🌙", color: CyberpunkTheme.purplePrimary)
                                    Text("End Time")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                
                                CyberpunkTimePicker(time: $endTime, color: scheduleError != nil ? CyberpunkTheme.redPrimary : CyberpunkTheme.purplePrimary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        // Schedule validation error
                        if let error = scheduleError {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10))
                                Text(error)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                            }
                            .foregroundColor(CyberpunkTheme.redPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Working Days
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                CyberpunkMiniIconBadge(
                                    icon: "calendar",
                                    color: CyberpunkTheme.cyanPrimary
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Working Days")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    Text("Select your regular working days")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundColor(.gray.opacity(0.6))
                                }
                            }
                            
                            CyberpunkWeekdaySelector(selectedDays: $selectedDays)
                        }
                    }
                }
            }
            .id(DeepLinkSection.workSchedule)
            
            // Monthly Goal Section (Lower Priority - Optional)
            CyberpunkDeepLinkSection(
                icon: "target",
                title: "Monthly Goal",
                color: CyberpunkTheme.orangePrimary
            ) {
                VStack(spacing: 16) {
                    // Goal Toggle
                    CyberpunkSettingsCard {
                        HStack(spacing: 12) {
                            CyberpunkIconBadge(
                                icon: "flag.fill",
                                color: CyberpunkTheme.orangePrimary
                            )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Enable Monthly Goal")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("Track progress toward your monthly target")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $goalEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: CyberpunkTheme.orangePrimary))
                                .scaleEffect(0.8)
                        }
                    }
                    
                    if goalEnabled {
                        // Goal Target Amount
                        CyberpunkSettingsCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 12) {
                                    CyberpunkIconBadge(
                                        icon: "dollarsign.circle.fill",
                                        color: CyberpunkTheme.yellowPrimary
                                    )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Target Amount")
                                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                        Text("Monthly income target to achieve")
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                            .foregroundColor(.gray.opacity(0.6))
                                    }
                                    
                                    Spacer()
                                    
                                    CyberpunkTextInput(
                                        text: $goalTargetAmount,
                                        placeholder: "8000",
                                        suffix: "¥",
                                        color: goalAmountError != nil ? CyberpunkTheme.redPrimary : CyberpunkTheme.yellowPrimary
                                    )
                                    .frame(width: 128)
                                }
                                
                                // Validation error message
                                if let error = goalAmountError {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 10))
                                        Text(error)
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    }
                                    .foregroundColor(CyberpunkTheme.redPrimary)
                                    .padding(.leading, 44)
                                }
                            }
                        }
                        
                        // Goal Reward Item
                        CyberpunkSettingsCard {
                            HStack(spacing: 12) {
                                CyberpunkIconBadge(
                                    icon: "gift.fill",
                                    color: CyberpunkTheme.purplePrimary
                                )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Reward Item")
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    Text("What will you buy when reaching the goal?")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundColor(.gray.opacity(0.6))
                                }
                                
                                Spacer()
                                
                                CyberpunkTextInput(
                                    text: $goalTitle,
                                    placeholder: "iPhone 15",
                                    color: CyberpunkTheme.purplePrimary
                                )
                                .frame(width: 160)
                            }
                        }
                        
                        // Current Progress Preview
                        let progress = calculateGoalProgress()
                        CyberpunkSettingsCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: "chart.bar.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(CyberpunkTheme.cyanPrimary)
                                        Text("Current Progress")
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(Int(progress * 100))%")
                                        .font(.system(size: 14, weight: .black, design: .monospaced))
                                        .foregroundColor(progress >= 1.0 ? CyberpunkTheme.greenPrimary : CyberpunkTheme.cyanPrimary)
                                }
                                
                                // Progress Bar
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.black.opacity(0.6))
                                        
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(
                                                LinearGradient(
                                                    colors: progress >= 1.0 
                                                        ? [CyberpunkTheme.greenPrimary, CyberpunkTheme.cyanPrimary]
                                                        : [CyberpunkTheme.orangePrimary, CyberpunkTheme.yellowPrimary],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geometry.size.width * CGFloat(min(progress, 1.0)))
                                            .shadow(color: CyberpunkTheme.orangePrimary.opacity(0.5), radius: 8)
                                    }
                                }
                                .frame(height: 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(CyberpunkTheme.orangePrimary.opacity(0.3), lineWidth: 1)
                                )
                                
                                // Progress Details
                                HStack {
                                    Text("¥\(String(format: "%.0f", enhancedViewModel.getMonthlyAccumulatedIncome()))")
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundColor(CyberpunkTheme.cyanPrimary)
                                    
                                    Spacer()
                                    
                                    Text("/ ¥\(goalTargetAmount)")
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundColor(.gray.opacity(0.6))
                                }
                            }
                        }
                    }
                }
            }
            .id(DeepLinkSection.monthlyGoal)
        }
        .onAppear {
            loadCurrentValues()
            // Auto-scroll to target section if specified
            if let section = initialSection {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        scrollProxy.scrollTo(section, anchor: .top)
                    }
                }
            }
        }
        .onChange(of: monthlySalary) { _, _ in saveConfiguration() }
        .onChange(of: workDays) { _, _ in saveConfiguration() }
        .onChange(of: startTime) { _, _ in saveConfiguration() }
        .onChange(of: endTime) { _, _ in saveConfiguration() }
        .onChange(of: selectedDays) { _, _ in saveConfiguration() }
        .onChange(of: goalEnabled) { _, _ in saveGoalSettings() }
        .onChange(of: goalTargetAmount) { _, _ in saveGoalSettings() }
        .onChange(of: goalTitle) { _, _ in saveGoalSettings() }
    }
    
    private func loadCurrentValues() {
        if let profile = enhancedViewModel.userProfile {
            monthlySalary = String(format: "%.0f", profile.monthlySalary)
            workDays = profile.workdaysPerMonth
        }
        
        if let schedule = enhancedViewModel.workSchedule {
            startTime = schedule.startTime
            endTime = schedule.endTime
            selectedDays = Set(schedule.workdays.map { $0.shortName })
        }
        
        // Load goal settings
        goalEnabled = UserDefaults.standard.bool(forKey: "monthlyGoalEnabled")
        goalTargetAmount = UserDefaults.standard.string(forKey: "monthlyGoalTargetAmount") ?? "8000"
        goalTitle = UserDefaults.standard.string(forKey: "monthlyGoalTitle") ?? ""
    }
    
    private func saveConfiguration() {
        // Validate salary
        switch EnhancedIncomeViewModel.validateSalary(monthlySalary) {
        case .success(let salary):
            salaryError = nil
            
            // Validate work days
            switch EnhancedIncomeViewModel.validateWorkDays(workDays) {
            case .success(let days):
                // Validate work times
                switch EnhancedIncomeViewModel.validateWorkTimes(start: startTime, end: endTime) {
                case .success:
                    scheduleError = nil
                    
                    // All validations passed - save
                    let profile = UserProfile(
                        name: enhancedViewModel.userProfile?.name ?? "User",
                        monthlySalary: salary,
                        workdaysPerMonth: days,
                        currency: "CNY"
                    )
                    enhancedViewModel.updateUserProfile(profile)
                    
                    // Save schedule
                    let workdaySet: Set<Weekday> = Set(selectedDays.compactMap { shortName in
                        Weekday.allCases.first { $0.shortName == shortName }
                    })
                    
                    let lunchStart = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
                    let lunchEnd = Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date()) ?? Date()
                    
                    let schedule = WorkSchedule(
                        startTime: startTime,
                        endTime: endTime,
                        lunchStartTime: lunchStart,
                        lunchEndTime: lunchEnd,
                        workdays: workdaySet
                    )
                    enhancedViewModel.updateWorkSchedule(schedule)
                    
                case .failure(let error):
                    scheduleError = error.message
                }
            case .failure:
                // Work days validation is handled by stepper bounds, shouldn't fail
                break
            }
        case .failure(let error):
            salaryError = error.message
        }
    }
    
    private func saveGoalSettings() {
        // Validate goal amount if enabled
        if goalEnabled {
            switch EnhancedIncomeViewModel.validateGoalAmount(goalTargetAmount) {
            case .success:
                goalAmountError = nil
            case .failure(let error):
                goalAmountError = error.message
                return // Don't save invalid goal
            }
        } else {
            goalAmountError = nil
        }
        
        UserDefaults.standard.set(goalEnabled, forKey: "monthlyGoalEnabled")
        UserDefaults.standard.set(goalTargetAmount, forKey: "monthlyGoalTargetAmount")
        UserDefaults.standard.set(goalTitle, forKey: "monthlyGoalTitle")
    }
    
    private func calculateGoalProgress() -> Double {
        guard let targetAmount = Double(goalTargetAmount), targetAmount > 0 else { return 0 }
        let currentIncome = enhancedViewModel.getMonthlyAccumulatedIncome()
        return min(currentIncome / targetAmount, 1.0)
    }
}

// MARK: - Privacy Content
struct CyberpunkPrivacyContent: View {
    @ObservedObject var privacySettings: PrivacySettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Privacy Protection Section
            CyberpunkDeepLinkSection(
                icon: "shield.fill",
                title: "Privacy Protection",
                color: CyberpunkTheme.bluePrimary
            ) {
                CyberpunkSettingsCard(borderColor: CyberpunkTheme.bluePrimary) {
                    HStack(spacing: 12) {
                        CyberpunkIconBadge(
                            icon: privacySettings.isPrivacyModeEnabled ? "eye.slash.fill" : "eye.fill",
                            color: CyberpunkTheme.bluePrimary
                        )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Privacy Mode")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text("Hide sensitive financial amounts when enabled")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $privacySettings.isPrivacyModeEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: CyberpunkTheme.bluePrimary))
                    }
                }
            }
            
            if privacySettings.isPrivacyModeEnabled {
                // Display Mode Section
                CyberpunkDeepLinkSection(
                    icon: "sparkles",
                    title: "Display Mode",
                    color: CyberpunkTheme.cyanPrimary
                ) {
                    VStack(spacing: 12) {
                        // Emoji Mode
                        CyberpunkPrivacyModeOption(
                            title: "🎮 Emoji Mode",
                            description: "Replace amounts with fun emojis - looks like game stats",
                            example: "¥12,345 → 🚀🚀⭐✨",
                            isSelected: privacySettings.displayMode == .emoji,
                            isRecommended: true,
                            color: CyberpunkTheme.greenPrimary,
                            action: { privacySettings.displayMode = .emoji }
                        )
                        
                        // Blur Mode
                        CyberpunkPrivacyModeOption(
                            title: "🌫️ Blur Mode",
                            description: "Apply gaussian blur effect to amounts",
                            example: nil,
                            isBlurExample: true,
                            isSelected: privacySettings.displayMode == .blur,
                            color: CyberpunkTheme.purplePrimary,
                            action: { privacySettings.displayMode = .blur }
                        )
                        
                        // Dots Mode
                        CyberpunkPrivacyModeOption(
                            title: "••• Dots Mode",
                            description: "Replace all digits with dots (classic style)",
                            example: "¥12,345 → ¥••,•••",
                            isSelected: privacySettings.displayMode == .dots,
                            color: CyberpunkTheme.cyanPrimary,
                            action: { privacySettings.displayMode = .dots }
                        )
                    }
                }
                
                if privacySettings.displayMode == .emoji {
                    // Emoji Theme Section
                    CyberpunkDeepLinkSection(
                        icon: "sparkles",
                        title: "Emoji Theme",
                        color: CyberpunkTheme.yellowPrimary
                    ) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            CyberpunkEmojiPresetCard(
                                emojis: "🍎🍊🍇",
                                title: "Fruits",
                                subtitle: "Fresh & healthy",
                                isSelected: privacySettings.emojiPreset == .fruits,
                                color: CyberpunkTheme.greenPrimary,
                                action: { privacySettings.emojiPreset = .fruits }
                            )
                            
                            CyberpunkEmojiPresetCard(
                                emojis: "🚀⭐✨",
                                title: "Rockets",
                                subtitle: "Space adventure",
                                isSelected: privacySettings.emojiPreset == .rockets,
                                color: CyberpunkTheme.cyanPrimary,
                                action: { privacySettings.emojiPreset = .rockets }
                            )
                            
                            CyberpunkEmojiPresetCard(
                                emojis: "💎💰🪙",
                                title: "Crypto",
                                subtitle: "Digital wealth",
                                isSelected: privacySettings.emojiPreset == .crypto,
                                color: CyberpunkTheme.yellowPrimary,
                                action: { privacySettings.emojiPreset = .crypto }
                            )
                            
                            CyberpunkEmojiPresetCard(
                                emojis: "🔥⚡✨",
                                title: "Custom",
                                subtitle: "Your own mix",
                                isSelected: privacySettings.emojiPreset == .custom,
                                color: CyberpunkTheme.purplePrimary,
                                action: { privacySettings.emojiPreset = .custom }
                            )
                        }
                        
                        // Preview
                        CyberpunkPreviewCard()
                    }
                }
            }
        }
    }
}

// MARK: - Notifications Content
struct CyberpunkNotificationsContent: View {
    @ObservedObject private var notificationService = NotificationService.shared
    
    @State private var workStartEnabled = true
    @State private var workEndEnabled = true
    @State private var overtimeEnabled = true
    @State private var soundEnabled = true
    @State private var workEndMinutes = 15
    @State private var permissionDenied = false
    @State private var isRequestingPermission = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Permission Status - Show when not granted
            if !notificationService.permissionGranted {
                CyberpunkSettingsCard(borderColor: permissionDenied ? CyberpunkTheme.redPrimary : CyberpunkTheme.yellowPrimary) {
                    HStack(spacing: 12) {
                        CyberpunkIconBadge(
                            icon: permissionDenied ? "xmark.circle.fill" : "exclamationmark.triangle.fill",
                            color: permissionDenied ? CyberpunkTheme.redPrimary : CyberpunkTheme.yellowPrimary
                        )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(permissionDenied ? "Notifications Blocked" : "Notifications Disabled")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text(permissionDenied 
                                 ? "Please enable notifications in System Settings"
                                 : "Click to enable notification permissions")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        if permissionDenied {
                            // If denied, show button to open System Settings
                            Button("Open Settings") {
                                notificationService.openNotificationSettings()
                            }
                            .buttonStyle(CyberpunkButtonStyle(color: CyberpunkTheme.cyanPrimary))
                        } else {
                            // Request permission
                            Button(isRequestingPermission ? "Requesting..." : "Enable") {
                                requestNotificationPermission()
                            }
                            .buttonStyle(CyberpunkButtonStyle(color: CyberpunkTheme.yellowPrimary))
                            .disabled(isRequestingPermission)
                        }
                    }
                }
            } else {
                // Permission granted status
                CyberpunkSettingsCard(borderColor: CyberpunkTheme.greenPrimary) {
                    HStack(spacing: 12) {
                        CyberpunkIconBadge(icon: "checkmark.circle.fill", color: CyberpunkTheme.greenPrimary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifications Enabled")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text("You will receive work reminders and alerts")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Button("Manage") {
                            notificationService.openNotificationSettings()
                        }
                        .buttonStyle(CyberpunkButtonStyle(color: CyberpunkTheme.greenPrimary))
                    }
                }
            }
            
            // Work Reminders Section
            CyberpunkDeepLinkSection(
                icon: "clock.fill",
                title: "Work Reminders",
                color: CyberpunkTheme.yellowPrimary
            ) {
                VStack(spacing: 16) {
                    // Work Start Reminder
                    CyberpunkSettingsCard {
                        HStack(spacing: 12) {
                            CyberpunkIconBadge(icon: "sunrise.fill", color: CyberpunkTheme.yellowPrimary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Work Start Reminder")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("Notify 5 minutes before work starts")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $workStartEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: CyberpunkTheme.yellowPrimary))
                                .scaleEffect(0.8)
                                .disabled(!notificationService.permissionGranted)
                        }
                    }
                    
                    // Work End Reminder
                    CyberpunkSettingsCard {
                        HStack(spacing: 12) {
                            CyberpunkIconBadge(icon: "sunset.fill", color: CyberpunkTheme.orangePrimary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Work End Reminder")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("Notify before work hours end")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $workEndEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: CyberpunkTheme.orangePrimary))
                                .scaleEffect(0.8)
                                .disabled(!notificationService.permissionGranted)
                        }
                    }
                    
                    if workEndEnabled && notificationService.permissionGranted {
                        // Reminder Time Offset
                        CyberpunkSettingsCard {
                            HStack(spacing: 12) {
                                CyberpunkIconBadge(icon: "timer", color: CyberpunkTheme.cyanPrimary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Reminder Time")
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    Text("Minutes before work ends")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundColor(.gray.opacity(0.6))
                                }
                                
                                Spacer()
                                
                                CyberpunkStepper(value: $workEndMinutes, range: 5...60)
                            }
                        }
                    }
                    
                    // Overtime Warning
                    CyberpunkSettingsCard {
                        HStack(spacing: 12) {
                            CyberpunkIconBadge(icon: "exclamationmark.triangle.fill", color: CyberpunkTheme.redPrimary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Overtime Warning")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("Remind you when working overtime")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $overtimeEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: CyberpunkTheme.redPrimary))
                                .scaleEffect(0.8)
                                .disabled(!notificationService.permissionGranted)
                        }
                    }
                }
            }
            
            // Sound Settings
            CyberpunkDeepLinkSection(
                icon: "speaker.wave.2.fill",
                title: "Sound",
                color: CyberpunkTheme.purplePrimary
            ) {
                CyberpunkSettingsCard {
                    HStack(spacing: 12) {
                        CyberpunkIconBadge(icon: "speaker.wave.2.fill", color: CyberpunkTheme.purplePrimary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notification Sound")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text("Play sound with notifications")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $soundEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: CyberpunkTheme.purplePrimary))
                            .scaleEffect(0.8)
                    }
                }
            }
        }
        .onAppear {
            loadNotificationSettings()
            checkPermissionStatus()
        }
        .onChange(of: workStartEnabled) { _, _ in saveNotificationSettings() }
        .onChange(of: workEndEnabled) { _, _ in saveNotificationSettings() }
        .onChange(of: overtimeEnabled) { _, _ in saveNotificationSettings() }
        .onChange(of: soundEnabled) { _, _ in saveNotificationSettings() }
        .onChange(of: workEndMinutes) { _, _ in saveNotificationSettings() }
    }
    
    private func requestNotificationPermission() {
        isRequestingPermission = true
        Task {
            let granted = await notificationService.requestPermissions()
            await MainActor.run {
                isRequestingPermission = false
                if !granted {
                    // Check if it was denied vs just not granted yet
                    Task {
                        permissionDenied = await notificationService.checkIfDenied()
                    }
                }
            }
        }
    }
    
    private func checkPermissionStatus() {
        Task {
            permissionDenied = await notificationService.checkIfDenied()
        }
    }
    
    private func loadNotificationSettings() {
        let prefs = notificationService.preferences
        workStartEnabled = prefs.workStartEnabled
        workEndEnabled = prefs.workEndEnabled
        overtimeEnabled = prefs.overtimeWarningEnabled
        soundEnabled = prefs.soundEnabled
        workEndMinutes = prefs.workEndReminderMinutes
    }
    
    private func saveNotificationSettings() {
        var prefs = NotificationPreferences()
        prefs.workStartEnabled = workStartEnabled
        prefs.workEndEnabled = workEndEnabled
        prefs.overtimeWarningEnabled = overtimeEnabled
        prefs.soundEnabled = soundEnabled
        prefs.workEndReminderMinutes = workEndMinutes
        notificationService.setNotificationPreferences(prefs)
    }
}

// MARK: - Shortcut Row
struct CyberpunkShortcutRow: View {
    let title: String
    let description: String
    let shortcut: String
    
    var body: some View {
        CyberpunkSettingsCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(description)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.6))
                }
                
                Spacer()
                
                // Shortcut Badge
                Text(shortcut)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberpunkTheme.yellowPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(CyberpunkTheme.yellowPrimary.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(CyberpunkTheme.yellowPrimary.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Cyberpunk Button Style
struct CyberpunkButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundColor(configuration.isPressed ? .black : color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? color : color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
    }
}

// MARK: - Advanced Content
struct CyberpunkAdvancedContent: View {
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared
    @ObservedObject private var shortcutManager = KeyboardShortcutManager.shared
    
    @State private var showResetConfirmation = false
    @State private var updateInterval: Int = 1
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Data Management Section
            CyberpunkDeepLinkSection(
                icon: "externaldrive.fill",
                title: "Data Management",
                color: CyberpunkTheme.purplePrimary
            ) {
                // Reset All Settings
                CyberpunkSettingsCard(borderColor: CyberpunkTheme.redPrimary) {
                    HStack(spacing: 12) {
                        CyberpunkIconBadge(icon: "trash.fill", color: CyberpunkTheme.redPrimary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reset All Settings")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text("Clear all data and restore defaults")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Button("Reset") {
                            showResetConfirmation = true
                        }
                        .buttonStyle(CyberpunkButtonStyle(color: CyberpunkTheme.redPrimary))
                    }
                }
            }
            
            // Performance Section
            CyberpunkDeepLinkSection(
                icon: "gauge.with.dots.needle.67percent",
                title: "Performance",
                color: CyberpunkTheme.cyanPrimary
            ) {
                VStack(spacing: 16) {
                    // Update Interval
                    CyberpunkSettingsCard {
                        HStack(spacing: 12) {
                            CyberpunkIconBadge(icon: "clock.arrow.circlepath", color: CyberpunkTheme.yellowPrimary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Update Interval")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("How often to refresh income (seconds)")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            CyberpunkStepper(value: $updateInterval, range: 1...60, unit: "sec")
                        }
                    }
                    
                    // Auto Start (Launch at Login)
                    CyberpunkSettingsCard {
                        HStack(spacing: 12) {
                            CyberpunkIconBadge(icon: "power", color: CyberpunkTheme.greenPrimary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Launch at Login")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("Start Paytick when you log in")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $launchAtLogin.isEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: CyberpunkTheme.greenPrimary))
                                .scaleEffect(0.8)
                        }
                    }
                }
            }
            
            // Keyboard Shortcuts Section - Only Privacy Toggle (customizable)
            CyberpunkDeepLinkSection(
                icon: "keyboard",
                title: "Keyboard Shortcuts",
                color: CyberpunkTheme.yellowPrimary
            ) {
                CyberpunkSettingsCard {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            CyberpunkIconBadge(icon: "eye.slash.fill", color: CyberpunkTheme.purplePrimary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Toggle Privacy Mode")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("Quickly hide/show income data")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            // Current shortcut display / recording button
                            Button(action: {
                                if shortcutManager.isRecordingShortcut {
                                    shortcutManager.cancelRecording()
                                } else {
                                    shortcutManager.startRecording()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    if shortcutManager.isRecordingShortcut {
                                        Text("Press keys...")
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundColor(CyberpunkTheme.yellowPrimary)
                                    } else {
                                        Text(shortcutManager.togglePrivacyShortcut.displayString)
                                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(shortcutManager.isRecordingShortcut 
                                              ? CyberpunkTheme.yellowPrimary.opacity(0.2) 
                                              : Color.white.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(shortcutManager.isRecordingShortcut 
                                                ? CyberpunkTheme.yellowPrimary 
                                                : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Help text and reset button
                        HStack {
                            Text("Click the shortcut to customize")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Spacer()
                            
                            Button("Reset to ⌃⌥P") {
                                shortcutManager.resetToDefault()
                            }
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(CyberpunkTheme.cyanPrimary.opacity(0.7))
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            
            // Debug Section
            CyberpunkDeepLinkSection(
                icon: "ant.fill",
                title: "Debug",
                color: CyberpunkTheme.orangePrimary
            ) {
                CyberpunkSettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("App Version")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.6))
                            Spacer()
                            Text("1.0.0 (Build 1)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(CyberpunkTheme.cyanPrimary)
                        }
                        
                        Divider().background(CyberpunkTheme.greenPrimary.opacity(0.2))
                        
                        HStack {
                            Text("macOS Version")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.6))
                            Spacer()
                            Text(ProcessInfo.processInfo.operatingSystemVersionString)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(CyberpunkTheme.cyanPrimary)
                        }
                        
                        Divider().background(CyberpunkTheme.greenPrimary.opacity(0.2))
                        
                        HStack {
                            Text("Data Storage")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.6))
                            Spacer()
                            Text("UserDefaults")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(CyberpunkTheme.cyanPrimary)
                        }
                    }
                }
            }
        }
        .onAppear {
            loadAdvancedSettings()
        }
        .onChange(of: updateInterval) { _, _ in saveAdvancedSettings() }
        .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("This will clear all your configuration data. This action cannot be undone.")
        }
    }
    
    private func loadAdvancedSettings() {
        updateInterval = UserDefaults.standard.integer(forKey: "updateInterval")
        if updateInterval == 0 { updateInterval = 1 }
        // Launch at login is managed by LaunchAtLoginManager
        launchAtLogin.refreshStatus()
    }
    
    private func saveAdvancedSettings() {
        UserDefaults.standard.set(updateInterval, forKey: "updateInterval")
        // Launch at login is automatically saved by LaunchAtLoginManager
    }
    
    private func resetAllSettings() {
        // Clear all UserDefaults
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        
        // Reset state
        updateInterval = 1
        launchAtLogin.isEnabled = false
        shortcutManager.resetToDefault()
    }
}

// MARK: - Reusable Components

struct CyberpunkDeepLinkSection<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
            
            content()
        }
    }
}

struct CyberpunkSettingsCard<Content: View>: View {
    var borderColor: Color = CyberpunkTheme.greenPrimary
    @ViewBuilder let content: () -> Content
    
    @State private var isHovered = false
    
    var body: some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHovered ? borderColor.opacity(0.4) : borderColor.opacity(0.2), lineWidth: 1)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
    }
}

struct CyberpunkIconBadge: View {
    let icon: String
    let color: Color
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 14))
            .foregroundColor(color)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(color.opacity(0.1))
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}

struct CyberpunkMiniIconBadge: View {
    var emoji: String? = nil
    var icon: String? = nil
    let color: Color
    
    var body: some View {
        Group {
            if let emoji = emoji {
                Text(emoji)
                    .font(.system(size: 12))
            } else if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
            }
        }
        .frame(width: 24, height: 24)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct CyberpunkTextInput: View {
    @Binding var text: String
    let placeholder: String
    var suffix: String? = nil
    let color: Color
    
    @State private var isFocused = false
    
    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
            
            if let suffix = suffix {
                Text(suffix)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(color.opacity(0.5))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? color : color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: isFocused ? color.opacity(0.3) : .clear, radius: 15)
        .onTapGesture { isFocused = true }
    }
}

struct CyberpunkStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var unit: String = "min"  // Default to minutes
    
    var body: some View {
        HStack(spacing: 8) {
            Text("\(value) \(unit)")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .frame(minWidth: 80, alignment: .leading)
            
            VStack(spacing: 2) {
                Button(action: { if value < range.upperBound { value += 1 } }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(CyberpunkTheme.cyanPrimary)
                }
                .buttonStyle(.plain)
                
                Button(action: { if value > range.lowerBound { value -= 1 } }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(CyberpunkTheme.cyanPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(CyberpunkTheme.cyanPrimary.opacity(0.3), lineWidth: 1)
        )
    }
}

struct CyberpunkTimePicker: View {
    @Binding var time: Date
    let color: Color
    
    // Static formatter to avoid recreation on each view update
    // Use HH:mm for 24-hour format to ensure consistent string length
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    // Computed property for formatted time string
    private var formattedTime: String {
        Self.timeFormatter.string(from: time)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Time display with fixed width to prevent layout shifts
            Text(formattedTime)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 50, alignment: .leading)
                .animation(nil, value: formattedTime) // Disable animation for time text
            
            Spacer()
            
            // DatePicker wrapped in a fixed frame to prevent jitter
            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .colorScheme(.dark)
                .frame(width: 80, height: 30)
                .fixedSize()
                .animation(nil, value: time) // Disable animation for picker changes
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(height: 50) // Fixed height for the entire component
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .animation(nil, value: time) // Disable any implicit animations
    }
}

struct CyberpunkWeekdaySelector: View {
    @Binding var selectedDays: Set<String>
    
    let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.self) { day in
                Button(action: {
                    if selectedDays.contains(day) {
                        selectedDays.remove(day)
                    } else {
                        selectedDays.insert(day)
                    }
                }) {
                    Text(day)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(selectedDays.contains(day) ? CyberpunkTheme.greenPrimary : .gray.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedDays.contains(day) ? CyberpunkTheme.greenPrimary.opacity(0.2) : Color.gray.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    selectedDays.contains(day) ? CyberpunkTheme.greenPrimary.opacity(0.5) : Color.gray.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: selectedDays.contains(day) ? CyberpunkTheme.greenPrimary.opacity(0.3) : .clear, radius: 15)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct CyberpunkPrivacyModeOption: View {
    let title: String
    let description: String
    var example: String? = nil
    var isBlurExample: Bool = false
    let isSelected: Bool
    var isRecommended: Bool = false
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? color.opacity(0.2) : Color.gray.opacity(0.1))
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? color.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
                    
                    if isSelected {
                        Text("✓")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(color)
                    }
                }
                .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        if isRecommended {
                            Text("RECOMMENDED")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(CyberpunkTheme.greenPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(CyberpunkTheme.greenPrimary.opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(CyberpunkTheme.greenPrimary.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    
                    Text(description)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    if let example = example {
                        Text(example)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.black.opacity(0.6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(color.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .padding(.top, 4)
                    }
                    
                    if isBlurExample {
                        Text("¥12,345.00")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(color)
                            .blur(radius: 4)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.black.opacity(0.6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(color.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .padding(.top, 4)
                    }
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color.opacity(0.5) : color.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: isSelected ? color.opacity(0.2) : .clear, radius: 20)
        }
        .buttonStyle(.plain)
    }
}

struct CyberpunkEmojiPresetCard: View {
    let emojis: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(emojis)
                    .font(.system(size: 24))
                
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: isSelected ? color.opacity(0.15) : .clear, radius: 15)
        }
        .buttonStyle(.plain)
    }
}

struct CyberpunkPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 10))
                    .foregroundColor(CyberpunkTheme.yellowPrimary.opacity(0.6))
                Text("PREVIEW")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberpunkTheme.yellowPrimary.opacity(0.6))
            }
            
            VStack(spacing: 8) {
                CyberpunkPreviewRow(original: "¥12,345", converted: "🚀🚀⭐✨")
                CyberpunkPreviewRow(original: "¥5,670", converted: "🚀⭐✨")
                CyberpunkPreviewRow(original: "¥520", converted: "⭐✨")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(CyberpunkTheme.yellowPrimary.opacity(0.2), lineWidth: 1)
        )
    }
}

struct CyberpunkPreviewRow: View {
    let original: String
    let converted: String
    
    var body: some View {
        HStack {
            Text(original)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("→")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.gray.opacity(0.4))
            
            Spacer()
            
            Text(converted)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

