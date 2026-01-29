//
//  PaytickApp.swift
//  Paytick
//
//  Created by miniLV on 2024/9/25.
//

import SwiftUI
import SwiftData

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var privacySettings: PrivacySettings?
    var iconSettings: PrivacyIconSettings?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let viewModel = IncomeViewModel()
        let privacySettings = PrivacySettings()
        let iconSettings = PrivacyIconSettings()
        self.privacySettings = privacySettings
        self.iconSettings = iconSettings
        
        // Create status bar controller only (LSUIElement=YES in Info.plist ensures menu bar only)
        statusBarController = StatusBarController(incomeViewModel: viewModel, privacySettings: privacySettings, iconSettings: iconSettings)
    }
}

// MARK: - App
@main
struct PaytickApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings { }
    }
}

