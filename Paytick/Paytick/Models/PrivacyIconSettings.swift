import Foundation

struct IconValue: Codable, Identifiable, Hashable {
    var id = UUID()
    var icon: String  // emoji
    var value: Double // 对应的金额
    
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
    
    // 预设的表情列表
    static let presetEmojis = ["🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🍒", "🥝", 
                              "🚗", "🚕", "🚙", "🚌", "🚎", "🏎️", "🚓", "🚑", "🚒", "✈️", "🚀",
                              "💎", "🌟", "⭐️", "🌙", "☀️", "🌈", "🎈", "🎨", "🎭", "🎪",
                              "🏠", "🏡", "🏢", "🏣", "🏤", "🏥", "🏦", "🏨", "🏩", "🏪", "🏫"]
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "iconValues"),
           let decoded = try? JSONDecoder().decode([IconValue].self, from: data) {
            self.iconValues = decoded.sorted(by: { $0.value > $1.value })
        } else {
            // 默认配置
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
        iconValues.sort(by: { $0.value > $1.value }) // 保持金额从大到小排序
    }
    
    func removeIconValue(_ iconValue: IconValue) {
        iconValues.removeAll(where: { $0.id == iconValue.id })
    }
    
    func formatAmount(_ amount: Double) -> String {
        // 边界处理 - 极小值
        if amount <= 0 {
            return "🔸"
        }
        
        var remainingAmount = amount
        var result = ""
        var emojiCount = 0
        let maxEmojis = 8 // 最大emoji长度限制
        
        // 第一优先级：使用用户配置的emoji映射
        for iconValue in iconValues {
            while remainingAmount >= iconValue.value && emojiCount < maxEmojis {
                result += iconValue.icon
                remainingAmount -= iconValue.value
                emojiCount += 1
            }
        }
        
        // 第二优先级：如果用户配置无法完全表示，且剩余金额较大，使用智能补位
        if remainingAmount > 0 && emojiCount < maxEmojis {
            // 如果剩余金额很大（说明用户配置的最大面额不够），使用智能补位
            if remainingAmount >= 5000 {
                let diamondCount = min(Int(remainingAmount / 5000), maxEmojis - emojiCount)
                result += String(repeating: "💎", count: diamondCount)
                remainingAmount -= Double(diamondCount * 5000)
                emojiCount += diamondCount
            }
            
            // 继续处理中等金额
            if remainingAmount >= 100 && emojiCount < maxEmojis {
                let carCount = min(Int(remainingAmount / 500), maxEmojis - emojiCount)
                result += String(repeating: "🚗", count: carCount)
                remainingAmount -= Double(carCount * 500)
                emojiCount += carCount
            }
            
            // 处理小额剩余
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
        
        // 第三优先级：极大值特殊处理
        if amount >= 50000 {
            // 如果原始金额极大，添加特殊标记
            if result.count >= maxEmojis - 1 {
                result = String(result.prefix(maxEmojis - 1)) + "+"
            } else {
                result += "+"
            }
        } else if remainingAmount >= 10 && emojiCount >= maxEmojis {
            // 如果达到最大长度但还有较大剩余，添加省略号
            result = String(result.dropLast()) + "+"
        }
        
        return result.isEmpty ? "🔸" : result
    }
} 