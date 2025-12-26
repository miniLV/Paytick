import Foundation
import SwiftUI

// Privacy display modes
enum PrivacyDisplayMode: String, CaseIterable {
    case dots = "dots"
    case blur = "blur"
    case emoji = "emoji"
}

// Emoji presets for privacy mode
enum EmojiPreset: String, CaseIterable {
    case fruits = "fruits"
    case rockets = "rockets"
    case crypto = "crypto"
    case custom = "custom"
}

class PrivacySettings: ObservableObject {
    @Published var isPrivacyModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isPrivacyModeEnabled, forKey: "isPrivacyModeEnabled")
        }
    }
    
    @Published var displayMode: PrivacyDisplayMode {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: "privacyDisplayMode")
        }
    }
    
    @Published var emojiPreset: EmojiPreset {
        didSet {
            UserDefaults.standard.set(emojiPreset.rawValue, forKey: "privacyEmojiPreset")
        }
    }
    
    @Published var incomeRanges: [IncomeRange] {
        didSet {
            if let encoded = try? JSONEncoder().encode(incomeRanges) {
                UserDefaults.standard.set(encoded, forKey: "incomeRanges")
            }
        }
    }
    
    init() {
        self.isPrivacyModeEnabled = UserDefaults.standard.bool(forKey: "isPrivacyModeEnabled")
        
        // Load display mode
        if let modeString = UserDefaults.standard.string(forKey: "privacyDisplayMode"),
           let mode = PrivacyDisplayMode(rawValue: modeString) {
            self.displayMode = mode
        } else {
            self.displayMode = .dots
        }
        
        // Load emoji preset
        if let presetString = UserDefaults.standard.string(forKey: "privacyEmojiPreset"),
           let preset = EmojiPreset(rawValue: presetString) {
            self.emojiPreset = preset
        } else {
            self.emojiPreset = .rockets
        }
        
        if let data = UserDefaults.standard.data(forKey: "incomeRanges"),
           let decoded = try? JSONDecoder().decode([IncomeRange].self, from: data) {
            self.incomeRanges = decoded
        } else {
            // Default income ranges with icons
            self.incomeRanges = [
                IncomeRange(min: 0, max: 100, icon: "star"),
                IncomeRange(min: 100, max: 500, icon: "star.fill"),
                IncomeRange(min: 500, max: 1000, icon: "star.circle"),
                IncomeRange(min: 1000, max: Double.infinity, icon: "star.circle.fill")
            ]
        }
    }
    
    func getIconForAmount(_ amount: Double) -> String {
        for range in incomeRanges {
            if amount >= range.min && amount < range.max {
                return range.icon
            }
        }
        return "questionmark.circle"
    }
    
    // Format amount based on current privacy mode
    func formatAmount(_ amount: Double) -> String {
        guard isPrivacyModeEnabled else {
            return String(format: "¥%.2f", amount)
        }
        
        switch displayMode {
        case .dots:
            let formatted = String(format: "%.2f", amount)
            return "¥" + formatted.replacingOccurrences(of: "[0-9]", with: "•", options: .regularExpression)
        case .blur:
            return String(format: "¥%.2f", amount) // Blur is handled in UI
        case .emoji:
            return getEmojiForAmount(amount)
        }
    }
    
    func getEmojiForAmount(_ amount: Double) -> String {
        let emojis: [String]
        switch emojiPreset {
        case .fruits:
            emojis = ["🍎", "🍊", "🍇", "🍋", "🍓"]
        case .rockets:
            emojis = ["🚀", "⭐", "✨", "💫", "🌟"]
        case .crypto:
            emojis = ["💎", "💰", "🪙", "💵", "🏆"]
        case .custom:
            emojis = ["🔥", "⚡", "✨", "💥", "🌈"]
        }
        
        // Generate emoji string based on amount
        var result = ""
        var remaining = amount
        let thresholds = [10000.0, 5000.0, 1000.0, 500.0, 100.0]
        
        for (index, threshold) in thresholds.enumerated() {
            while remaining >= threshold && index < emojis.count {
                result += emojis[index]
                remaining -= threshold
            }
        }
        
        return result.isEmpty ? emojis.last ?? "✨" : result
    }
}

struct IncomeRange: Codable, Identifiable {
    var id = UUID()
    var min: Double
    var max: Double
    var icon: String
    
    enum CodingKeys: String, CodingKey {
        case id, min, max, icon
    }
} 