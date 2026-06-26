//
//  OktaAuthWebView.swift
//  Mac Setup Buddy
//
//  Okta OAuth2/OIDC authentication via embedded WebView
//  Similar to JAMF Connect's authentication flow:
//  - Opens Okta login page in embedded browser
//  - Handles MFA natively through Okta's UI
//  - Captures OAuth tokens on successful authentication
//  - Returns user info to the app
//
//  Created: December 2025
//

import SwiftUI
import WebKit
import AppKit

// MARK: - Okta Auth Result
struct OktaAuthResult {
    let accessToken: String
    let idToken: String?
    let refreshToken: String?
    let username: String
    let email: String?
    let firstName: String?
    let lastName: String?
    let groups: [String]?
    
    var fullName: String {
        if let first = firstName, let last = lastName {
            return "\(first) \(last)"
        }
        return username
    }
}

// MARK: - Okta Configuration
struct OktaConfig {
    let domain: String              // e.g., "company.okta.com"
    let clientId: String            // OAuth2 Client ID
    let redirectUri: String         // Redirect URI (e.g., "com.sebastiansantos.mac-setup-buddy://callback")
    let scopes: [String]            // OAuth scopes
    
    var authorizationEndpoint: String {
        "https://\(domain)/oauth2/default/v1/authorize"
    }
    
    var tokenEndpoint: String {
        "https://\(domain)/oauth2/default/v1/token"
    }
    
    var userInfoEndpoint: String {
        "https://\(domain)/oauth2/default/v1/userinfo"
    }
    
    var logoutEndpoint: String {
        "https://\(domain)/oauth2/default/v1/logout"
    }
    
    // Default configuration
    static func defaultConfig(domain: String) -> OktaConfig {
        OktaConfig(
            domain: domain,
            clientId: "0oa1234567890abcdef",  // Replace with actual client ID
            redirectUri: "com.sebastiansantos.mac-setup-buddy://callback",
            scopes: ["openid", "profile", "email", "groups", "offline_access"]
        )
    }
}

// MARK: - PKCE Helper
struct PKCEHelper {
    let codeVerifier: String
    let codeChallenge: String
    let state: String
    
    init() {
        // Generate code verifier (43-128 characters)
        self.codeVerifier = PKCEHelper.generateRandomString(length: 64)
        
        // Generate code challenge (SHA256 hash of verifier, base64url encoded)
        self.codeChallenge = PKCEHelper.generateCodeChallenge(from: codeVerifier)
        
        // Generate state for CSRF protection
        self.state = PKCEHelper.generateRandomString(length: 32)
    }
    
    private static func generateRandomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    private static func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return verifier }
        
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        
        let hashData = Data(hash)
        return hashData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// Required for SHA256
import CommonCrypto

// MARK: - Okta Auth WebView
struct OktaAuthWebView: View {
    let config: OktaConfig
    let onSuccess: (OktaAuthResult) -> Void
    let onCancel: () -> Void
    let onError: (String) -> Void
    
    @State private var isLoading: Bool = true
    @State private var loadingMessage: String = "Connecting to Okta..."
    @State private var pkce = PKCEHelper()
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.08, green: 0.12, blue: 0.25)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                // WebView
                OktaWebViewRepresentable(
                    config: config,
                    pkce: pkce,
                    isLoading: $isLoading,
                    loadingMessage: $loadingMessage,
                    onSuccess: onSuccess,
                    onError: onError
                )
                .background(Color.white)
                .cornerRadius(12)
                .padding(20)
            }
            
            // Loading overlay
            if isLoading {
                loadingOverlay
            }
        }
        .frame(width: 500, height: 700)
    }
    
    private var header: some View {
        HStack {
            Button(action: onCancel) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            Text("Sign in with Okta")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            // Placeholder for symmetry
            Color.clear
                .frame(width: 80, height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                
                Text(loadingMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.2))
            )
        }
    }
}

// MARK: - WebView Representable
struct OktaWebViewRepresentable: NSViewRepresentable {
    let config: OktaConfig
    let pkce: PKCEHelper
    @Binding var isLoading: Bool
    @Binding var loadingMessage: String
    let onSuccess: (OktaAuthResult) -> Void
    let onError: (String) -> Void
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent() // Don't persist cookies
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        
        // Load authorization URL
        if let url = buildAuthorizationURL() {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func buildAuthorizationURL() -> URL? {
        var components = URLComponents(string: config.authorizationEndpoint)
        
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "redirect_uri", value: config.redirectUri),
            URLQueryItem(name: "state", value: pkce.state),
            URLQueryItem(name: "code_challenge", value: pkce.codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "login"), // Always show login
        ]
        
        return components?.url
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: OktaWebViewRepresentable
        
        init(_ parent: OktaWebViewRepresentable) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.loadingMessage = "Loading..."
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            // Don't report cancelled navigations as errors
            if (error as NSError).code != NSURLErrorCancelled {
                parent.onError("Navigation failed: \(error.localizedDescription)")
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            // Check if this is our redirect URI (callback)
            if url.absoluteString.starts(with: parent.config.redirectUri) {
                decisionHandler(.cancel)
                handleCallback(url: url)
                return
            }
            
            decisionHandler(.allow)
        }
        
        private func handleCallback(url: URL) {
            parent.loadingMessage = "Completing authentication..."
            parent.isLoading = true
            
            // Parse the callback URL
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                parent.onError("Invalid callback URL")
                return
            }
            
            // Check for errors
            if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
                let description = components.queryItems?.first(where: { $0.name == "error_description" })?.value ?? error
                parent.onError(description)
                return
            }
            
            // Get authorization code
            guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                parent.onError("No authorization code received")
                return
            }
            
            // Verify state
            let state = components.queryItems?.first(where: { $0.name == "state" })?.value
            if state != parent.pkce.state {
                parent.onError("Invalid state parameter")
                return
            }
            
            // Exchange code for tokens
            exchangeCodeForTokens(code: code)
        }
        
        private func exchangeCodeForTokens(code: String) {
            parent.loadingMessage = "Getting access token..."
            
            guard let url = URL(string: parent.config.tokenEndpoint) else {
                parent.onError("Invalid token endpoint")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let bodyParams = [
                "grant_type": "authorization_code",
                "client_id": parent.config.clientId,
                "code": code,
                "redirect_uri": parent.config.redirectUri,
                "code_verifier": parent.pkce.codeVerifier
            ]
            
            let bodyString = bodyParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&")
            request.httpBody = bodyString.data(using: .utf8)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.parent.onError("Token request failed: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let data = data else {
                        self.parent.onError("No token data received")
                        return
                    }
                    
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let error = json["error"] as? String {
                                let description = json["error_description"] as? String ?? error
                                self.parent.onError(description)
                                return
                            }
                            
                            guard let accessToken = json["access_token"] as? String else {
                                self.parent.onError("No access token in response")
                                return
                            }
                            
                            let idToken = json["id_token"] as? String
                            let refreshToken = json["refresh_token"] as? String
                            
                            // Get user info
                            self.getUserInfo(accessToken: accessToken, idToken: idToken, refreshToken: refreshToken)
                        }
                    } catch {
                        self.parent.onError("Failed to parse token response")
                    }
                }
            }.resume()
        }
        
        private func getUserInfo(accessToken: String, idToken: String?, refreshToken: String?) {
            parent.loadingMessage = "Getting user info..."
            
            guard let url = URL(string: parent.config.userInfoEndpoint) else {
                // Return with just the tokens
                let result = OktaAuthResult(
                    accessToken: accessToken,
                    idToken: idToken,
                    refreshToken: refreshToken,
                    username: "user",
                    email: nil,
                    firstName: nil,
                    lastName: nil,
                    groups: nil
                )
                parent.onSuccess(result)
                return
            }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    var username = "user"
                    var email: String? = nil
                    var firstName: String? = nil
                    var lastName: String? = nil
                    var groups: [String]? = nil
                    
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        username = json["preferred_username"] as? String ?? json["email"] as? String ?? "user"
                        email = json["email"] as? String
                        firstName = json["given_name"] as? String
                        lastName = json["family_name"] as? String
                        groups = json["groups"] as? [String]
                    }
                    
                    let result = OktaAuthResult(
                        accessToken: accessToken,
                        idToken: idToken,
                        refreshToken: refreshToken,
                        username: username,
                        email: email,
                        firstName: firstName,
                        lastName: lastName,
                        groups: groups
                    )
                    
                    self.parent.onSuccess(result)
                }
            }.resume()
        }
    }
}

// MARK: - Okta Auth Sheet (Wrapper for presenting as sheet)
struct OktaAuthSheet: View {
    @Binding var isPresented: Bool
    let oktaDomain: String
    let clientId: String
    let onSuccess: (OktaAuthResult) -> Void
    let onError: (String) -> Void
    
    var body: some View {
        let config = OktaConfig(
            domain: oktaDomain,
            clientId: clientId,
            redirectUri: "com.sebastiansantos.mac-setup-buddy://callback",
            scopes: ["openid", "profile", "email", "groups", "offline_access"]
        )
        
        OktaAuthWebView(
            config: config,
            onSuccess: { result in
                isPresented = false
                onSuccess(result)
            },
            onCancel: {
                isPresented = false
            },
            onError: { error in
                isPresented = false
                onError(error)
            }
        )
    }
}

// MARK: - Preview
