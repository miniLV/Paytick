# Settings Interface Redesign Specification

## Overview
Complete redesign of the Paytick settings interface following modern macOS design patterns with sidebar navigation and organized content sections.

## User Stories

### Epic: Settings Interface Modernization
As a user, I want a clean, organized settings interface that allows me to easily configure my income tracking preferences and privacy options.

#### User Story 1: Sidebar Navigation
- **AS A** user
- **I WANT TO** navigate between different settings categories using a sidebar
- **SO THAT** I can quickly access the settings I need without confusion

**Acceptance Criteria:**
- [ ] Sidebar displays clear category icons and labels
- [ ] Active category is visually highlighted
- [ ] Smooth transitions between categories
- [ ] Sidebar is consistently styled with app theme

#### User Story 2: Personal Information Settings
- **AS A** user  
- **I WANT TO** easily configure my salary, work days, and schedule
- **SO THAT** my income calculations are accurate

**Acceptance Criteria:**
- [ ] Clean input fields for monthly salary
- [ ] Intuitive work days configuration
- [ ] Daily hours slider with real-time feedback
- [ ] Value goal setting with description
- [ ] Form validation and error states

#### User Story 3: Privacy Protection
- **AS A** user
- **I WANT** privacy settings to hide my salary information
- **SO THAT** colleagues cannot see my actual income when looking at my screen

**Acceptance Criteria:**
- [ ] Toggle to enable/disable privacy mode
- [ ] Configurable privacy symbols (dots, asterisks, etc.)
- [ ] Quick privacy toggle from main interface
- [ ] Privacy state persists between sessions
- [ ] Clear indication when privacy mode is active

#### User Story 4: Visual Polish
- **AS A** user
- **I WANT** the settings interface to feel cohesive with the main app
- **SO THAT** the experience feels professional and polished

**Acceptance Criteria:**
- [ ] Consistent color scheme and typography
- [ ] Smooth animations and transitions
- [ ] Proper spacing and alignment
- [ ] Responsive layout for different window sizes

## Technical Implementation Plan

### Phase 1: Settings Architecture
**Objective:** Create the foundation for the new settings system

**Tasks:**
1. Create `SettingsView` main container
2. Implement sidebar navigation component
3. Set up routing between settings categories
4. Create base settings page protocol

**Implementation:**
```swift
// New settings structure
struct SettingsView: View {
    @State private var selectedCategory: SettingsCategory = .personalInfo
    
    var body: some View {
        HSplitView {
            SettingsSidebar(selectedCategory: $selectedCategory)
                .frame(width: 200)
            
            SettingsContentView(category: selectedCategory)
                .frame(minWidth: 400)
        }
    }
}

enum SettingsCategory: CaseIterable {
    case personalInfo
    case privacy
    case notifications
    case advanced
    
    var title: String { ... }
    var icon: String { ... }
}
```

### Phase 2: Sidebar Navigation
**Objective:** Create intuitive category navigation

**Tasks:**
1. Design sidebar with icons and labels
2. Implement selection states and hover effects
3. Add smooth transition animations
4. Ensure accessibility support

**Implementation:**
```swift
struct SettingsSidebar: View {
    @Binding var selectedCategory: SettingsCategory
    
    var body: some View {
        VStack(spacing: 4) {
            ForEach(SettingsCategory.allCases, id: \.self) { category in
                SettingsSidebarItem(
                    category: category,
                    isSelected: selectedCategory == category,
                    action: { selectedCategory = category }
                )
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
```

### Phase 3: Personal Information Settings
**Objective:** Redesign the main configuration interface

**Tasks:**
1. Create clean input field components
2. Implement work schedule configuration
3. Add value goal setting interface
4. Include form validation and feedback

**Implementation:**
```swift
struct PersonalInfoSettingsView: View {
    @ObservedObject var viewModel: EnhancedIncomeViewModel
    @State private var monthlySalary: String = ""
    @State private var workDays: Int = 22
    @State private var dailyHours: Double = 8.0
    @State private var valueGoal: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsSection("Financial Information") {
                    SalaryInputField(value: $monthlySalary)
                    WorkDaysInputField(value: $workDays)
                }
                
                SettingsSection("Work Schedule") {
                    DailyHoursSlider(value: $dailyHours)
                    WorkTimeConfiguration()
                }
                
                SettingsSection("Goals") {
                    ValueGoalConfiguration(goal: $valueGoal)
                }
            }
            .padding(24)
        }
    }
}
```

### Phase 4: Privacy Settings Implementation
**Objective:** Add comprehensive privacy protection

**Tasks:**
1. Create privacy mode toggle interface
2. Implement privacy symbol configuration
3. Add quick access privacy controls
4. Ensure privacy state management

**Implementation:**
```swift
struct PrivacySettingsView: View {
    @ObservedObject var privacySettings: PrivacySettings
    
    var body: some View {
        VStack(spacing: 24) {
            SettingsSection("Privacy Protection") {
                Toggle("Enable Privacy Mode", isOn: $privacySettings.isPrivacyModeEnabled)
                    .toggleStyle(SwitchToggleStyle())
                
                if privacySettings.isPrivacyModeEnabled {
                    PrivacySymbolPicker(selectedSymbol: $privacySettings.privacySymbol)
                    PrivacyPreview(symbol: privacySettings.privacySymbol)
                }
            }
            
            SettingsSection("Quick Access") {
                Text("Add privacy toggle to menu bar")
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
    }
}
```

## Visual Design Specifications

### Layout Structure
- **Sidebar width:** 200px fixed
- **Content area:** Minimum 400px width, expandable
- **Section spacing:** 24px between major sections
- **Item spacing:** 12px between related items

### Color Scheme
- **Background:** System background colors
- **Sidebar:** Control background color
- **Accent:** App's signature green for active states
- **Text:** Primary and secondary text colors

### Typography
- **Section headers:** System font, 16pt, semibold
- **Labels:** System font, 13pt, medium
- **Input text:** System font, 13pt, regular
- **Help text:** System font, 11pt, regular, secondary color

### Interactive Elements
- **Input fields:** Rounded corners, focus states
- **Sliders:** Custom styling matching app theme
- **Buttons:** Consistent with main app styling
- **Toggles:** Native macOS switch style

## Component Architecture

### Base Components
```swift
// Reusable settings components
struct SettingsSection<Content: View>: View
struct SettingsInputField: View
struct SettingsSlider: View
struct SettingsToggle: View
```

### Settings Categories
```swift
// Individual settings pages
struct PersonalInfoSettingsView: View
struct PrivacySettingsView: View
struct NotificationSettingsView: View
struct AdvancedSettingsView: View
```

## Testing Criteria

### Functional Tests
- [ ] All input fields accept and validate data correctly
- [ ] Privacy mode toggles work across the application
- [ ] Settings persist between app sessions
- [ ] Form validation provides clear feedback

### Visual Tests
- [ ] Interface scales properly with window resizing
- [ ] All animations are smooth and purposeful
- [ ] Color contrast meets accessibility standards
- [ ] Typography is consistent and readable

### Integration Tests
- [ ] Settings changes reflect immediately in main interface
- [ ] Privacy mode affects all income displays
- [ ] Data synchronization works correctly

## Implementation Priority

1. **High:** Basic settings architecture and sidebar
2. **High:** Personal information settings redesign
3. **High:** Privacy settings implementation
4. **Medium:** Visual polish and animations
5. **Low:** Advanced settings and customization

## Success Metrics

- [ ] Settings interface feels intuitive and modern
- [ ] Privacy protection works seamlessly
- [ ] User can configure all necessary options easily
- [ ] Interface maintains app's visual consistency
- [ ] Zero crashes or data loss during configuration

## Future Enhancements

- Keyboard shortcuts for quick settings access
- Import/export settings functionality
- Advanced privacy modes (blur, custom symbols)
- Workflow automation settings
- Multiple profile support