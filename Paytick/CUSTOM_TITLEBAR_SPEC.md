# Custom Title Bar Implementation Specification

## Overview
Implementation of a custom macOS title bar for Paytick application with native dragging functionality and system-style controls.

## User Stories

### Epic: Custom Title Bar Implementation
As a user, I want a custom title bar that looks integrated with the app design while maintaining native macOS functionality.

#### User Story 1: Window Dragging
- **AS A** user
- **I WANT TO** drag the window by clicking and holding anywhere on the title bar area
- **SO THAT** I can move the window around my desktop naturally

**Acceptance Criteria:**
- [ ] Title bar responds to mouse down events for dragging
- [ ] Window moves smoothly following cursor movement
- [ ] Dragging works across the entire width of the title bar
- [ ] No visual glitches during drag operations

#### User Story 2: Window Controls
- **AS A** user  
- **I WANT** functional window control buttons
- **SO THAT** I can close, minimize, or manage the window

**Acceptance Criteria:**
- [ ] Red close button closes the application
- [ ] Yellow minimize button minimizes to dock
- [ ] Green maximize button toggles fullscreen (optional)
- [ ] Buttons have hover effects
- [ ] Buttons are positioned at standard macOS locations

#### User Story 3: Visual Integration
- **AS A** user
- **I WANT** the title bar to visually integrate with the app content
- **SO THAT** the interface feels cohesive and modern

**Acceptance Criteria:**
- [ ] Title bar has the same dark theme as content
- [ ] No visible border between title bar and content
- [ ] Proper corner radius to match window design
- [ ] Traffic light buttons positioned correctly

## Technical Implementation Plan

### Phase 1: Window Configuration
**Objective:** Set up borderless window with custom title bar area

**Tasks:**
1. Modify window style to `.borderless` for full control
2. Add `.titled` back to maintain some system behaviors
3. Configure window to hide standard title bar but keep functionality

**Implementation:**
```swift
// In ContentView.swift - setupWindow()
let window = NSWindow(
    contentRect: NSRect(x: 100, y: 100, width: 800, height: 600),
    styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
    backing: .buffered,
    defer: false
)
window.titlebarAppearsTransparent = true
window.titleVisibility = .hidden
```

### Phase 2: Custom Title Bar View
**Objective:** Create SwiftUI view that acts as native title bar

**Tasks:**
1. Create `CustomTitleBar` SwiftUI component
2. Implement traffic light button positioning
3. Add window dragging gesture handling

**Implementation:**
```swift
struct CustomTitleBar: View {
    var body: some View {
        HStack {
            // Traffic light buttons area (handled by system)
            Color.clear.frame(width: 70, height: 44)
            
            Spacer()
            
            // Optional: App title or controls
        }
        .frame(height: 44)
        .background(Color.clear)
        .contentShape(Rectangle()) // Make entire area draggable
    }
}
```

### Phase 3: Native Window Dragging
**Objective:** Implement smooth window dragging using NSWindow APIs

**Tasks:**
1. Use `NSWindow.performDrag()` for native drag behavior  
2. Handle mouse events through NSView integration
3. Ensure drag gestures don't conflict with button interactions

**Implementation:**
```swift
// Custom NSView for drag handling
class DraggableArea: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

// SwiftUI integration
struct DraggableView: NSViewRepresentable {
    func makeNSView(context: Context) -> DraggableArea {
        DraggableArea()
    }
    
    func updateNSView(_ nsView: DraggableArea, context: Context) {}
}
```

### Phase 4: Window Controls Integration  
**Objective:** Integrate with existing window controls

**Tasks:**
1. Position content to avoid traffic light button area
2. Ensure proper spacing and alignment
3. Test window control functionality

## Visual Design Specifications

### Layout
- **Title bar height:** 44px (standard macOS height)
- **Traffic lights position:** 20px from left edge, vertically centered
- **Content padding:** 70px from left to avoid traffic light overlap

### Colors
- **Background:** Transparent to show content background
- **Traffic lights:** Use system colors for consistency

### Interaction States
- **Hover:** System handles traffic light button hover states
- **Drag cursor:** System provides appropriate cursor during drag

## Testing Criteria

### Functional Tests
- [ ] Window drags smoothly without lag
- [ ] All traffic light buttons work correctly  
- [ ] No interference between drag and button clicks
- [ ] Window maintains proper bounds during drag

### Visual Tests
- [ ] Title bar seamlessly integrates with content
- [ ] Traffic lights positioned correctly
- [ ] No visual artifacts during window operations

### Cross-platform Compatibility
- [ ] Works on macOS 14.0+ (minimum target)
- [ ] Handles different display densities
- [ ] Respects system accessibility settings

## Implementation Priority

1. **High:** Window dragging functionality
2. **High:** Traffic light button integration  
3. **Medium:** Visual polish and animations
4. **Low:** Advanced window management features

## Success Metrics

- [ ] Window dragging works with native system feel
- [ ] Zero crashes related to window management
- [ ] Visual design matches target screenshot
- [ ] All window controls function properly