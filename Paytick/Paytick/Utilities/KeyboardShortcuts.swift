//
//  KeyboardShortcuts.swift
//  Paytick
//
//  Global keyboard shortcuts for Paytick
//

import SwiftUI
import AppKit
import Carbon.HIToolbox

// MARK: - Keyboard Shortcut Manager
class KeyboardShortcutManager: ObservableObject {
    static let shared = KeyboardShortcutManager()
    
    // Primary shortcut: Toggle Privacy Mode (⌃⌥P - Control + Option + P)
    // This is the main shortcut users need for quickly hiding sensitive income data
    @Published var togglePrivacyShortcut: KeyCombo = KeyCombo(key: .p, modifiers: [.control, .option])
    
    // Recording state for shortcut customization
    @Published var isRecordingShortcut: Bool = false
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    // Callback for privacy toggle
    var onTogglePrivacy: (() -> Void)?
    
    private init() {
        loadShortcuts()
        setupGlobalMonitor()
    }
    
    deinit {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func setupGlobalMonitor() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        // Also monitor local events for when app is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if let self = self {
                // If recording, capture the shortcut and don't pass the event
                if self.isRecordingShortcut {
                    self.captureShortcut(from: event)
                    return nil // Consume the event
                }
                self.handleKeyEvent(event)
            }
            return event
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        // Don't handle shortcuts while recording
        guard !isRecordingShortcut else { return }
        
        let pressedCombo = KeyCombo(
            keyCode: event.keyCode,
            modifiers: event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        )
        
        if pressedCombo.matches(togglePrivacyShortcut) {
            onTogglePrivacy?()
        }
    }
    
    /// Captures a new shortcut from a key event during recording
    private func captureShortcut(from event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        // Require at least one modifier key (Control, Option, Command, or Shift)
        guard modifiers.contains(.control) || modifiers.contains(.option) || 
              modifiers.contains(.command) || modifiers.contains(.shift) else {
            return
        }
        
        // Ignore modifier-only key presses
        guard event.keyCode != 0 else { return }
        
        let newCombo = KeyCombo(keyCode: event.keyCode, modifiers: modifiers)
        
        DispatchQueue.main.async {
            self.togglePrivacyShortcut = newCombo
            self.isRecordingShortcut = false
            self.saveShortcuts()
        }
    }
    
    /// Starts recording a new shortcut
    func startRecording() {
        isRecordingShortcut = true
    }
    
    /// Cancels shortcut recording
    func cancelRecording() {
        isRecordingShortcut = false
    }
    
    /// Resets to default shortcut (⌃⌥P)
    func resetToDefault() {
        togglePrivacyShortcut = KeyCombo(key: .p, modifiers: [.control, .option])
        saveShortcuts()
    }
    
    func loadShortcuts() {
        if let data = UserDefaults.standard.data(forKey: "togglePrivacyShortcut"),
           let combo = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            togglePrivacyShortcut = combo
        }
    }
    
    func saveShortcuts() {
        if let data = try? JSONEncoder().encode(togglePrivacyShortcut) {
            UserDefaults.standard.set(data, forKey: "togglePrivacyShortcut")
        }
    }
}

// MARK: - Key Combo
struct KeyCombo: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags
    
    init(key: KeyboardKey, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = key.keyCode
        self.modifiers = modifiers
    }
    
    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
    
    func matches(_ other: KeyCombo) -> Bool {
        return keyCode == other.keyCode && modifiers == other.modifiers
    }
    
    var displayString: String {
        var parts: [String] = []
        
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        
        if let key = KeyboardKey(rawValue: keyCode) {
            parts.append(key.symbol)
        }
        
        return parts.joined()
    }
    
    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case keyCode
        case modifierRawValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        let rawValue = try container.decode(UInt.self, forKey: .modifierRawValue)
        modifiers = NSEvent.ModifierFlags(rawValue: rawValue)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifiers.rawValue, forKey: .modifierRawValue)
    }
}

// MARK: - Keyboard Key
enum KeyboardKey: UInt16 {
    case a = 0
    case s = 1
    case d = 2
    case f = 3
    case h = 4
    case g = 5
    case z = 6
    case x = 7
    case c = 8
    case v = 9
    case b = 11
    case q = 12
    case w = 13
    case e = 14
    case r = 15
    case y = 16
    case t = 17
    case one = 18
    case two = 19
    case three = 20
    case four = 21
    case six = 22
    case five = 23
    case equal = 24
    case nine = 25
    case seven = 26
    case minus = 27
    case eight = 28
    case zero = 29
    case rightBracket = 30
    case o = 31
    case u = 32
    case leftBracket = 33
    case i = 34
    case p = 35
    case returnKey = 36
    case l = 37
    case j = 38
    case quote = 39
    case k = 40
    case semicolon = 41
    case backslash = 42
    case comma = 43
    case slash = 44
    case n = 45
    case m = 46
    case period = 47
    case tab = 48
    case space = 49
    case grave = 50
    case delete = 51
    case escape = 53
    
    var keyCode: UInt16 {
        return rawValue
    }
    
    var symbol: String {
        switch self {
        case .a: return "A"
        case .s: return "S"
        case .d: return "D"
        case .f: return "F"
        case .h: return "H"
        case .g: return "G"
        case .z: return "Z"
        case .x: return "X"
        case .c: return "C"
        case .v: return "V"
        case .b: return "B"
        case .q: return "Q"
        case .w: return "W"
        case .e: return "E"
        case .r: return "R"
        case .y: return "Y"
        case .t: return "T"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .zero: return "0"
        case .equal: return "="
        case .minus: return "-"
        case .rightBracket: return "]"
        case .leftBracket: return "["
        case .o: return "O"
        case .u: return "U"
        case .i: return "I"
        case .p: return "P"
        case .l: return "L"
        case .j: return "J"
        case .k: return "K"
        case .n: return "N"
        case .m: return "M"
        case .returnKey: return "↩"
        case .quote: return "'"
        case .semicolon: return ";"
        case .backslash: return "\\"
        case .comma: return ","
        case .slash: return "/"
        case .period: return "."
        case .tab: return "⇥"
        case .space: return "␣"
        case .grave: return "`"
        case .delete: return "⌫"
        case .escape: return "⎋"
        }
    }
}

