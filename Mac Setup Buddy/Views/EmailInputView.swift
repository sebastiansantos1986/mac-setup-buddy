//
//  EmailInputView.swift
//  Mac Setup Buddy
//
//  Created by Sebastian Santos on October 4, 2025
//
//  Updated to use centralized Theme system
//

import SwiftUI

struct EmailInputView: View {
    var config: CommandLineConfig
    var completion: (String) -> Void

    @State private var email: String = ""
    @State private var isHoveredCancel = false
    @State private var isHoveredContinue = false
    @State private var iconAppeared = false
    @State private var formAppeared = false
    @State private var glowAnimation = false
    @State private var isFocused = false

    var body: some View {
        ZStack {
            // Background gradient - using Theme
            Theme.Gradients.background
                .ignoresSafeArea()
            
            VStack(spacing: Theme.Spacing.xl) {
                // Banner area - using BannerView component
                BannerView(
                    imagePath: config.bannerImage,
                    height: 250,
                    contentMode: .fill
                )
                
                // Email icon with gradient background
                ZStack {
                    // Glow effect
                    if glowAnimation {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Theme.Brand.tertiary.opacity(0.4),
                                        Theme.Brand.tertiary.opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: 70
                                )
                            )
                            .frame(width: 140, height: 140)
                            .scaleEffect(glowAnimation ? 1.1 : 0.9)
                            .animation(
                                .easeInOut(duration: 2).repeatForever(autoreverses: true),
                                value: glowAnimation
                            )
                    }
                    
                    // Circular gradient background for icon
                    Circle()
                        .fill(Theme.Gradients.accent)
                        .frame(width: 100, height: 100)
                        .shadow(
                            color: Theme.Brand.tertiary.opacity(0.5),
                            radius: 20,
                            y: 10
                        )
                    
                    Image(systemName: "envelope.fill")
                        .resizable()
                        .frame(width: 45, height: 35)
                        .foregroundColor(.white)
                }
                .padding(.top, -30)
                .scaleEffect(iconAppeared ? 1 : 0.5)
                .opacity(iconAppeared ? 1 : 0)
                .onAppear {
                    withAnimation(Theme.Animation.spring) {
                        iconAppeared = true
                    }
                    glowAnimation = true
                }
                
                // Title and message
                VStack(spacing: Theme.Spacing.xs) {
                    Text(config.title ?? "Device Setup")
                        .font(Theme.Typography.title2())
                        .foregroundColor(Theme.Text.primary)
                    
                    Text(config.message ?? "Enter your email to continue")
                        .font(Theme.Typography.body())
                        .foregroundColor(Theme.Text.secondary)
                }
                .opacity(formAppeared ? 1 : 0)
                .offset(y: formAppeared ? 0 : 10)
                .onAppear {
                    withAnimation(.easeOut(duration: Theme.Animation.slow).delay(0.2)) {
                        formAppeared = true
                    }
                }
                
                // Email input field with Theme styling
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "envelope")
                        .foregroundColor(isFocused ? Theme.Brand.primary : Theme.Text.tertiary)
                        .font(.system(size: 16))
                        .animation(Theme.Animation.smooth, value: isFocused)
                    
                    TextField("", text: $email, onEditingChanged: { editing in
                        isFocused = editing
                    })
                    .placeholder(when: email.isEmpty) {
                        Text(config.emailPlaceholder ?? "email@example.com")
                            .foregroundColor(Theme.Text.disabled)
                    }
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(Theme.Text.primary)
                    .font(Theme.Typography.body())
                }
                .padding(Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .fill(Theme.Background.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                .stroke(
                                    isFocused ? Theme.Border.focus : Theme.Border.primary,
                                    lineWidth: isFocused ? 2 : 1
                                )
                                .animation(Theme.Animation.smooth, value: isFocused)
                        )
                )
                .frame(maxWidth: 400)
                .opacity(formAppeared ? 1 : 0)
                .offset(y: formAppeared ? 0 : 10)
                
                Spacer()
                
                // Buttons
                HStack(spacing: Theme.Spacing.lg) {
                    // Cancel button
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Text("Cancel")
                            .font(Theme.Typography.headline())
                            .foregroundColor(Theme.Text.secondary)
                            .padding(.horizontal, Theme.Spacing.xxl)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.pill)
                                    .fill(Theme.Background.card.opacity(isHoveredCancel ? 0.15 : 0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.CornerRadius.pill)
                                            .stroke(Theme.Border.highlighted, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        withAnimation(Theme.Animation.smooth) {
                            isHoveredCancel = hovering
                        }
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    // Continue button with gradient
                    Button(action: {
                        completion(email)
                    }) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text("Continue")
                                .font(Theme.Typography.headline())
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(Theme.Text.primary)
                        .padding(.horizontal, Theme.Spacing.xxl)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            Theme.Gradients.accent
                                .opacity(isHoveredContinue ? 1 : 0.9)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.pill))
                        )
                        .shadow(
                            color: Theme.Brand.tertiary.opacity(isHoveredContinue ? 0.5 : 0.3),
                            radius: 15,
                            y: 5
                        )
                        .scaleEffect(isHoveredContinue ? 1.03 : 1.0)
                        .animation(Theme.Animation.smooth, value: isHoveredContinue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        isHoveredContinue = hovering
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(email.isEmpty)
                    .opacity(email.isEmpty ? 0.6 : 1.0)
                }
                .opacity(formAppeared ? 1 : 0)
                
                // Progress indicator
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "timer")
                        .foregroundColor(Theme.Text.disabled)
                        .font(.system(size: 12))
                    Text("4:51")
                        .font(Theme.Typography.captionBold())
                        .foregroundColor(Theme.Text.disabled)
                }
                .padding(.bottom, Theme.Spacing.lg)
            }
        }
        .frame(minWidth: config.windowWidth, minHeight: config.windowHeight)
    }
}

// Custom placeholder modifier for TextField
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
