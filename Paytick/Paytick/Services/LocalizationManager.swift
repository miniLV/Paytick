//
//  LocalizationManager.swift
//  Paytick
//
//  Manages app language detection, switching, and persistence
//

import Foundation
import SwiftUI

// MARK: - Supported Languages
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system:
            return NSLocalizedString("language.system", comment: "System Default")
        case .english:
            return "English"
        case .chinese:
            return "简体中文"
        }
    }
    
    var localizedDisplayName: String {
        switch self {
        case .system:
            // This will be localized based on current language
            return LocalizationManager.shared.localizedString(for: "language.system")
        case .english:
            return "English"
        case .chinese:
            return "简体中文"
        }
    }
}

// MARK: - LocalizationManager
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    // MARK: - Published Properties
    @AppStorage("appLanguage") private var storedLanguage: String = AppLanguage.system.rawValue
    
    @Published private(set) var currentLanguage: AppLanguage = .system
    @Published private(set) var currentLocale: Locale = .current
    
    // Bundle for localized strings
    private var localizedBundle: Bundle = .main
    
    // MARK: - Initialization
    private init() {
        // Load stored language preference
        if let language = AppLanguage(rawValue: storedLanguage) {
            currentLanguage = language
        }
        updateLocaleAndBundle()
    }
    
    // MARK: - Public Methods
    
    /// Sets the app language and updates immediately
    func setLanguage(_ language: AppLanguage) {
        storedLanguage = language.rawValue
        currentLanguage = language
        updateLocaleAndBundle()
        
        // Post notification for components that need to refresh
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }
    
    /// Returns the effective language code (resolves "system" to actual language)
    var effectiveLanguageCode: String {
        switch currentLanguage {
        case .system:
            return systemLanguageCode
        case .english:
            return "en"
        case .chinese:
            return "zh-Hans"
        }
    }
    
    /// Gets the system's preferred language (en or zh-Hans)
    var systemLanguageCode: String {
        let preferredLanguages = Locale.preferredLanguages
        
        for language in preferredLanguages {
            if language.hasPrefix("zh") {
                return "zh-Hans"
            } else if language.hasPrefix("en") {
                return "en"
            }
        }
        
        // Default to English if no match
        return "en"
    }
    
    /// Returns a localized string for the given key
    func localizedString(for key: String, comment: String = "") -> String {
        return NSLocalizedString(key, bundle: localizedBundle, comment: comment)
    }
    
    /// Returns a localized string with format arguments
    func localizedString(for key: String, _ args: CVarArg...) -> String {
        let format = localizedString(for: key)
        return String(format: format, arguments: args)
    }
    
    // MARK: - Private Methods
    
    private func updateLocaleAndBundle() {
        let languageCode = effectiveLanguageCode
        
        // Update locale
        currentLocale = Locale(identifier: languageCode)
        
        // Update bundle for localized strings
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            localizedBundle = bundle
        } else {
            // Fallback to main bundle (English)
            localizedBundle = .main
        }
        
        // Trigger SwiftUI view updates
        objectWillChange.send()
    }
}

// MARK: - Notification Name Extension
extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

// MARK: - Environment Key
private struct LocalizationManagerKey: EnvironmentKey {
    static let defaultValue = LocalizationManager.shared
}

extension EnvironmentValues {
    var localizationManager: LocalizationManager {
        get { self[LocalizationManagerKey.self] }
        set { self[LocalizationManagerKey.self] = newValue }
    }
}

