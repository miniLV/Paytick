//
//  String+Localization.swift
//  Paytick
//
//  Convenience extensions for localization
//

import Foundation

extension String {
    /// Returns the localized string using LocalizationManager
    var localized: String {
        return LocalizationManager.shared.localizedString(for: self)
    }
    
    /// Returns the localized string with format arguments
    func localized(_ args: CVarArg...) -> String {
        let format = LocalizationManager.shared.localizedString(for: self)
        return String(format: format, arguments: args)
    }
    
    /// Returns the localized string with a single integer argument
    func localized(with value: Int) -> String {
        let format = LocalizationManager.shared.localizedString(for: self)
        return String(format: format, value)
    }
    
    /// Returns the localized string with a single double argument
    func localized(with value: Double) -> String {
        let format = LocalizationManager.shared.localizedString(for: self)
        return String(format: format, value)
    }
}

