import Foundation

struct IconValue: Codable, Identifiable, Hashable {
    var id = UUID()
    var icon: String  // emoji
    var value: Double // Corresponding amount
    
    static func == (lhs: IconValue, rhs: IconValue) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

class PrivacyIconSettings: ObservableObject {
    @Published var iconValues: [IconValue] {
        didSet {
            saveIconValues()
        }
    }
    
    // Preset emoji list
    static let presetEmojis = ["🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🍒", "🥝", 
                              "🚗", "🚕", "🚙", "🚌", "🚎", "🏎️", "🚓", "🚑", "🚒", "✈️", "🚀",
                              "💎", "🌟", "⭐️", "🌙", "☀️", "🌈", "🎈", "🎨", "🎭", "🎪",
                              "🏠", "🏡", "🏢", "🏣", "🏤", "🏥", "🏦", "🏨", "🏩", "🏪", "🏫"]
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "iconValues"),
           let decoded = try? JSONDecoder().decode([IconValue].self, from: data) {
            self.iconValues = decoded.sorted(by: { $0.value > $1.value })
        } else {
            // Default configuration
            self.iconValues = [
                IconValue(icon: "🚀", value: 1000),
                IconValue(icon: "🚗", value: 500),
                IconValue(icon: "🍎", value: 100)
            ]
        }
    }
    
    private func saveIconValues() {
        if let encoded = try? JSONEncoder().encode(iconValues) {
            UserDefaults.standard.set(encoded, forKey: "iconValues")
        }
    }
    
    func addIconValue(_ iconValue: IconValue) {
        iconValues.append(iconValue)
        iconValues.sort(by: { $0.value > $1.value }) // Keep amounts sorted from largest to smallest
    }
    
    func removeIconValue(_ iconValue: IconValue) {
        iconValues.removeAll(where: { $0.id == iconValue.id })
    }
    
    func formatAmount(_ amount: Double) -> String {
        // Boundary handling - minimum value
        if amount <= 0 {
            return "🔸"
        }
        
        var remainingAmount = amount
        var result = ""
        var emojiCount = 0
        let maxEmojis = 8 // Maximum emoji length limit
        
        // Priority 1: Use user-configured emoji mapping
        for iconValue in iconValues {
            while remainingAmount >= iconValue.value && emojiCount < maxEmojis {
                result += iconValue.icon
                remainingAmount -= iconValue.value
                emojiCount += 1
            }
        }
        
        // Priority 2: Use smart padding if user configuration is insufficient and remaining amount is large
        if remainingAmount > 0 && emojiCount < maxEmojis {
            // Use smart padding if remaining amount is very large (suggests user config max denomination is insufficient)
            if remainingAmount >= 5000 {
                let diamondCount = min(Int(remainingAmount / 5000), maxEmojis - emojiCount)
                result += String(repeating: "💎", count: diamondCount)
                remainingAmount -= Double(diamondCount * 5000)
                emojiCount += diamondCount
            }
            
            // Continue processing medium amounts
            if remainingAmount >= 100 && emojiCount < maxEmojis {
                let carCount = min(Int(remainingAmount / 500), maxEmojis - emojiCount)
                result += String(repeating: "🚗", count: carCount)
                remainingAmount -= Double(carCount * 500)
                emojiCount += carCount
            }
            
            // Handle small remaining amounts
            if remainingAmount >= 50 && emojiCount < maxEmojis {
                result += "🌟"
                remainingAmount -= min(remainingAmount, 99)
                emojiCount += 1
            } else if remainingAmount >= 10 && emojiCount < maxEmojis {
                result += "⭐"
                remainingAmount -= min(remainingAmount, 49)
                emojiCount += 1
            }
        }
        
        // Priority 3: Special handling for very large values
        if amount >= 50000 {
            // Add special marker if original amount is extremely large
            if result.count >= maxEmojis - 1 {
                result = String(result.prefix(maxEmojis - 1)) + "+"
            } else {
                result += "+"
            }
        } else if remainingAmount >= 10 && emojiCount >= maxEmojis {
            // Add ellipsis if maximum length is reached but significant amount remains
            result = String(result.dropLast()) + "+"
        }
        
        return result.isEmpty ? "🔸" : result
    }
} 