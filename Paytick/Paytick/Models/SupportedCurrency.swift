//
//  SupportedCurrency.swift
//  Paytick
//
//  Defines supported currencies for the app
//

import Foundation

// MARK: - Supported Currency Enum
enum SupportedCurrency: String, CaseIterable, Identifiable, Codable {
    case system = "system"
    case cny = "CNY"
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case jpy = "JPY"
    case krw = "KRW"
    case hkd = "HKD"
    case twd = "TWD"
    
    var id: String { rawValue }
    
    /// Currency symbol (e.g., ¥, $, €)
    var symbol: String {
        switch self {
        case .system:
            return CurrencyManager.shared.systemCurrencySymbol
        case .cny:
            return "¥"
        case .usd:
            return "$"
        case .eur:
            return "€"
        case .gbp:
            return "£"
        case .jpy:
            return "¥"
        case .krw:
            return "₩"
        case .hkd:
            return "HK$"
        case .twd:
            return "NT$"
        }
    }
    
    /// Display name with symbol (e.g., "¥ CNY (人民币)")
    var displayName: String {
        switch self {
        case .system:
            return LocalizationManager.shared.localizedString(for: "currency.system")
        case .cny:
            return "¥ CNY (人民币)"
        case .usd:
            return "$ USD (US Dollar)"
        case .eur:
            return "€ EUR (Euro)"
        case .gbp:
            return "£ GBP (British Pound)"
        case .jpy:
            return "¥ JPY (日本円)"
        case .krw:
            return "₩ KRW (한국원)"
        case .hkd:
            return "HK$ HKD (港幣)"
        case .twd:
            return "NT$ TWD (新台幣)"
        }
    }
    
    /// ISO currency code
    var currencyCode: String {
        switch self {
        case .system:
            return Locale.current.currency?.identifier ?? "CNY"
        default:
            return rawValue
        }
    }
    
    /// Number of decimal places for this currency
    var decimalPlaces: Int {
        switch self {
        case .jpy, .krw:
            return 0  // These currencies typically don't use decimals
        default:
            return 2
        }
    }
}

