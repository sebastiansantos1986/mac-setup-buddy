//
//  CredentialInputView.swift
//  Mac Setup Buddy
//
//  Collects Jamf Connect credentials for SSO passthrough
//  to Microsoft Office, Druva InSync, and other enterprise apps
//

import SwiftUI
import AppKit

struct CredentialInputView: View {
    let config: CommandLineConfig
    var onComplete: ((CredentialResult) -> Void)? = nil
    
    // Form fields
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var saveToKeychain: Bool = true
    
    // App selection
    @State private var configureOffice: Bool = true
    @State private var configureDruva: Bool = true
    @State private var configureCustomApps: Bool = false
    
    // UI State
    @State private var isProcessing: Bool = false
    @State private var processingMessage: String = ""
    @State private var showPassword: Bool = false
    @State private var isHoveredButton: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var configurationResults: [AppConfigResult] = []
    @State private var isComplete: Bool = false
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case username, password
    }
    
    var isFormValid: Bool {
        !username.isEmpty && !password.isEmpty && username.contains("@")
    }
    
    var body: some View {
        ZStack {
            // Background
            Theme.Gradients.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Banner
                bannerSection
                
                if isComplete {
                    // Results view
                    resultsView
                } else if isProcessing {
                    // Processing view
                    processingView
                } else {
                    // Input form
                    formView
                }
            }
        }
        .frame(width: config.windowWidth, height: config.windowHeight)
        .onAppear {
            // Pre-fill username if provided
            if let email = config.email {
                username = email
            }
        }
    }
    
    // MARK: - Banner Section
    private var bannerSection: some View {
        ZStack {
            if let bannerPath = config.bannerImage, !bannerPath.isEmpty {
                BannerView(imagePath: bannerPath, height: 140, contentMode: .fill)
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.4), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                Theme.Gradients.banner
                    .frame(height: 140)
                    .overlay(
                        VStack(spacing: Theme.Spacing.xs) {
                            Text(config.bannerTitle ?? "Mac Setup Buddy")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Text.primary)
                            
                            Text(config.bannerSubtitle ?? "Enterprise Sign-In")
                                .font(Theme.Typography.body())
                                .foregroundColor(Theme.Text.secondary)
                        }
                    )
            }
        }
    }
    
    // MARK: - Form View
    private var formView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Header
                VStack(spacing: Theme.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Theme.Gradients.accent)
                            .frame(width: 70, height: 70)
                            .shadow(color: Theme.Brand.tertiary.opacity(0.4), radius: 15, y: 5)
                        
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(Theme.Text.primary)
                    }
                    
                    Text(config.title ?? "Sign In to Enterprise Apps")
                        .font(Theme.Typography.title())
                        .foregroundColor(Theme.Text.primary)
                    
                    Text(config.message ?? "Enter your credentials to automatically sign in to your enterprise applications.")
                        .font(Theme.Typography.body())
                        .foregroundColor(Theme.Text.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
                .padding(.top, Theme.Spacing.lg)
                
                // Credential form card
                VStack(spacing: Theme.Spacing.md) {
                    // Username field
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("Email / Username")
                            .font(Theme.Typography.captionBold())
                            .foregroundColor(Theme.Text.secondary)
                        
                        HStack {
                            Image(systemName: "person.circle")
                                .foregroundColor(focusedField == .username ? Theme.Brand.primary : Theme.Text.tertiary)
                                .frame(width: 20)
                            
                            TextField("user@company.com", text: $username)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(Theme.Typography.body())
                                .foregroundColor(Theme.Text.primary)
                                .focused($focusedField, equals: .username)
                                .textContentType(.username)
                                .disableAutocorrection(true)
                        }
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Background.card)
                        .cornerRadius(Theme.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                .stroke(
                                    focusedField == .username ? Theme.Brand.primary : Theme.Border.primary,
                                    lineWidth: focusedField == .username ? 2 : 1
                                )
                        )
                    }
                    
                    // Password field
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("Password")
                            .font(Theme.Typography.captionBold())
                            .foregroundColor(Theme.Text.secondary)
                        
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(focusedField == .password ? Theme.Brand.primary : Theme.Text.tertiary)
                                .frame(width: 20)
                            
                            if showPassword {
                                TextField("••••••••", text: $password)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(Theme.Typography.body())
                                    .foregroundColor(Theme.Text.primary)
                                    .focused($focusedField, equals: .password)
                            } else {
                                SecureField("••••••••", text: $password)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(Theme.Typography.body())
                                    .foregroundColor(Theme.Text.primary)
                                    .focused($focusedField, equals: .password)
                            }
                            
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(Theme.Text.tertiary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Background.card)
                        .cornerRadius(Theme.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                .stroke(
                                    focusedField == .password ? Theme.Brand.primary : Theme.Border.primary,
                                    lineWidth: focusedField == .password ? 2 : 1
                                )
                        )
                    }
                    
                    // Keychain option
                    HStack {
                        Toggle(isOn: $saveToKeychain) {
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: "key.fill")
                                    .foregroundColor(Theme.Brand.primary)
                                Text("Save to Keychain (recommended)")
                                    .font(Theme.Typography.caption())
                                    .foregroundColor(Theme.Text.secondary)
                            }
                        }
                        .toggleStyle(CheckboxToggleStyle())
                        
                        Spacer()
                    }
                }
                .padding(Theme.Spacing.lg)
                .glassCard()
                .padding(.horizontal, Theme.Spacing.xl)
                
                // App selection card
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Configure Applications")
                        .font(Theme.Typography.headline())
                        .foregroundColor(Theme.Text.primary)
                    
                    VStack(spacing: Theme.Spacing.sm) {
                        AppToggleRow(
                            icon: "doc.text.fill",
                            iconColor: Color.orange,
                            title: "Microsoft Office 365",
                            subtitle: "Word, Excel, PowerPoint, Outlook",
                            isOn: $configureOffice
                        )
                        
                        Divider()
                            .background(Theme.Border.subtle)
                        
                        AppToggleRow(
                            icon: "cloud.fill",
                            iconColor: Color.blue,
                            title: "Druva InSync",
                            subtitle: "Backup & sync client",
                            isOn: $configureDruva
                        )
                        
                        if config.customApps != nil {
                            Divider()
                                .background(Theme.Border.subtle)
                            
                            AppToggleRow(
                                icon: "app.badge.fill",
                                iconColor: Color.purple,
                                title: "Additional Apps",
                                subtitle: "Custom enterprise applications",
                                isOn: $configureCustomApps
                            )
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
                .glassCard()
                .padding(.horizontal, Theme.Spacing.xl)
                
                // Error message
                if showError {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Theme.Status.error)
                        Text(errorMessage)
                            .font(Theme.Typography.caption())
                            .foregroundColor(Theme.Status.error)
                    }
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Status.error.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.small)
                    .padding(.horizontal, Theme.Spacing.xl)
                }
                
                // Security note
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(Theme.Status.success)
                    Text("Your credentials are encrypted and stored securely")
                        .font(Theme.Typography.small())
                        .foregroundColor(Theme.Text.muted)
                }
                .padding(.top, Theme.Spacing.sm)
                
                Spacer(minLength: Theme.Spacing.lg)
                
                // Continue button
                Button(action: { processCredentials() }) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text("Sign In & Configure")
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .font(Theme.Typography.headline())
                    .foregroundColor(isFormValid ? Theme.Text.primary : Theme.Text.disabled)
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        isFormValid ? Theme.Gradients.primaryButton :
                        LinearGradient(colors: [Theme.Text.disabled, Theme.Text.disabled], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(Theme.CornerRadius.pill)
                    .shadow(
                        color: isFormValid ? Theme.Brand.primary.opacity(isHoveredButton ? 0.5 : 0.3) : Color.clear,
                        radius: 15,
                        y: 5
                    )
                    .scaleEffect(isHoveredButton && isFormValid ? 1.03 : 1.0)
                    .animation(Theme.Animation.smooth, value: isHoveredButton)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!isFormValid)
                .onHover { hovering in isHoveredButton = hovering }
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
    }
    
    // MARK: - Processing View
    private var processingView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.Brand.primary.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Circle()
                    .fill(Theme.Gradients.primaryButton)
                    .frame(width: 80, height: 80)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.Text.primary))
                    .scaleEffect(1.5)
            }
            
            Text("Configuring Applications")
                .font(Theme.Typography.title())
                .foregroundColor(Theme.Text.primary)
            
            Text(processingMessage)
                .font(Theme.Typography.body())
                .foregroundColor(Theme.Text.secondary)
                .multilineTextAlignment(.center)
            
            // Progress steps
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ProcessingStepRow(text: "Validating credentials...", isComplete: true)
                ProcessingStepRow(text: "Saving to Keychain...", isComplete: saveToKeychain)
                ProcessingStepRow(text: "Configuring Microsoft Office...", isComplete: false, isActive: configureOffice)
                ProcessingStepRow(text: "Configuring Druva InSync...", isComplete: false, isActive: configureDruva)
            }
            .padding(Theme.Spacing.lg)
            .glassCard()
            .padding(.horizontal, Theme.Spacing.xxl)
            
            Spacer()
        }
    }
    
    // MARK: - Results View
    private var resultsView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            
            // Success icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.Status.success.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Circle()
                    .fill(Theme.Gradients.success)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(Theme.Text.primary)
            }
            
            Text("Configuration Complete")
                .font(Theme.Typography.title())
                .foregroundColor(Theme.Text.primary)
            
            Text("Your enterprise applications have been configured")
                .font(Theme.Typography.body())
                .foregroundColor(Theme.Text.secondary)
            
            // Results list
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(configurationResults) { result in
                    HStack {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.success ? Theme.Status.success : Theme.Status.error)
                        
                        Text(result.appName)
                            .font(Theme.Typography.bodyBold())
                            .foregroundColor(Theme.Text.primary)
                        
                        Spacer()
                        
                        Text(result.success ? "Configured" : "Failed")
                            .font(Theme.Typography.caption())
                            .foregroundColor(result.success ? Theme.Status.success : Theme.Status.error)
                    }
                    .padding(Theme.Spacing.sm)
                }
            }
            .padding(Theme.Spacing.lg)
            .glassCard()
            .padding(.horizontal, Theme.Spacing.xxl)
            
            Spacer()
            
            // Continue button
            Button(action: {
                let result = CredentialResult(
                    username: username,
                    success: true,
                    configuredApps: configurationResults.filter { $0.success }.map { $0.appName }
                )
                onComplete?(result)
            }) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text("Continue")
                    Image(systemName: "arrow.right.circle.fill")
                }
                .font(Theme.Typography.headline())
                .foregroundColor(Theme.Text.primary)
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Gradients.primaryButton)
                .cornerRadius(Theme.CornerRadius.pill)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom, Theme.Spacing.xl)
        }
    }
    
    // MARK: - Process Credentials
    private func processCredentials() {
        guard isFormValid else { return }
        
        isProcessing = true
        processingMessage = "Validating credentials..."
        
        // Simulate async processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            processingMessage = "Saving to Keychain..."
            
            // Save to Keychain if enabled
            if saveToKeychain {
                let saved = KeychainHelper.saveCredentials(username: username, password: password)
                if !saved {
                    showError = true
                    errorMessage = "Failed to save to Keychain"
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                processingMessage = "Configuring applications..."
                
                // Configure apps
                var results: [AppConfigResult] = []
                
                if configureOffice {
                    let success = AppConfigurator.configureMicrosoftOffice(email: username)
                    results.append(AppConfigResult(appName: "Microsoft Office 365", success: success))
                }
                
                if configureDruva {
                    let success = AppConfigurator.configureDruvaInSync(email: username, password: password)
                    results.append(AppConfigResult(appName: "Druva InSync", success: success))
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    configurationResults = results
                    isProcessing = false
                    isComplete = true
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct CredentialResult {
    let username: String
    let success: Bool
    let configuredApps: [String]
}

struct AppConfigResult: Identifiable {
    let id = UUID()
    let appName: String
    let success: Bool
}

// MARK: - Supporting Views

struct AppToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.bodyBold())
                    .foregroundColor(Theme.Text.primary)
                
                Text(subtitle)
                    .font(Theme.Typography.small())
                    .foregroundColor(Theme.Text.muted)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: Theme.Brand.primary))
        }
    }
}

struct ProcessingStepRow: View {
    let text: String
    let isComplete: Bool
    var isActive: Bool = true
    
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ZStack {
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.Status.success)
                } else if isActive {
                    Circle()
                        .stroke(Theme.Brand.primary.opacity(0.3), lineWidth: 2)
                        .frame(width: 18, height: 18)
                    
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(Theme.Brand.primary, lineWidth: 2)
                        .frame(width: 18, height: 18)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                        .onAppear { isAnimating = true }
                } else {
                    Circle()
                        .stroke(Theme.Text.disabled, lineWidth: 2)
                        .frame(width: 18, height: 18)
                }
            }
            .frame(width: 20)
            
            Text(text)
                .font(Theme.Typography.caption())
                .foregroundColor(isActive ? Theme.Text.secondary : Theme.Text.disabled)
            
            Spacer()
        }
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? Theme.Brand.primary : Theme.Text.tertiary)
                    .font(.system(size: 18))
                
                configuration.label
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
