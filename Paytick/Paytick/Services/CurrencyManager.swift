//
//  CurrencyManager.swift
//  Paytick
//
//  Manages currency selection, formatting, and persistence
//

import Foundation
import SwiftUI

// MARK: - CurrencyManager
final class CurrencyManager: ObservableObject {
    static let shared = CurrencyManager()
    
    // MARK: - Published Properties
    @AppStorage("appCurrency") private var storedCurrency: String = SupportedCurrency.system.rawValue
    
    @Published private(set) var currentCurrency: SupportedCurrency = .system
    
    // Number formatter for currency
    private var numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    // MARK: - Initialization
    private init() {
        // Load stored currency preference
        if let currency = SupportedCurrency(rawValue: storedCurrency) {
            currentCurrency = currency
        }
        updateFormatter()
    }
    
    // MARK: - Public Methods
    
    /// Sets the app currency and updates immediately
    func setCurrency(_ currency: SupportedCurrency) {
        storedCurrency = currency.rawValue
        currentCurrency = currency
        updateFormatter()
        
        // Post notification for components that need to refresh
        NotificationCenter.default.post(name: .currencyDidChange, object: nil)
        
        // Trigger SwiftUI view updates
        objectWillChange.send()
    }
    
    /// Returns the effective currency symbol
    var currencySymbol: String {
        effectiveCurrency.symbol
    }
    
    /// Returns the effective currency (resolves "system" to actual currency)
    var effectiveCurrency: SupportedCurrency {
        if currentCurrency == .system {
            return systemCurrency
        }
        return currentCurrency
    }
    
    /// Gets the system's currency based on locale
    var systemCurrency: SupportedCurrency {
        let currencyCode = Locale.current.currency?.identifier ?? "CNY"
        
        // Try to match with supported currencies
        if let matched = SupportedCurrency(rawValue: currencyCode) {
            return matched
        }
        
        // Default to CNY if not matched
        return .cny
    }
    
    /// Gets the system's currency symbol
    var systemCurrencySymbol: String {
        systemCurrency.symbol
    }
    
    /// Formats an amount with the current currency symbol
    func formatAmount(_ amount: Double) -> String {
        let symbol = currencySymbol
        let formatted = numberFormatter.string(from: NSNumber(value: amount)) ?? "0.00"
        return "\(symbol)\(formatted)"
    }
    
    /// Formats an amount for compact display (e.g., status bar)
    func formatCompactAmount(_ amount: Double) -> String {
        let symbol = currencySymbol
        
        if amount >= 10000 {
            return String(format: "%@%.1fk", symbol, amount / 1000)
        } else if amount >= 1000 {
            return String(format: "%@%.0f", symbol, amount)
        } else {
            return String(format: "%@%.2f", symbol, amount)
        }
    }
    
    /// Formats an amount with masked digits for privacy mode
    func formatMaskedAmount() -> String {
        return "\(currencySymbol)••••.••"
    }
    
    // MARK: - Private Methods
    
    private func updateFormatter() {
        let currency = effectiveCurrency
        numberFormatter.minimumFractionDigits = currency.decimalPlaces
        numberFormatter.maximumFractionDigits = currency.decimalPlaces
    }
}

// MARK: - Notification Name Extension
extension Notification.Name {
    static let currencyDidChange = Notification.Name("currencyDidChange")
}

// MARK: - Environment Key
private struct CurrencyManagerKey: EnvironmentKey {
    static let defaultValue = CurrencyManager.shared
}

extension EnvironmentValues {
    var currencyManager: CurrencyManager {
        get { self[CurrencyManagerKey.self] }
        set { self[CurrencyManagerKey.self] = newValue }
    }
}

