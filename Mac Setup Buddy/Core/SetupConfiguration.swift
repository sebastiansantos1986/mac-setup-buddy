//
//  SetupConfiguration.swift
//  Mac Setup Buddy
//
//  JSON-based configuration for zero-touch provisioning
//  Admins can customize via:
//    - Configuration profile (MDM)
//    - JSON file on disk
//    - Remote URL
//
//  Created: December 2025
//

import Foundation
import SwiftUI

// MARK: - Main Configuration
struct SetupConfiguration: Codable {
    var branding: BrandingConfig?
    var authentication: AuthenticationConfig?
    var userCreation: UserCreationConfig?
    var ui: UIConfig?
    var setupSteps: [SetupStepConfig]?
    var policies: PoliciesConfig?
    var completion: CompletionConfig?
    var advanced: AdvancedConfig?
    
    // Default configuration
    static let `default` = SetupConfiguration(
        branding: BrandingConfig(),
        authentication: nil,
        userCreation: UserCreationConfig(),
        ui: UIConfig(),
        setupSteps: [],
        policies: nil,
        completion: CompletionConfig(),
        advanced: AdvancedConfig()
    )
}

// MARK: - Branding Configuration
struct BrandingConfig: Codable {
    var companyName: String = "Mac Setup Buddy"
    var logoPath: String?
    var backgroundImagePath: String?
    var primaryColor: String = "#1a2744"
    var accentColor: String = "#4073d6"
    var welcomeTitle: String = "Welcome"
    var welcomeMessage: String?
    var loginMessage: String?
    var helpContactInfo: String?
    
    // Convert hex color to SwiftUI Color
    var primarySwiftUIColor: Color {
        Color(hex: primaryColor) ?? Color(red: 0.1, green: 0.15, blue: 0.27)
    }
    
    var accentSwiftUIColor: Color {
        Color(hex: accentColor) ?? Color.blue
    }
}

// MARK: - Authentication Configuration
struct AuthenticationConfig: Codable {
    var oktaDomain: String
    var allowedDomains: [String]?
    var requireMFA: Bool = true
    var allowPasswordAuth: Bool = false
    var sessionTimeout: Int = 60
}

// MARK: - User Creation Configuration
struct UserCreationConfig: Codable {
    var enabled: Bool = true
    var accountType: AccountType = .admin
    var usernameFormat: UsernameFormat = .firstDotLast
    var hideAdminAccount: Bool = true
    var syncPassword: Bool = true
    var homeDirectory: String = "/Users/{username}"
    var defaultShell: String = "/bin/zsh"
    
    enum AccountType: String, Codable {
        case admin
        case standard
    }
    
    enum UsernameFormat: String, Codable {
        case firstLast      // "sebastiansantos"
        case firstDotLast   // "sebastian.santos"
        case email          // "sebastian.santos@example.com"
        case samAccountName // Use Okta's samAccountName if available
    }
    
    // Format username based on configuration
    func formatUsername(firstName: String?, lastName: String?, email: String?) -> String {
        switch usernameFormat {
        case .firstLast:
            if let first = firstName?.lowercased(), let last = lastName?.lowercased() {
                return "\(first)\(last)"
            }
        case .firstDotLast:
            if let first = firstName?.lowercased(), let last = lastName?.lowercased() {
                return "\(first).\(last)"
            }
        case .email:
            return email ?? ""
        case .samAccountName:
            // Extract from email if available
            if let email = email, let username = email.split(separator: "@").first {
                return String(username)
            }
        }
        
        // Fallback: extract from email
        if let email = email, let username = email.split(separator: "@").first {
            return String(username)
        }
        return ""
    }
}

// MARK: - UI Configuration
struct UIConfig: Codable {
    var showLanguageSelector: Bool = true
    var showNetworkSelector: Bool = true
    var showShutdownButton: Bool = true
    var showRestartButton: Bool = true
    var showHelpButton: Bool = true
    var defaultLanguage: String?
    var windowWidth: Int = 1440
    var windowHeight: Int = 900
    var fullscreen: Bool = true
}

// MARK: - Setup Step Configuration
struct SetupStepConfig: Codable, Identifiable {
    var id: String
    var title: String
    var description: String?
    var icon: String = "circle.fill"
    var iconColor: String = "#4073d6"
    var type: StepType
    var action: StepAction?
    var buttonText: String = "Continue"
    var required: Bool = false
    var autoAdvance: Bool = false
    var skipIfInstalled: Bool = false
    var skipIfMissing: Bool = true
    var timeout: Int = 300
    
    enum StepType: String, Codable {
        case app
        case policy
        case script
        case url
        case keychain
        case wait
    }
    
    var iconSwiftUIColor: Color {
        Color(hex: iconColor) ?? Color.blue
    }
}

struct StepAction: Codable {
    var appPath: String?
    var appBundleId: String?
    var policyId: String?
    var policyTrigger: String?
    var scriptPath: String?
    var scriptContent: String?
    var url: String?
    var keychainService: String?
    var waitSeconds: Int?
    var waitForProcess: String?
}

// MARK: - Policies Configuration
struct PoliciesConfig: Codable {
    var enrollmentPolicy: String?
    var postAuthPolicy: String?
    var finalPolicy: String?
    var jamfBinaryPath: String = "/usr/local/bin/jamf"
    
    init(enrollmentPolicy: String? = nil, postAuthPolicy: String? = nil, finalPolicy: String? = nil, jamfBinaryPath: String = "/usr/local/bin/jamf") {
        self.enrollmentPolicy = enrollmentPolicy
        self.postAuthPolicy = postAuthPolicy
        self.finalPolicy = finalPolicy
        self.jamfBinaryPath = jamfBinaryPath
    }
}

// MARK: - Completion Configuration
struct CompletionConfig: Codable {
    var title: String = "Setup Complete!"
    var message: String = "Your Mac is now configured and ready to use."
    var showRestartPrompt: Bool = false
    var autoLogout: Bool = false
    var launchAppOnComplete: String?
    var redirectUrl: String?
}

// MARK: - Advanced Configuration
struct AdvancedConfig: Codable {
    var debugMode: Bool = false
    var logPath: String = "/var/log/mac-setup-buddy.log"
    var configRefreshUrl: String?
    var bypassOnError: Bool = false
    var exitCodes: ExitCodes = ExitCodes()
    
    struct ExitCodes: Codable {
        var success: Int = 0
        var cancelled: Int = 1
        var authFailed: Int = 2
        var setupFailed: Int = 3
    }
}

// MARK: - Configuration Loader
class ConfigurationLoader {
    
    static let shared = ConfigurationLoader()
    
    private init() {}
    
    // Configuration search paths (in priority order)
    private let configPaths = [
        "/Library/Managed Preferences/com.sebastiansantos.mac-setup-buddy.plist",  // MDM managed
        "/Library/Application Support/Mac Setup Buddy/config.json",      // System-wide
        "~/Library/Application Support/Mac Setup Buddy/config.json",     // User-specific
        Bundle.main.path(forResource: "config", ofType: "json")     // Bundled default
    ].compactMap { $0 }
    
    // Load configuration from first available source
    func loadConfiguration() -> SetupConfiguration {
        // 1. Try to load from MDM managed preferences
        if let config = loadFromManagedPreferences() {
            log("Loaded configuration from MDM managed preferences")
            return config
        }
        
        // 2. Try JSON files in order
        for path in configPaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                if let config = loadFromJSON(path: expandedPath) {
                    log("Loaded configuration from: \(expandedPath)")
                    return config
                }
            }
        }
        
        // 3. Return default configuration
        log("Using default configuration")
        return SetupConfiguration.default
    }
    
    // Load from remote URL
    func loadConfiguration(from url: URL, completion: @escaping (SetupConfiguration?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                self.log("Failed to load remote config: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let config = try decoder.decode(SetupConfiguration.self, from: data)
                self.log("Loaded configuration from remote URL")
                completion(config)
            } catch {
                self.log("Failed to parse remote config: \(error)")
                completion(nil)
            }
        }.resume()
    }
    
    // Load from JSON file
    private func loadFromJSON(path: String) -> SetupConfiguration? {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let decoder = JSONDecoder()
            return try decoder.decode(SetupConfiguration.self, from: data)
        } catch {
            log("Failed to load JSON config from \(path): \(error)")
            return nil
        }
    }
    
    // Load from MDM managed preferences (plist)
    private func loadFromManagedPreferences() -> SetupConfiguration? {
        let domain = "com.sebastiansantos.mac-setup-buddy"
        
        guard let prefs = UserDefaults(suiteName: domain),
              let dict = prefs.dictionaryRepresentation() as? [String: Any],
              !dict.isEmpty else {
            return nil
        }
        
        // Convert plist dictionary to JSON then decode
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict)
            let decoder = JSONDecoder()
            return try decoder.decode(SetupConfiguration.self, from: jsonData)
        } catch {
            log("Failed to parse MDM preferences: \(error)")
            return nil
        }
    }
    
    // Save configuration to file
    func saveConfiguration(_ config: SetupConfiguration, to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: URL(fileURLWithPath: path))
    }
    
    // Logging
    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] ConfigLoader: \(message)")
    }
}

// MARK: - Color Extension for Hex Colors
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Command Line Config Bridge
extension SetupConfiguration {
    /// Convert to CommandLineConfig for backward compatibility
    func toCommandLineConfig() -> CommandLineConfig {
        var config = CommandLineConfig()
        
        // Branding
        if let branding = branding {
            config.title = branding.companyName
            config.message = branding.loginMessage
            config.bannerImage = branding.logoPath
            config.loginInfoMessage = branding.welcomeMessage
            config.helpContactInfo = branding.helpContactInfo
        }
        
        // Authentication
        if let auth = authentication {
            config.oktaDomain = auth.oktaDomain
            config.allowedDomains = auth.allowedDomains
        }
        
        // User Creation
        if let user = userCreation {
            config.createLocalUser = user.enabled
        }
        
        // UI
        if let ui = ui {
            config.showLanguageSelector = ui.showLanguageSelector
            config.showNetworkSelector = ui.showNetworkSelector
            config.windowWidth = CGFloat(ui.windowWidth)
            config.windowHeight = CGFloat(ui.windowHeight)
            config.hideWindowControls = ui.fullscreen
        }
        
        return config
    }
}
