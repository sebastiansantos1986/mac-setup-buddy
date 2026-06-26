//
//  OktaAuthManager.swift
//  Mac Setup Buddy
//
//  Okta Primary Authentication with MFA Push support
//  Based on working implementation - handles:
//  - Primary authentication
//  - MFA push notifications via Okta Verify
//  - Polling for MFA completion
//  - User profile extraction
//
//  Created: December 2025
//

import Foundation
import SwiftUI
import Combine

// MARK: - Okta Primary Auth Result
struct OktaPrimaryAuthResult {
    let sessionToken: String
    let username: String
    let email: String?
    let firstName: String?
    let lastName: String?
    
    var fullName: String {
        if let first = firstName, let last = lastName {
            return "\(first) \(last)"
        }
        return username
    }
}

// MARK: - Okta API Response Models
struct OktaAuthResponse: Codable {
    let status: String
    let sessionToken: String?
    let stateToken: String?
    let expiresAt: String?
    let embedded: OktaEmbedded?
    let errorSummary: String?
    let errorCode: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case sessionToken
        case stateToken
        case expiresAt
        case embedded = "_embedded"
        case errorSummary
        case errorCode
    }
}

struct OktaEmbedded: Codable {
    let factors: [OktaFactor]?
    let user: OktaUser?
}

struct OktaFactor: Codable, Identifiable {
    let id: String
    let factorType: String
    let provider: String
    let vendorName: String?
    let links: OktaFactorLinks?
    
    enum CodingKeys: String, CodingKey {
        case id
        case factorType
        case provider
        case vendorName
        case links = "_links"
    }
}

struct OktaFactorLinks: Codable {
    let verify: OktaLink?
}

struct OktaLink: Codable {
    let href: String
}

struct OktaUser: Codable {
    let id: String
    let profile: OktaUserProfile?
}

struct OktaUserProfile: Codable {
    let login: String?
    let firstName: String?
    let lastName: String?
    let email: String?
}

// MARK: - Auth State
enum OktaAuthState: Equatable {
    case idle
    case authenticating
    case mfaRequired([OktaFactor])
    case mfaPending(String) // Factor type description
    case success(String) // Session token
    case error(String)
    
    static func == (lhs: OktaAuthState, rhs: OktaAuthState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.authenticating, .authenticating):
            return true
        case (.mfaRequired, .mfaRequired),
             (.mfaPending, .mfaPending),
             (.success, .success),
             (.error, .error):
            return true
        default:
            return false
        }
    }
}

// MARK: - Auth Errors
enum OktaAuthError: LocalizedError {
    case invalidResponse
    case invalidCredentials
    case httpError(Int)
    case mfaFailed(String)
    case timeout
    case noMfaFactors
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidCredentials:
            return "Invalid username or password"
        case .httpError(let code):
            return "Server error (HTTP \(code))"
        case .mfaFailed(let reason):
            return "MFA verification failed: \(reason)"
        case .timeout:
            return "MFA verification timed out"
        case .noMfaFactors:
            return "No MFA factors available"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Okta Authentication Manager
@MainActor
class OktaAuthManager: ObservableObject {
    @Published var authState: OktaAuthState = .idle
    @Published var mfaStatusMessage: String = ""
    @Published var availableFactors: [OktaFactor] = []
    
    private var oktaDomain: String = ""
    private var stateToken: String?
    private var pollingTask: Task<Void, Never>?
    private var storedUsername: String = ""
    private var userProfile: OktaUserProfile?
    
    // Callbacks
    var onSuccess: ((OktaPrimaryAuthResult) -> Void)?
    var onError: ((String) -> Void)?
    
    // MARK: - Configuration
    func configure(domain: String) {
        // Clean up domain - remove https:// if present
        var cleanDomain = domain
        if cleanDomain.hasPrefix("https://") {
            cleanDomain = String(cleanDomain.dropFirst(8))
        }
        if cleanDomain.hasPrefix("http://") {
            cleanDomain = String(cleanDomain.dropFirst(7))
        }
        // Remove trailing slash
        if cleanDomain.hasSuffix("/") {
            cleanDomain = String(cleanDomain.dropLast())
        }
        self.oktaDomain = cleanDomain
    }
    
    // MARK: - Primary Authentication
    func authenticate(username: String, password: String) async {
        guard !oktaDomain.isEmpty else {
            authState = .error("Okta domain not configured")
            return
        }
        
        storedUsername = username
        authState = .authenticating
        
        do {
            let response = try await performPrimaryAuth(username: username, password: password)
            await handleAuthResponse(response)
        } catch let error as OktaAuthError {
            authState = .error(error.localizedDescription)
            onError?(error.localizedDescription)
        } catch {
            authState = .error("Authentication failed: \(error.localizedDescription)")
            onError?("Authentication failed: \(error.localizedDescription)")
        }
    }
    
    private func performPrimaryAuth(username: String, password: String) async throws -> OktaAuthResponse {
        let url = URL(string: "https://\(oktaDomain)/api/v1/authn")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "username": username,
            "password": password,
            "options": [
                "multiOptionalFactorEnroll": false,
                "warnBeforePasswordExpired": false
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OktaAuthError.invalidResponse
        }
        
        // Try to decode response for error details
        if let oktaResponse = try? JSONDecoder().decode(OktaAuthResponse.self, from: data) {
            if httpResponse.statusCode == 401 || oktaResponse.errorCode != nil {
                let message = oktaResponse.errorSummary ?? "Invalid credentials"
                throw OktaAuthError.invalidCredentials
            }
            
            if httpResponse.statusCode == 200 {
                return oktaResponse
            }
        }
        
        if httpResponse.statusCode == 401 {
            throw OktaAuthError.invalidCredentials
        }
        
        guard httpResponse.statusCode == 200 else {
            throw OktaAuthError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(OktaAuthResponse.self, from: data)
    }
    
    // MARK: - Handle Auth Response
    private func handleAuthResponse(_ response: OktaAuthResponse) async {
        // Store user profile if available
        userProfile = response.embedded?.user?.profile
        
        switch response.status {
        case "SUCCESS":
            // No MFA required - authentication complete
            if let sessionToken = response.sessionToken {
                completeAuthentication(sessionToken: sessionToken)
            } else {
                authState = .error("No session token received")
            }
            
        case "MFA_REQUIRED":
            stateToken = response.stateToken
            
            if let factors = response.embedded?.factors, !factors.isEmpty {
                availableFactors = factors
                
                // Auto-trigger push if available
                if let pushFactor = factors.first(where: { $0.factorType == "push" && $0.provider == "OKTA" }) {
                    authState = .mfaPending("Okta Verify Push")
                    mfaStatusMessage = "Sending push notification to Okta Verify..."
                    await triggerPushNotification(factor: pushFactor)
                } else {
                    // Show available factors
                    authState = .mfaRequired(factors)
                }
            } else {
                authState = .error("MFA required but no factors available.\nPlease contact IT support.")
            }
            
        case "MFA_ENROLL":
            authState = .error("MFA enrollment required.\nPlease enroll in Okta Verify first.")
            
        case "MFA_CHALLENGE":
            // Already in MFA challenge - continue polling
            authState = .mfaPending("Waiting for verification")
            
        case "LOCKED_OUT":
            authState = .error("Your account is locked.\nPlease contact IT support.")
            
        case "PASSWORD_EXPIRED":
            authState = .error("Your password has expired.\nPlease reset your password first.")
            
        case "PASSWORD_WARN":
            // Password expiring soon, but allow login
            if let sessionToken = response.sessionToken {
                completeAuthentication(sessionToken: sessionToken)
            }
            
        default:
            authState = .error("Unexpected status: \(response.status)")
        }
    }
    
    // MARK: - MFA Push Flow
    func triggerFactor(_ factor: OktaFactor) async {
        switch factor.factorType {
        case "push":
            authState = .mfaPending("Okta Verify Push")
            mfaStatusMessage = "Sending push notification..."
            await triggerPushNotification(factor: factor)
            
        case "token:software:totp":
            // For TOTP, we'd show a code entry UI
            authState = .mfaPending("Enter TOTP Code")
            mfaStatusMessage = "Please enter the code from your authenticator app"
            
        default:
            authState = .error("Unsupported MFA factor: \(factor.factorType)")
        }
    }
    
    private func triggerPushNotification(factor: OktaFactor) async {
        guard let stateToken = stateToken,
              let verifyUrl = factor.links?.verify?.href else {
            authState = .error("Unable to initiate MFA verification")
            return
        }
        
        do {
            var request = URLRequest(url: URL(string: verifyUrl)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 30
            
            let body: [String: String] = ["stateToken": stateToken]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw OktaAuthError.mfaFailed("Failed to send push notification")
            }
            
            let oktaResponse = try JSONDecoder().decode(OktaAuthResponse.self, from: data)
            
            // Check if immediate success (rare)
            if oktaResponse.status == "SUCCESS", let sessionToken = oktaResponse.sessionToken {
                completeAuthentication(sessionToken: sessionToken)
                return
            }
            
            // Start polling for MFA completion
            mfaStatusMessage = "Push sent! Waiting for approval..."
            await pollForMFACompletion(verifyUrl: verifyUrl)
            
        } catch {
            authState = .error("Failed to send push: \(error.localizedDescription)")
        }
    }
    
    private func pollForMFACompletion(verifyUrl: String) async {
        guard let stateToken = stateToken else { return }
        
        // Cancel any existing polling
        pollingTask?.cancel()
        
        pollingTask = Task {
            var attempts = 0
            let maxAttempts = 60 // 60 seconds timeout
            
            while attempts < maxAttempts && !Task.isCancelled {
                do {
                    // Wait 1 second between polls
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    
                    var request = URLRequest(url: URL(string: verifyUrl)!)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    
                    let body: [String: String] = ["stateToken": stateToken]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    
                    let (data, _) = try await URLSession.shared.data(for: request)
                    let response = try JSONDecoder().decode(OktaAuthResponse.self, from: data)
                    
                    switch response.status {
                    case "SUCCESS":
                        if let sessionToken = response.sessionToken {
                            await MainActor.run {
                                self.completeAuthentication(sessionToken: sessionToken)
                            }
                        }
                        return
                        
                    case "MFA_CHALLENGE":
                        // Still waiting - update message
                        attempts += 1
                        await MainActor.run {
                            self.mfaStatusMessage = "Waiting for approval... (\(maxAttempts - attempts)s)"
                        }
                        continue
                        
                    case "MFA_REJECTED":
                        await MainActor.run {
                            self.authState = .error("MFA was rejected.\nPlease try again.")
                        }
                        return
                        
                    default:
                        await MainActor.run {
                            self.authState = .error("MFA failed: \(response.status)")
                        }
                        return
                    }
                    
                } catch {
                    if !Task.isCancelled {
                        await MainActor.run {
                            self.authState = .error("MFA polling error: \(error.localizedDescription)")
                        }
                    }
                    return
                }
            }
            
            // Timeout
            if !Task.isCancelled {
                await MainActor.run {
                    self.authState = .error("MFA verification timed out.\nPlease try again.")
                }
            }
        }
    }
    
    // MARK: - Complete Authentication
    private func completeAuthentication(sessionToken: String) {
        authState = .success(sessionToken)
        
        let result = OktaPrimaryAuthResult(
            sessionToken: sessionToken,
            username: userProfile?.login ?? storedUsername,
            email: userProfile?.email ?? userProfile?.login ?? storedUsername,
            firstName: userProfile?.firstName,
            lastName: userProfile?.lastName
        )
        
        onSuccess?(result)
    }
    
    // MARK: - Cancel
    func cancel() {
        pollingTask?.cancel()
        pollingTask = nil
        stateToken = nil
        authState = .idle
    }
    
    func reset() {
        cancel()
        storedUsername = ""
        userProfile = nil
        availableFactors = []
        mfaStatusMessage = ""
    }
}
