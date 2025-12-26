# Glass-Style Titlebar Implementation Specification

## Overview
Implementation of a glass-style titlebar that displays key income information directly in the window's titlebar area while maintaining native macOS functionality.

## User Stories

### Epic: Glass Titlebar with Income Display
As a user, I want key income information displayed in a beautiful glass-style titlebar so I can see my earnings at a glance without taking up main content space.

#### User Story 1: Real-Time Income Display in Titlebar
- **AS A** user
- **I WANT TO** see my current daily income prominently displayed in the titlebar
- **SO THAT** I can monitor my earnings without looking away from other work

**Acceptance Criteria:**
- [ ] Daily income (¥11118.46) displayed prominently in titlebar center
- [ ] Income updates in real-time as work progresses
- [ ] Text is large enough to read clearly (minimum 24px)
- [ ] Currency symbol (¥) is clearly visible

#### User Story 2: Minute Rate and Monthly Progress in Titlebar
- **AS A** user
- **I WANT TO** see my per-minute rate and monthly progress in the titlebar
- **SO THAT** I have quick access to key metrics

**Acceptance Criteria:**
- [ ] Per-minute rate (¥2.00/min) displayed below main income
- [ ] Monthly accumulated income (本月累计: ¥9028) shown as subtitle
- [ ] Text hierarchy is clear with appropriate font sizes
- [ ] Information updates automatically

#### User Story 3: Visual Wave Animation
- **AS A** user
- **I WANT TO** see an animated wave effect in the titlebar
- **SO THAT** the interface feels alive and engaging

**Acceptance Criteria:**
- [ ] Animated wave effect at bottom of titlebar
- [ ] Wave colors match design (purple, cyan, teal gradients)
- [ ] Animation is smooth and not distracting
- [ ] Wave effect can be disabled for performance if needed

#### User Story 4: Glass Effect Background
- **AS A** user
- **I WANT** a beautiful glass effect background in the titlebar
- **SO THAT** the interface feels modern and premium

**Acceptance Criteria:**
- [ ] Titlebar has translucent glass background effect
- [ ] Background gradient matches design (blue to purple)
- [ ] Glass effect provides enough contrast for text readability
- [ ] Effect works with different desktop backgrounds

#### User Story 5: App Branding Integration
- **AS A** user
- **I WANT TO** see the Paytick logo and name in the titlebar
- **SO THAT** I can identify the application clearly

**Acceptance Criteria:**
- [ ] Paytick logo displayed in top-left of titlebar
- [ ] App name "Paytick" shown next to logo
- [ ] Branding doesn't interfere with system traffic light buttons
- [ ] Logo is crisp at all display densities

## Technical Implementation Plan

### Phase 1: Titlebar Structure Setup
**Objective:** Create expandable titlebar structure with proper spacing

**Tasks:**
1. Increase titlebar height from 44px to 120px to accommodate content
2. Ensure proper spacing for traffic light buttons
3. Create layout zones for different content areas

**Implementation:**
```swift
// Expand titlebar height in ContentView.swift
window.titlebarAppearsTransparent = true
window.titleVisibility = .hidden

// Custom titlebar view with expanded height
struct GlassTitleBar: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top section with traffic light space and branding
            HStack {
                Color.clear.frame(width: 70, height: 28) // Traffic light space
                
                // App branding
                HStack(spacing: 8) {
                    Image("app-icon")
                        .resizable()
                        .frame(width: 20, height: 20)
                    Text("Paytick")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
            .frame(height: 28)
            
            // Main content section with income data
            VStack(spacing: 4) {
                // Large income amount
                Text("¥11118.46")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                // Per minute rate
                Text("¥2.00 /min")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                // Monthly progress
                Text("本月累计: ¥9028")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            
            // Wave animation section
            WaveAnimationView()
                .frame(height: 20)
        }
        .frame(height: 120)
        .background(GlassBackgroundView())
    }
}
```

### Phase 2: Glass Background Effect
**Objective:** Create realistic glass background with gradient and blur

**Tasks:**
1. Implement gradient background (blue to purple)
2. Add blur/translucency effect
3. Ensure readability of overlaid text
4. Optimize for performance

**Implementation:**
```swift
struct GlassBackgroundView: View {
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.4, green: 0.6, blue: 1.0),  // Light blue
                    Color(red: 0.6, green: 0.4, blue: 1.0)   // Purple
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Glass effect overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.3)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}
```

### Phase 3: Wave Animation Implementation
**Objective:** Create smooth, appealing wave animation

**Tasks:**
1. Design wave path using SwiftUI Path
2. Implement smooth animation loop
3. Add gradient coloring to waves
4. Optimize animation performance

**Implementation:**
```swift
struct WaveAnimationView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    WavePath(
                        offset: animationOffset + CGFloat(index) * 0.3,
                        amplitude: 8 - CGFloat(index) * 2,
                        frequency: 0.02 + Double(index) * 0.005
                    )
                    .fill(
                        LinearGradient(
                            colors: waveColors(for: index),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(0.7 - Double(index) * 0.2)
                }
            }
        }
        .onAppear {
            withAnimation(
                Animation.linear(duration: 3.0).repeatForever(autoreverses: false)
            ) {
                animationOffset = geometry.size.width
            }
        }
    }
    
    private func waveColors(for index: Int) -> [Color] {
        switch index {
        case 0: return [Color.purple, Color.cyan]
        case 1: return [Color.cyan, Color.teal]
        default: return [Color.teal, Color.blue]
        }
    }
}

struct WavePath: Shape {
    let offset: CGFloat
    let amplitude: CGFloat
    let frequency: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: 0, y: height / 2))
        
        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let sine = sin(relativeX * frequency * 2 * .pi + offset * 0.05)
            let y = amplitude * sine + height / 2
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        return path
    }
}
```

### Phase 4: Data Integration
**Objective:** Connect titlebar display to real income data

**Tasks:**
1. Bind titlebar components to EnhancedIncomeViewModel
2. Ensure real-time updates
3. Handle privacy mode integration
4. Add proper error states

**Implementation:**
```swift
struct GlassTitleBar: View {
    @ObservedObject var viewModel: EnhancedIncomeViewModel
    @ObservedObject var privacySettings: PrivacySettings
    @StateObject private var iconSettings = PrivacyIconSettings()
    
    private func formatIncome(_ amount: Double) -> String {
        if privacySettings.isPrivacyModeEnabled {
            return iconSettings.formatAmount(amount)
        }
        return String(format: "%.2f", amount)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ... existing layout
            
            // Income display with real data
            VStack(spacing: 4) {
                Text("¥\(formatIncome(viewModel.getValueStreamIncome()))")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("¥\(formatIncome(viewModel.getValueStreamMinuteRate())) /min")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("本月累计: ¥\(formatIncome(viewModel.getMonthlyAccumulatedIncome()))")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // ... wave animation
        }
    }
}
```

### Phase 5: Integration and Polish
**Objective:** Integrate with existing app and add polish

**Tasks:**
1. Update MainValueWindow to use new titlebar
2. Adjust content layout to account for expanded titlebar
3. Add hover states and interactions
4. Perform accessibility testing

## Visual Design Specifications

### Layout Dimensions
- **Total titlebar height:** 120px
- **Traffic light area:** 70px × 28px (top-left)
- **Main content area:** Full width × 64px (center)
- **Wave animation area:** Full width × 20px (bottom)
- **Corner radius:** 12px (matches window)

### Typography
- **Main income:** 32px, Bold, White
- **Per-minute rate:** 16px, Medium, White 90%
- **Monthly total:** 14px, Regular, White 80%
- **App name:** 14px, Medium, White

### Colors and Effects
- **Background gradient:** Blue (#66A3FF) to Purple (#9966FF)
- **Glass overlay:** ultraThinMaterial at 30% opacity
- **Wave colors:** Purple → Cyan → Teal gradients
- **Text shadows:** Subtle dark shadow for legibility

### Animation Specifications
- **Wave animation:** 3-second linear loop, continuous
- **Income updates:** 0.3-second easeInOut transition
- **Hover effects:** 0.2-second easeOut

## Required Resources

### Assets Needed
- [ ] High-resolution app icon (20×20, 40×40 for retina)
- [ ] Icon font or SF Symbols for currency symbols
- [ ] Color palette definitions in DesignSystem

### Dependencies
- [ ] Existing EnhancedIncomeViewModel integration
- [ ] Privacy settings compatibility
- [ ] Value stream calculator connection

### Technical Requirements
- [ ] macOS 14.0+ for advanced material effects
- [ ] SwiftUI 5.0+ for complex animations
- [ ] Metal performance shaders (optional for advanced effects)

## Testing Criteria

### Functional Tests
- [ ] Income data updates in real-time in titlebar
- [ ] Privacy mode works correctly in titlebar display
- [ ] Window dragging still works with expanded titlebar
- [ ] All window controls (close, minimize, maximize) function
- [ ] Animation performance is smooth (60fps)

### Visual Tests
- [ ] Text is legible on various desktop backgrounds
- [ ] Wave animation doesn't cause seizure risk
- [ ] Glass effect looks professional
- [ ] Layout works on different screen sizes
- [ ] Retina display optimization

### Accessibility Tests
- [ ] VoiceOver can read income information
- [ ] High contrast mode compatibility
- [ ] Reduced motion mode disables animations
- [ ] Keyboard navigation support

## Performance Considerations

### Memory Usage
- [ ] Wave animation uses efficient rendering
- [ ] No memory leaks from continuous updates
- [ ] Proper cleanup when window closes

### CPU Usage
- [ ] Animation doesn't exceed 5% CPU on modern Macs
- [ ] Real-time updates don't cause UI lag
- [ ] Efficient text formatting and updates

## Implementation Priority

1. **Critical:** Basic titlebar layout with income display
2. **High:** Glass background effect implementation  
3. **High:** Data binding to real income information
4. **Medium:** Wave animation implementation
5. **Medium:** Privacy mode integration
6. **Low:** Advanced visual polish and micro-interactions

## Success Metrics

- [ ] Titlebar displays all key income information clearly
- [ ] Glass effect matches design vision closely
- [ ] Real-time updates work without performance issues
- [ ] User can still interact with window controls normally
- [ ] Overall user experience feels premium and polished

## Risk Mitigation

### Technical Risks
- **Window control interference:** Test extensively, provide fallback titlebar
- **Performance on older Macs:** Provide simplified mode for older hardware
- **Privacy mode compatibility:** Ensure emoji formatting works in titlebar context

### UX Risks  
- **Information overload:** Ensure layout hierarchy guides attention properly
- **Readability issues:** Test on various backgrounds, provide fallback themes
- **Animation distraction:** Allow disabling animations in settings