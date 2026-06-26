//
//  SetupAssistantView.swift
//  Mac Setup Buddy
//
//  Created by Sebastian Santos on 10/3/25.
//
//  Updated to use centralized Theme system
//

import SwiftUI

struct SetupAssistantView: View {
    @State private var fullName = ""
    @State private var accountName = ""
    @State private var password = ""
    @State private var verifyPassword = ""
    @State private var isHoveredBack = false
    @State private var isHoveredContinue = false
    @State private var showPasswordMismatch = false
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case fullName, accountName, password, verifyPassword
    }
    
    var isFormValid: Bool {
        !fullName.isEmpty && !accountName.isEmpty && !password.isEmpty && password == verifyPassword
    }
    
    var body: some View {
        ZStack {
            // Background
            Theme.Gradients.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with icon
                VStack(spacing: Theme.Spacing.md) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Theme.Gradients.accent)
                            .frame(width: 70, height: 70)
                            .shadow(color: Theme.Brand.tertiary.opacity(0.4), radius: 15, y: 5)
                        
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(Theme.Text.primary)
                    }
                    
                    VStack(spacing: Theme.Spacing.xs) {
                        Text("Create a Computer Account")
                            .font(Theme.Typography.title())
                            .foregroundColor(Theme.Text.primary)
                        
                        Text("Fill out the following information to create your local account.")
                            .font(Theme.Typography.body())
                            .foregroundColor(Theme.Text.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.lg)
                
                // Form card
                VStack(spacing: Theme.Spacing.md) {
                    // Full Name
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("Full Name")
                            .font(Theme.Typography.captionBold())
                            .foregroundColor(Theme.Text.secondary)
                        
                        HStack {
                            Image(systemName: "person")
                                .foregroundColor(focusedField == .fullName ? Theme.Brand.primary : Theme.Text.tertiary)
                                .frame(width: 20)
                            
                            TextField("John Smith", text: $fullName)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(Theme.Typography.body())
                                .foregroundColor(Theme.Text.primary)
                                .focused($focusedField, equals: .fullName)
                        }
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Background.card)
                        .cornerRadius(Theme.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                .stroke(
                                    focusedField == .fullName ? Theme.Brand.primary : Theme.Border.primary,
                                    lineWidth: focusedField == .fullName ? 2 : 1
                                )
                        )
                    }
                    
                    // Account Name
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("Account Name")
                            .font(Theme.Typography.captionBold())
                            .foregroundColor(Theme.Text.secondary)
                        
                        HStack {
                            Image(systemName: "at")
                                .foregroundColor(focusedField == .accountName ? Theme.Brand.primary : Theme.Text.tertiary)
                                .frame(width: 20)
                            
                            TextField("jsmith", text: $accountName)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(Theme.Typography.body())
                                .foregroundColor(Theme.Text.primary)
                                .focused($focusedField, equals: .accountName)
                        }
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Background.card)
                        .cornerRadius(Theme.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                .stroke(
                                    focusedField == .accountName ? Theme.Brand.primary : Theme.Border.primary,
                                    lineWidth: focusedField == .accountName ? 2 : 1
                                )
                        )
                        
                        Text("This will be used for your login")
                            .font(Theme.Typography.small())
                            .foregroundColor(Theme.Text.muted)
                    }
                    
                    // Password
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("Password")
                            .font(Theme.Typography.captionBold())
                            .foregroundColor(Theme.Text.secondary)
                        
                        HStack {
                            Image(systemName: "lock")
                                .foregroundColor(focusedField == .password ? Theme.Brand.primary : Theme.Text.tertiary)
                                .frame(width: 20)
                            
                            SecureField("••••••••", text: $password)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(Theme.Typography.body())
                                .foregroundColor(Theme.Text.primary)
                                .focused($focusedField, equals: .password)
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
                    
                    // Verify Password
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("Verify Password")
                            .font(Theme.Typography.captionBold())
                            .foregroundColor(Theme.Text.secondary)
                        
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(
                                    showPasswordMismatch ? Theme.Status.error :
                                    (focusedField == .verifyPassword ? Theme.Brand.primary : Theme.Text.tertiary)
                                )
                                .frame(width: 20)
                            
                            SecureField("••••••••", text: $verifyPassword)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(Theme.Typography.body())
                                .foregroundColor(Theme.Text.primary)
                                .focused($focusedField, equals: .verifyPassword)
                                .onChange(of: verifyPassword) { _, _ in
                                    showPasswordMismatch = !verifyPassword.isEmpty && password != verifyPassword
                                }
                        }
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Background.card)
                        .cornerRadius(Theme.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                .stroke(
                                    showPasswordMismatch ? Theme.Status.error :
                                    (focusedField == .verifyPassword ? Theme.Brand.primary : Theme.Border.primary),
                                    lineWidth: focusedField == .verifyPassword || showPasswordMismatch ? 2 : 1
                                )
                        )
                        
                        if showPasswordMismatch {
                            HStack(spacing: Theme.Spacing.xxs) {
                                Image(systemName: "exclamationmark.circle")
                                Text("Passwords do not match")
                            }
                            .font(Theme.Typography.small())
                            .foregroundColor(Theme.Status.error)
                        }
                    }
                }
                .padding(Theme.Spacing.xl)
                .glassCard()
                .padding(.horizontal, Theme.Spacing.xl)
                
                Spacer()
                
                // Bottom buttons
                HStack(spacing: Theme.Spacing.md) {
                    // Back button
                    Button(action: {
                        // Handle back action
                    }) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(Theme.Typography.bodyBold())
                        .foregroundColor(Theme.Text.secondary)
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.pill)
                                .fill(isHoveredBack ? Theme.Background.card : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.pill)
                                        .stroke(Theme.Border.primary, lineWidth: 1)
                                )
                        )
                        .scaleEffect(isHoveredBack ? 1.02 : 1.0)
                        .animation(Theme.Animation.smooth, value: isHoveredBack)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        isHoveredBack = hovering
                    }
                    
                    Spacer()
                    
                    // Continue button
                    Button(action: {
                        if isFormValid {
                            NSApplication.shared.terminate(nil)
                        }
                    }) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text("Continue")
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        .font(Theme.Typography.headline())
                        .foregroundColor(isFormValid ? Theme.Text.primary : Theme.Text.disabled)
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            Group {
                                if isFormValid {
                                    Theme.Gradients.primaryButton
                                } else {
                                    LinearGradient(
                                        colors: [Theme.Text.disabled, Theme.Text.disabled],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                }
                            }
                        )
                        .cornerRadius(Theme.CornerRadius.pill)
                        .shadow(
                            color: isFormValid ? Theme.Brand.primary.opacity(isHoveredContinue ? 0.5 : 0.3) : Color.clear,
                            radius: 15,
                            y: 5
                        )
                        .scaleEffect(isHoveredContinue && isFormValid ? 1.03 : 1.0)
                        .animation(Theme.Animation.smooth, value: isHoveredContinue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!isFormValid)
                    .onHover { hovering in
                        isHoveredContinue = hovering
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .frame(width: 600, height: 650)
    }
}

// MARK: - Preview
