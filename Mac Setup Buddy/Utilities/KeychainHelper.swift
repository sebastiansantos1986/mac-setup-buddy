//
//  KeychainHelper.swift
//  Mac Setup Buddy
//
//  Secure storage and retrieval of credentials using macOS Keychain
//

import Foundation
import Security

class KeychainHelper {
    
    // Keychain service identifier
    private static let serviceName = "com.sebastiansantos.mac-setup-buddy.credentials"
    
    // MARK: - Save Credentials
    
    /// Save username and password to Keychain
    /// - Parameters:
    ///   - username: The user's email/username
    ///   - password: The user's password
    /// - Returns: True if saved successfully
    @discardableResult
    static func saveCredentials(username: String, password: String) -> Bool {
        // First, try to delete any existing entry
        deleteCredentials(for: username)
        
        guard let passwordData = password.data(using: .utf8) else {
            print("[Keychain] Failed to encode password")
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: username,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("[Keychain] Credentials saved for \(username)")
            return true
        } else {
            print("[Keychain] Failed to save credentials: \(status)")
            return false
        }
    }
    
    // MARK: - Retrieve Credentials
    
    /// Retrieve password for a given username
    /// - Parameter username: The username to look up
    /// - Returns: The password if found, nil otherwise
    static func getPassword(for username: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: username,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            let password = String(data: data, encoding: .utf8)
            print("[Keychain] Retrieved credentials for \(username)")
            return password
        } else {
            print("[Keychain] No credentials found for \(username)")
            return nil
        }
    }
    
    // MARK: - Delete Credentials
    
    /// Delete stored credentials for a username
    /// - Parameter username: The username to delete
    /// - Returns: True if deleted or not found
    @discardableResult
    static func deleteCredentials(for username: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: username
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            print("[Keychain] Deleted credentials for \(username)")
            return true
        } else {
            print("[Keychain] Failed to delete credentials: \(status)")
            return false
        }
    }
    
    // MARK: - Check If Credentials Exist
    
    /// Check if credentials exist for a username
    /// - Parameter username: The username to check
    /// - Returns: True if credentials exist
    static func hasCredentials(for username: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: username,
            kSecReturnData as String: false
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Save to Internet Password (for app-specific access)
    
    /// Save credentials as Internet Password (accessible by specific apps)
    /// - Parameters:
    ///   - username: User email/username
    ///   - password: User password
    ///   - server: Server domain (e.g., "login.microsoftonline.com")
    /// - Returns: True if saved successfully
    @discardableResult
    static func saveInternetPassword(username: String, password: String, server: String) -> Bool {
        // Delete existing entry first
        deleteInternetPassword(username: username, server: server)
        
        guard let passwordData = password.data(using: .utf8) else {
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: username,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("[Keychain] Internet password saved for \(server)")
            return true
        } else {
            print("[Keychain] Failed to save internet password: \(status)")
            return false
        }
    }
    
    /// Delete internet password entry
    @discardableResult
    static func deleteInternetPassword(username: String, server: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: username
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Bulk Operations
    
    /// Save credentials for multiple services at once
    /// - Parameters:
    ///   - username: User email/username
    ///   - password: User password
    ///   - servers: List of server domains
    /// - Returns: Dictionary of server -> success status
    static func saveCredentialsForServices(username: String, password: String, servers: [String]) -> [String: Bool] {
        var results: [String: Bool] = [:]
        
        for server in servers {
            results[server] = saveInternetPassword(username: username, password: password, server: server)
        }
        
        // Also save to generic keychain
        results["generic"] = saveCredentials(username: username, password: password)
        
        return results
    }
    
    // MARK: - Microsoft-specific
    
    /// Save credentials for Microsoft services
    static func saveMicrosoftCredentials(username: String, password: String) -> Bool {
        let microsoftServers = [
            "login.microsoftonline.com",
            "login.microsoft.com",
            "outlook.office365.com",
            "outlook.office.com"
        ]
        
        let results = saveCredentialsForServices(username: username, password: password, servers: microsoftServers)
        return results.values.contains(true)
    }
    
    // MARK: - Druva-specific
    
    /// Save credentials for Druva InSync
    static func saveDruvaCredentials(username: String, password: String) -> Bool {
        return saveInternetPassword(username: username, password: password, server: "cloud.druva.com")
    }
}
