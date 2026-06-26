//
//  CommandLineConfig.swift
//  Mac Setup Buddy
//
//  Created by Sebastian Santos on October 4, 2025
//  Updated: December 2025 - Added persistent blur and flow mode support
//

import Foundation

// MARK: - Background Style
enum BackgroundStyle: String {
    case solid       // Solid black background (blocks everything)
    case blur        // BLUR EFFECT - Creates macOS blur overlay
    case transparent // Transparent background (no overlay)
    case none        // No background modification
}

// MARK: - Blur Mode
enum BlurMode: String {
    case perWindow      // Default: blur opens/closes with each window
    case persistent     // NEW: blur stays open, only content windows change
}

// MARK: - Command Line Configuration
struct CommandLineConfig {
    // Execution settings
    var backgroundStyle: BackgroundStyle = .none
    var hideWindowControls: Bool = false
    var hideControls: Bool = false  // Alias for hideWindowControls
    
    var windowWidth: Double = 650
    var windowHeight: Double = 500
    var outputMode: OutputMode = .exitCode
    
    // JSON Configuration file path
    var configFilePath: String? = nil
    var previewMode: Bool = false
    
    // NEW: Persistent Blur Mode
    var blurMode: BlurMode = .perWindow          // Default to legacy behavior
    var persistentBlurAction: PersistentBlurAction = .none  // What to do with persistent blur
    
    // Text & branding
    var title: String?
    var subtitle: String?
    var message: String?
    var bannerImage: String?
    var logoImage: String?
    
    // Welcome screen specific
    var bannerTitle: String?
    var bannerSubtitle: String?
    var welcomeIcon: String?
    var welcomeTimeEstimate: String?
    var buttonText: String?
    var timeEstimate: String?
    var welcomeStep1: String?
    var welcomeStep2: String?
    var welcomeStep3: String?
    var welcomeStep4: String?

    // Email flow
    var email: String?
    var emailDomain: String?
    var emailPlaceholder: String?
    
    // User info
    var userName: String?
    var userDepartment: String?
    var userTitle: String?
    var assetTag: String?
    
    // Device info (for completion view)
    var deviceName: String?
    var deviceModel: String?
    var serialNumber: String?
    var osVersion: String?
    var isEncrypted: Bool?
    
    // Installation progress
    var installationItems: [InstallationItem]?
    var overallProgress: Double?
    var enableLogMonitor: Bool = false
    var autoCloseDelay: Int?
    var showCountdown: Bool = false
    
    // AAD progress
    var showAADProgress: Bool = false
    var aadIcon: String?
    var aadProgressMessage: String?
    var aadProgressSteps: [String]?
    var aadStepDuration: TimeInterval?
    var aadAutoProgress: Bool?
    var aadCancelButtonText: String?
    
    // Notification
    var notificationTitle: String?
    var notificationMessage: String?
    var notificationIcon: String?
    var notificationButtons: [String]?
    
    // Misc
    var skipAnimations: Bool = false
    
    // Flow control (for persistent blur navigation)
    var enableFlow: Bool = false
    var flowOrder: [String]?
    var autoAdvance: Bool = false
    
    // NEW: Feature flags (used by NavigationController)
    var enableNetworkCheck: Bool = false
    var networkCheckHosts: [String]? = nil  // Hosts to check for network connectivity
    var customApps: [String]? = nil         // Custom apps for credential configuration
    
    // NEW: Credential Login Screen (JAMF Connect-style)
    var showLanguageSelector: Bool? = true       // Show language dropdown
    var showNetworkSelector: Bool? = true        // Show WiFi network dropdown
    var loginInfoMessage: String? = nil          // Multi-line message between card and buttons
    var oktaDomain: String? = nil                // Okta domain for authentication (e.g., "company.okta.com")
    var createLocalUser: Bool? = false           // Create local macOS user after Okta auth
    var helpContactInfo: String? = nil           // Contact info shown in Help dialog
    var allowedDomains: [String]? = nil          // Allowed email domains (e.g., ["company.com"])
}

// MARK: - Persistent Blur Actions
enum PersistentBlurAction: String {
    case none           // No action - use per-window blur (legacy)
    case start          // Start the persistent blur background
    case stop           // Stop the persistent blur background
    case showOnly       // Just show content (blur already running)
}

// MARK: - Output Mode
enum OutputMode {
    case none
    case stdout
    case exitCode
}

// MARK: - Installation Item Model
struct InstallationItem: Identifiable {
    let id = UUID()
    let policyUUID: String
    let trigger: String
    let name: String
    let description: String
    let icon: String           // SF Symbol name (fallback)
    var iconURL: String?       // NEW: URL or file path for custom icon
    var status: ItemStatus
    var progress: Double
}

enum ItemStatus {
    case pending
    case installing
    case completed
    case failed
}

// MARK: - Exit Codes
enum ExitCode: Int32 {
    case success = 0
    case failure = 1
    case cancelled = 2
    case timeout = 4
    case skipped = 5
}

// MARK: - ViewState Enum
enum ViewState {
    case welcome
    case emailInput
    case networkCheck      // NEW
    case credentials       // NEW - SSO passthrough for Office/Druva
    case credentialLogin   // NEW - Fullscreen JAMF Connect-style login
    case progress
    case success
    case notification
    case aadProgress
    case verification
    case completion
    case error
}
