//
//  AppConfigurator.swift
//  Mac Setup Buddy
//
//  Configures enterprise applications with user credentials
//  Supports Microsoft Office 365, Druva InSync, and custom apps
//

import Foundation
import AppKit

class AppConfigurator {
    
    // MARK: - Microsoft Office 365 Configuration
    
    /// Configure Microsoft Office with user email for automatic sign-in
    /// - Parameter email: User's email address
    /// - Returns: True if configuration was successful
    @discardableResult
    static func configureMicrosoftOffice(email: String) -> Bool {
        print("[AppConfigurator] Configuring Microsoft Office for \(email)")
        
        var success = true
        
        // Set the default email for Office apps using defaults
        let officeApps = [
            "com.microsoft.Word",
            "com.microsoft.Excel",
            "com.microsoft.Powerpoint",
            "com.microsoft.Outlook",
            "com.microsoft.onenote.mac"
        ]
        
        for bundleId in officeApps {
            // Set the Office Sign-In hint
            let result = runCommand("/usr/bin/defaults", arguments: [
                "write", bundleId, "DefaultEmailAddressOrDomain", email
            ])
            
            if !result {
                print("[AppConfigurator] Warning: Could not configure \(bundleId)")
            }
        }
        
        // Configure Office activation email
        success = runCommand("/usr/bin/defaults", arguments: [
            "write", "com.microsoft.office", "OfficeActivationEmailAddress", email
        ])
        
        // Set organization identity hint
        let domain = email.components(separatedBy: "@").last ?? ""
        if !domain.isEmpty {
            runCommand("/usr/bin/defaults", arguments: [
                "write", "com.microsoft.office", "OrganizationDomain", domain
            ])
        }
        
        // Save to keychain for Microsoft services
        KeychainHelper.saveMicrosoftCredentials(username: email, password: "")
        
        print("[AppConfigurator] Microsoft Office configured: \(success)")
        return success
    }
    
    /// Configure Microsoft Office with full credentials (email + password)
    @discardableResult
    static func configureMicrosoftOffice(email: String, password: String) -> Bool {
        // First do the basic config
        let basicConfig = configureMicrosoftOffice(email: email)
        
        // Then save credentials to keychain for auto-fill
        let keychainSave = KeychainHelper.saveMicrosoftCredentials(username: email, password: password)
        
        return basicConfig && keychainSave
    }
    
    // MARK: - Druva InSync Configuration
    
    /// Configure Druva InSync with user credentials
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password (optional, can be empty for SSO)
    /// - Returns: True if configuration was successful
    @discardableResult
    static func configureDruvaInSync(email: String, password: String = "") -> Bool {
        print("[AppConfigurator] Configuring Druva InSync for \(email)")
        
        // Check if Druva InSync is installed
        let druvaPath = "/Applications/Druva inSync.app"
        let druvaAltPath = "/Applications/inSync.app"
        
        var inSyncPath: String? = nil
        
        if FileManager.default.fileExists(atPath: druvaPath) {
            inSyncPath = druvaPath
        } else if FileManager.default.fileExists(atPath: druvaAltPath) {
            inSyncPath = druvaAltPath
        }
        
        guard inSyncPath != nil else {
            print("[AppConfigurator] Druva InSync not found at expected paths")
            // Still save credentials to keychain for later activation
            KeychainHelper.saveDruvaCredentials(username: email, password: password)
            return true // Return true since credentials are saved
        }
        
        // Save credentials to keychain
        let keychainSave = KeychainHelper.saveDruvaCredentials(username: email, password: password)
        
        // Try to configure via command line if available
        let cliPath = "/Library/Application Support/inSync/inSync.app/Contents/MacOS/inSyncClient"
        
        if FileManager.default.fileExists(atPath: cliPath) {
            // Attempt CLI activation
            let result = runCommand(cliPath, arguments: ["--set-user", email])
            print("[AppConfigurator] Druva CLI configuration: \(result)")
        }
        
        // Set defaults for Druva
        runCommand("/usr/bin/defaults", arguments: [
            "write", "com.druva.inSync", "UserEmail", email
        ])
        
        print("[AppConfigurator] Druva InSync configured: \(keychainSave)")
        return keychainSave
    }
    
    // MARK: - Generic App Configuration
    
    /// Configure a generic app with email using defaults
    /// - Parameters:
    ///   - bundleId: The app's bundle identifier
    ///   - email: User's email
    ///   - emailKey: The defaults key for email (default: "UserEmail")
    /// - Returns: True if successful
    @discardableResult
    static func configureApp(bundleId: String, email: String, emailKey: String = "UserEmail") -> Bool {
        print("[AppConfigurator] Configuring \(bundleId) for \(email)")
        
        return runCommand("/usr/bin/defaults", arguments: [
            "write", bundleId, emailKey, email
        ])
    }
    
    /// Configure multiple apps at once
    /// - Parameters:
    ///   - apps: Array of (bundleId, emailKey) tuples
    ///   - email: User's email
    /// - Returns: Dictionary of bundleId -> success status
    static func configureApps(_ apps: [(bundleId: String, emailKey: String)], email: String) -> [String: Bool] {
        var results: [String: Bool] = [:]
        
        for app in apps {
            results[app.bundleId] = configureApp(bundleId: app.bundleId, email: email, emailKey: app.emailKey)
        }
        
        return results
    }
    
    // MARK: - Jamf Connect Integration
    
    /// Extract credentials from Jamf Connect if available
    /// - Returns: Tuple of (username, domain) if available
    static func getJamfConnectCredentials() -> (username: String, domain: String)? {
        // Check Jamf Connect preferences
        let jamfConnectPrefs = "/Library/Managed Preferences/com.jamf.connect.plist"
        let jamfConnectLoginPrefs = "/Library/Managed Preferences/com.jamf.connect.login.plist"
        
        var username: String?
        var domain: String?
        
        // Try to read from Jamf Connect preferences
        if let prefs = NSDictionary(contentsOfFile: jamfConnectPrefs) {
            username = prefs["LastUser"] as? String
            domain = prefs["OIDCDomain"] as? String ?? prefs["ADDomain"] as? String
        }
        
        // Try login preferences as fallback
        if username == nil, let loginPrefs = NSDictionary(contentsOfFile: jamfConnectLoginPrefs) {
            username = loginPrefs["LastUser"] as? String
            domain = loginPrefs["ADDomain"] as? String
        }
        
        // Try to get from current user context
        if username == nil {
            username = NSUserName()
        }
        
        if let user = username, let dom = domain {
            return (user, dom)
        } else if let user = username {
            return (user, "")
        }
        
        return nil
    }
    
    /// Auto-configure apps using Jamf Connect credentials
    /// - Returns: True if credentials were found and apps configured
    @discardableResult
    static func autoConfigureFromJamfConnect() -> Bool {
        guard let credentials = getJamfConnectCredentials() else {
            print("[AppConfigurator] No Jamf Connect credentials found")
            return false
        }
        
        var email = credentials.username
        if !credentials.domain.isEmpty && !email.contains("@") {
            email = "\(credentials.username)@\(credentials.domain)"
        }
        
        print("[AppConfigurator] Auto-configuring with Jamf Connect user: \(email)")
        
        // Configure all supported apps
        configureMicrosoftOffice(email: email)
        configureDruvaInSync(email: email)
        
        return true
    }
    
    // MARK: - Helper Methods
    
    /// Run a shell command
    /// - Parameters:
    ///   - command: Path to the command
    ///   - arguments: Command arguments
    /// - Returns: True if command succeeded (exit code 0)
    @discardableResult
    private static func runCommand(_ command: String, arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let exitCode = process.terminationStatus
            
            if exitCode != 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                print("[AppConfigurator] Command failed with exit code \(exitCode): \(output)")
            }
            
            return exitCode == 0
        } catch {
            print("[AppConfigurator] Failed to run command: \(error)")
            return false
        }
    }
    
    /// Run a shell script
    /// - Parameter script: Shell script content
    /// - Returns: True if script succeeded
    @discardableResult
    static func runScript(_ script: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            print("[AppConfigurator] Script failed: \(error)")
            return false
        }
    }
    
    // MARK: - Verification
    
    /// Verify if an app is installed
    /// - Parameter bundleId: The app's bundle identifier
    /// - Returns: True if app is installed
    static func isAppInstalled(bundleId: String) -> Bool {
        let workspace = NSWorkspace.shared
        return workspace.urlForApplication(withBundleIdentifier: bundleId) != nil
    }
    
    /// Get list of installed Microsoft Office apps
    /// - Returns: Array of installed Office app names
    static func getInstalledOfficeApps() -> [String] {
        var installed: [String] = []
        
        let officeApps: [(String, String)] = [
            ("com.microsoft.Word", "Word"),
            ("com.microsoft.Excel", "Excel"),
            ("com.microsoft.Powerpoint", "PowerPoint"),
            ("com.microsoft.Outlook", "Outlook"),
            ("com.microsoft.onenote.mac", "OneNote")
        ]
        
        for (bundleId, name) in officeApps {
            if isAppInstalled(bundleId: bundleId) {
                installed.append(name)
            }
        }
        
        return installed
    }
}
