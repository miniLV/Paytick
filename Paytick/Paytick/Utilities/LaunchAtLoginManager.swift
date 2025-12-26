//
//  LaunchAtLoginManager.swift
//  Paytick
//
//  Manages Launch at Login functionality using SMAppService (macOS 13+)
//

import Foundation
import ServiceManagement

@MainActor
class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()
    
    @Published var isEnabled: Bool {
        didSet {
            if oldValue != isEnabled {
                updateLoginItemStatus()
            }
        }
    }
    
    private init() {
        // Check current status on init
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }
    
    /// Updates the login item registration status
    private func updateLoginItemStatus() {
        do {
            if isEnabled {
                // Register as login item
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                // Unregister as login item
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // Revert the change if it failed
            DispatchQueue.main.async {
                self.isEnabled = SMAppService.mainApp.status == .enabled
            }
        }
    }
    
    /// Refreshes the current status from the system
    func refreshStatus() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
    
    /// Returns a human-readable status description
    var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Enabled"
        case .notRegistered:
            return "Not Registered"
        case .requiresApproval:
            return "Requires Approval in System Settings"
        case .notFound:
            return "App Not Found"
        @unknown default:
            return "Unknown"
        }
    }
}

