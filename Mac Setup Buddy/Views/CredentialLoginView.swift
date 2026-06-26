//
//  CredentialLoginView.swift
//  Mac Setup Buddy
//
//  A JAMF Connect-style fullscreen login view with:
//  - Full-screen branded background with watermark
//  - Centered login card with logo
//  - Username and password fields
//  - Language selector (like JAMF Connect)
//  - Network/WiFi selector
//  - Multi-line message support with line breaks
//  - Okta authentication integration
//  - Local user account creation
//  - Working Shut Down, Restart, Help buttons
//
//  Configuration can come from:
//  - Command line arguments
//  - Configuration profile (future)
//
//  Updated: December 2025
//

import SwiftUI
import AppKit
import SystemConfiguration
import CoreWLAN

// MARK: - Language Model
struct LanguageOption: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let name: String
    let nativeName: String
    let flag: String
    
    var displayCode: String {
        code.uppercased()
    }
    
    static let supportedLanguages: [LanguageOption] = [
        LanguageOption(code: "en", name: "English", nativeName: "English", flag: "🇺🇸"),
        LanguageOption(code: "es", name: "Spanish", nativeName: "Español", flag: "🇪🇸"),
        LanguageOption(code: "fr", name: "French", nativeName: "Français", flag: "🇫🇷"),
        LanguageOption(code: "de", name: "German", nativeName: "Deutsch", flag: "🇩🇪"),
        LanguageOption(code: "pt", name: "Portuguese", nativeName: "Português", flag: "🇧🇷"),
        LanguageOption(code: "it", name: "Italian", nativeName: "Italiano", flag: "🇮🇹"),
        LanguageOption(code: "ja", name: "Japanese", nativeName: "日本語", flag: "🇯🇵"),
        LanguageOption(code: "zh", name: "Chinese", nativeName: "中文", flag: "🇨🇳"),
        LanguageOption(code: "ko", name: "Korean", nativeName: "한국어", flag: "🇰🇷"),
        LanguageOption(code: "nl", name: "Dutch", nativeName: "Nederlands", flag: "🇳🇱"),
        LanguageOption(code: "pl", name: "Polish", nativeName: "Polski", flag: "🇵🇱"),
        LanguageOption(code: "ru", name: "Russian", nativeName: "Русский", flag: "🇷🇺"),
        LanguageOption(code: "ar", name: "Arabic", nativeName: "العربية", flag: "🇸🇦"),
        LanguageOption(code: "he", name: "Hebrew", nativeName: "עברית", flag: "🇮🇱"),
        LanguageOption(code: "tr", name: "Turkish", nativeName: "Türkçe", flag: "🇹🇷"),
        LanguageOption(code: "sv", name: "Swedish", nativeName: "Svenska", flag: "🇸🇪"),
        LanguageOption(code: "da", name: "Danish", nativeName: "Dansk", flag: "🇩🇰"),
        LanguageOption(code: "nb", name: "Norwegian", nativeName: "Norsk", flag: "🇳🇴"),
        LanguageOption(code: "fi", name: "Finnish", nativeName: "Suomi", flag: "🇫🇮"),
    ]
    
    /// Get the system's preferred language
    static func systemLanguage() -> LanguageOption {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        let languageCode = String(preferredLanguage.prefix(2)).lowercased()
        
        return supportedLanguages.first { $0.code == languageCode }
            ?? supportedLanguages.first! // Default to English
    }
}

// WiFiNetwork model is now in WiFiSelectorSheet.swift

// MARK: - Main Credential Login View
struct CredentialLoginView: View {
    let config: CommandLineConfig
    var onLogin: ((String, String) -> Void)? = nil
    var onCancel: (() -> Void)? = nil
    var onShutdown: (() -> Void)? = nil
    var onRestart: (() -> Void)? = nil
    
    // Login state
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoggingIn: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var isHoveringLogin: Bool = false
    
    // Language & Network state
    @State private var selectedLanguage: LanguageOption = LanguageOption.systemLanguage()
    @State private var showWiFiSheet: Bool = false
    @State private var currentNetworkName: String = "Not Connected"
    
    // Okta state
    @StateObject private var oktaManager = OktaAuthManager()
    @State private var showMFAOverlay: Bool = false
    
    // Brand colors - Mac Setup Buddy blue theme
    private let brandPrimaryColor = Color(red: 0.08, green: 0.15, blue: 0.35)
    private let brandAccentColor = Color(red: 0.25, green: 0.45, blue: 0.85)
    private let cardBackground = Color(red: 0.06, green: 0.12, blue: 0.28)
    private let inputBackground = Color(red: 0.04, green: 0.08, blue: 0.20)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full-screen branded background
                backgroundLayer(size: geometry.size)
                
                // Main content
                VStack(spacing: 0) {
                    // Top bar with language and network selectors
                    topActionBar
                    
                    Spacer()
                    
                    // Login card
                    loginCard
                    
                    // Message area between card and buttons
                    messageArea
                    
                    Spacer()
                    
                    // Bottom action bar (Shut Down, Restart, Help)
                    bottomActionBar
                }
                
                // MFA Pending Overlay
                if showMFAOverlay {
                    mfaOverlay
                }
            }
        }
        .frame(width: config.windowWidth, height: config.windowHeight)
        .onAppear {
            loadCurrentNetwork()
            setupOktaManager()
        }
        .onChange(of: oktaManager.authState) { newState in
            observeAuthState()
        }
    }
    
    // MARK: - Setup Okta Manager
    
    private func setupOktaManager() {
        if let oktaDomain = config.oktaDomain {
            oktaManager.configure(domain: oktaDomain)
            
            // Set up success callback
            oktaManager.onSuccess = { result in
                print("Okta auth successful: \(result.username)")
                self.username = result.email ?? result.username
                self.showMFAOverlay = false
                self.isLoggingIn = false
                
                if self.config.createLocalUser == true {
                    self.createLocalUser(username: result.username, fullName: result.fullName)
                } else {
                    self.completeLogin()
                }
            }
            
            // Set up error callback
            oktaManager.onError = { error in
                self.showMFAOverlay = false
                self.isLoggingIn = false
                self.showErrorMessage(error)
            }
        }
    }
    
    // Observe auth state changes to show/hide MFA overlay
    private func observeAuthState() {
        switch oktaManager.authState {
        case .mfaPending, .mfaRequired:
            showMFAOverlay = true
        case .authenticating:
            showMFAOverlay = false
        case .error(let message):
            showMFAOverlay = false
            isLoggingIn = false
            showErrorMessage(message)
        case .success:
            showMFAOverlay = false
        case .idle:
            showMFAOverlay = false
        }
    }
    
    // MARK: - MFA Overlay
    
    private var mfaOverlay: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            // MFA Card
            VStack(spacing: 24) {
                // Okta Verify Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.system(size: 44))
                        .foregroundColor(.blue)
                }
                
                // Title
                Text("Check Your Phone")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                // Status message
                Text(oktaManager.mfaStatusMessage)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                
                // Instructions
                Text("Tap 'Approve' in Okta Verify to continue")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                
                // Cancel button
                Button(action: cancelMFA) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 8)
            }
            .padding(40)
            .frame(width: 400)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.1, green: 0.15, blue: 0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 30)
        }
    }
    
    private func cancelMFA() {
        oktaManager.cancel()
        showMFAOverlay = false
        isLoggingIn = false
    }
    
    // MARK: - Background Layer
    
    private func backgroundLayer(size: CGSize) -> some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    brandPrimaryColor,
                    Color(red: 0.05, green: 0.10, blue: 0.25),
                    Color(red: 0.03, green: 0.06, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Large watermark on right side
            HStack {
                Spacer()
                Image(systemName: "shield.checkered")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width * 0.4, height: size.height * 0.6)
                    .foregroundColor(.white.opacity(0.03))
                    .offset(x: size.width * 0.1)
            }
            
            // Subtle dot pattern
            Canvas { context, canvasSize in
                let spacing: CGFloat = 50
                for x in stride(from: 0, through: canvasSize.width, by: spacing) {
                    for y in stride(from: 0, through: canvasSize.height, by: spacing) {
                        let rect = CGRect(x: x - 0.5, y: y - 0.5, width: 1, height: 1)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.02)))
                    }
                }
            }
        }
    }
    
    // MARK: - Top Action Bar (Language & Network)
    
    private var topActionBar: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 12) {
                // Language selector
                if config.showLanguageSelector != false {
                    languageSelectorButton
                }
                
                // Network selector
                if config.showNetworkSelector != false {
                    networkSelectorButton
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    private var languageSelectorButton: some View {
        Menu {
            ForEach(LanguageOption.supportedLanguages) { language in
                Button(action: {
                    withAnimation { selectedLanguage = language }
                }) {
                    Label {
                        Text("\(language.displayCode) – \(language.nativeName)")
                    } icon: {
                        Text(language.flag)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedLanguage.displayCode)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(selectedLanguage.flag)
                    .font(.system(size: 14))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .menuIndicator(.hidden)
    }
    
    private var networkSelectorButton: some View {
        Button(action: {
            showWiFiSheet = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: currentNetworkName == "Not Connected" ? "wifi.slash" : "wifi")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showWiFiSheet, arrowEdge: .bottom) {
            WiFiSelectorSheet(isPresented: $showWiFiSheet) { ssid in
                currentNetworkName = ssid
            }
        }
    }
    
    // MARK: - Login Card
    
    private var loginCard: some View {
        VStack(spacing: 24) {
            // Company logo
            companyLogo
            
            // Login form
            VStack(spacing: 16) {
                // Username field
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizedString("Username:"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    TextField("", text: $username)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(inputBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .onSubmit {
                            // Move focus to password field (if possible)
                        }
                }
                
                // Password field
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizedString("Password:"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    HStack {
                        Group {
                            if isPasswordVisible {
                                TextField("", text: $password)
                            } else {
                                SecureField("", text: $password)
                            }
                        }
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .onSubmit {
                            if loginButtonEnabled {
                                performLogin()
                            }
                        }
                        
                        Button(action: { isPasswordVisible.toggle() }) {
                            Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(size: 14))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(inputBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
                
                // Error message
                if showError {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Login button
                Button(action: performLogin) {
                    HStack(spacing: 8) {
                        if isLoggingIn {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        }
                        Text(isLoggingIn ? localizedString("Signing in...") : localizedString("Log In"))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(loginButtonEnabled ? brandAccentColor : brandAccentColor.opacity(0.4))
                    )
                    .shadow(color: loginButtonEnabled && isHoveringLogin ? brandAccentColor.opacity(0.5) : .clear, radius: 12)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!loginButtonEnabled)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHoveringLogin = hovering
                    }
                }
            }
            
            // Helper text below login button
            Text(config.message ?? localizedString("Please enter your corporate credentials"))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(36)
        .frame(width: 380)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground.opacity(0.95))
                .shadow(color: .black.opacity(0.4), radius: 30, y: 15)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.15), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
    }
    
    private var loginButtonEnabled: Bool {
        !username.isEmpty && !password.isEmpty && !isLoggingIn
    }
    
    // MARK: - Company Logo
    
    private var companyLogo: some View {
        VStack(spacing: 8) {
            if let logoPath = config.bannerImage, !logoPath.isEmpty,
               let nsImage = NSImage(contentsOfFile: logoPath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 70)
            } else {
                // Default Mac Setup Buddy-style logo
                HStack(spacing: 12) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 42, weight: .light))
                        .foregroundColor(.white)
                    
                    Text(config.title ?? "Mac Setup Buddy")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Message Area (Between Card and Buttons)
    
    private var messageArea: some View {
        Group {
            if let infoMessage = config.loginInfoMessage, !infoMessage.isEmpty {
                VStack(spacing: 6) {
                    // Parse message for line breaks (\n or literal \n)
                    let parsedMessage = infoMessage
                        .replacingOccurrences(of: "\\n", with: "\n")
                        .replacingOccurrences(of: "<br>", with: "\n")
                        .replacingOccurrences(of: "<br/>", with: "\n")
                    
                    Text(parsedMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 24)
                .frame(maxWidth: 700)
            }
        }
    }
    
    // MARK: - Bottom Action Bar (Shut Down, Restart, Help)
    
    private var bottomActionBar: some View {
        HStack(spacing: 60) {
            // Shut Down - WORKING
            actionButton(
                icon: "power",
                label: localizedString("Shut Down"),
                action: performShutdown
            )
            
            // Restart - WORKING
            actionButton(
                icon: "arrow.clockwise",
                label: localizedString("Restart"),
                action: performRestart
            )
            
            // Help - WORKING
            actionButton(
                icon: "questionmark.circle",
                label: localizedString("Help"),
                action: showHelp
            )
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 60)
        .frame(maxWidth: 500)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.bottom, 30)
    }
    
    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
    
    // MARK: - Login Actions
    
    private func performLogin() {
        guard !username.isEmpty && !password.isEmpty else {
            showErrorMessage(localizedString("Please enter both username and password"))
            return
        }
        
        isLoggingIn = true
        showError = false
        
        // Check if Okta validation is enabled
        if let _ = config.oktaDomain {
            // Use OktaAuthManager for authentication with MFA support
            Task {
                await oktaManager.authenticate(username: username, password: password)
            }
        } else {
            // Direct login without Okta
            completeLogin()
        }
    }
    
    private func createLocalUser(username: String, fullName: String) {
        print("Creating local account...")
        
        // Sanitize username for local account (remove domain if email)
        // e.g., "sebastian.santos@example.com" → "sebastian.santos"
        let localUsername = username.contains("@")
            ? String(username.split(separator: "@").first ?? Substring(username))
            : username
        
        print("Local username will be: \(localUsername)")
        
        // Escape special characters for shell
        func shellEscape(_ string: String) -> String {
            return string
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "'\\''")
        }
        
        let escapedUsername = shellEscape(localUsername)
        let escapedFullName = shellEscape(fullName)
        let escapedPassword = shellEscape(password)
        
        // Use sysadminctl which is the modern way to create users
        // -admin flag makes the user an administrator
        let createUserCommand = """
        /usr/sbin/sysadminctl -addUser '\(escapedUsername)' -fullName '\(escapedFullName)' -password '\(escapedPassword)' -home /Users/'\(escapedUsername)' -shell /bin/zsh -admin
        """
        
        // AppleScript to run with admin privileges
        let appleScriptSource = """
        do shell script "\(createUserCommand.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))" with administrator privileges
        """
        
        print("Creating user: \(localUsername)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            var errorInfo: NSDictionary? = nil
            if let appleScript = NSAppleScript(source: appleScriptSource) {
                let result = appleScript.executeAndReturnError(&errorInfo)
                
                DispatchQueue.main.async {
                    if let errorInfo = errorInfo {
                        let errorMessage = errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                        print("User creation error: \(errorMessage)")
                        
                        // Check if user already exists
                        if errorMessage.contains("already exists") || errorMessage.contains("-14") {
                            print("User \(localUsername) already exists, continuing...")
                        }
                        
                        // Still complete login even if user creation fails
                        self.completeLogin()
                    } else {
                        print("Local user created successfully: \(localUsername)")
                        if let output = result.stringValue {
                            print("Output: \(output)")
                        }
                        self.completeLogin()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    print("Failed to create AppleScript")
                    self.completeLogin()
                }
            }
        }
    }
    
    private func completeLogin() {
        // Output captured credentials for script consumption
        print("Captured username: \(username)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let onLogin = onLogin {
                onLogin(username, password)
            } else {
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    private func showErrorMessage(_ message: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            errorMessage = message
            showError = true
        }
    }
    
    // MARK: - Bottom Button Actions (WORKING!)
    
    private func performShutdown() {
        let alert = NSAlert()
        alert.messageText = localizedString("Shut Down")
        alert.informativeText = localizedString("Are you sure you want to shut down this Mac?\n\nAny unsaved changes will be lost.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: localizedString("Shut Down"))
        alert.addButton(withTitle: localizedString("Cancel"))
        
        // Style the alert for dark mode
        alert.window.appearance = NSAppearance(named: .darkAqua)
        
        if alert.runModal() == .alertFirstButtonReturn {
            if let onShutdown = onShutdown {
                onShutdown()
            } else {
                // Execute actual shutdown
                executeSystemCommand("shut down")
            }
        }
    }
    
    private func performRestart() {
        let alert = NSAlert()
        alert.messageText = localizedString("Restart")
        alert.informativeText = localizedString("Are you sure you want to restart this Mac?\n\nAny unsaved changes will be lost.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: localizedString("Restart"))
        alert.addButton(withTitle: localizedString("Cancel"))
        
        // Style the alert for dark mode
        alert.window.appearance = NSAppearance(named: .darkAqua)
        
        if alert.runModal() == .alertFirstButtonReturn {
            if let onRestart = onRestart {
                onRestart()
            } else {
                // Execute actual restart
                executeSystemCommand("restart")
            }
        }
    }
    
    private func executeSystemCommand(_ command: String) {
        let script = "tell application \"System Events\" to \(command)"
        if let appleScript = NSAppleScript(source: script) {
            var errorInfo: NSDictionary? = nil
            appleScript.executeAndReturnError(&errorInfo)
            if let errorInfo = errorInfo {
                print("System command error: \(errorInfo)")
                // Fallback: try with shell command
                let shellScript = command == "shut down"
                    ? "do shell script \"sudo shutdown -h now\" with administrator privileges"
                    : "do shell script \"sudo shutdown -r now\" with administrator privileges"
                if let fallbackScript = NSAppleScript(source: shellScript) {
                    var fallbackError: NSDictionary? = nil
                    fallbackScript.executeAndReturnError(&fallbackError)
                }
            }
        }
    }
    
    private func showHelp() {
        let alert = NSAlert()
        alert.messageText = localizedString("Login Help")
        
        let helpText = """
        \(localizedString("Enter your corporate credentials to sign in."))
        
        \(localizedString("Username")): \(localizedString("Your email address or network ID"))
        \(localizedString("Password")): \(localizedString("Your network password"))
        
        \(localizedString("If you're having trouble signing in:"))
        • \(localizedString("Check your network connection"))
        • \(localizedString("Verify your username is correct"))
        • \(localizedString("Make sure Caps Lock is off"))
        
        \(config.helpContactInfo ?? "IT Support: it-support@company.com")
        """
        
        alert.informativeText = helpText
        alert.alertStyle = .informational
        alert.addButton(withTitle: localizedString("OK"))
        
        // Style the alert for dark mode
        alert.window.appearance = NSAppearance(named: .darkAqua)
        
        alert.runModal()
    }
    
    // MARK: - Network Functions
    
    private func loadCurrentNetwork() {
        DispatchQueue.global(qos: .userInitiated).async {
            var networkName = "Not Connected"
            
            if let interface = CWWiFiClient.shared().interface() {
                networkName = interface.ssid() ?? "Not Connected"
            }
            
            DispatchQueue.main.async {
                self.currentNetworkName = networkName
            }
        }
        
    }
    
    // MARK: - Localization Helper
    
    private func localizedString(_ key: String) -> String {
        // Map of translations
        let translations: [String: [String: String]] = [
            "es": [
                "Username:": "Usuario:",
                "Password:": "Contraseña:",
                "Log In": "Iniciar Sesión",
                "Signing in...": "Iniciando sesión...",
                "Shut Down": "Apagar",
                "Restart": "Reiniciar",
                "Help": "Ayuda",
                "Cancel": "Cancelar",
                "Please enter your corporate credentials": "Por favor ingrese sus credenciales corporativas",
                "Please enter both username and password": "Por favor ingrese usuario y contraseña",
                "Invalid username or password": "Usuario o contraseña inválidos",
            ],
            "fr": [
                "Username:": "Nom d'utilisateur:",
                "Password:": "Mot de passe:",
                "Log In": "Connexion",
                "Signing in...": "Connexion en cours...",
                "Shut Down": "Éteindre",
                "Restart": "Redémarrer",
                "Help": "Aide",
                "Cancel": "Annuler",
            ],
            "de": [
                "Username:": "Benutzername:",
                "Password:": "Passwort:",
                "Log In": "Anmelden",
                "Signing in...": "Anmeldung...",
                "Shut Down": "Ausschalten",
                "Restart": "Neustart",
                "Help": "Hilfe",
                "Cancel": "Abbrechen",
            ],
        ]
        
        // Return translated string or original
        if let langTranslations = translations[selectedLanguage.code],
           let translated = langTranslations[key] {
            return translated
        }
        return key
    }
}

// MARK: - Preview

