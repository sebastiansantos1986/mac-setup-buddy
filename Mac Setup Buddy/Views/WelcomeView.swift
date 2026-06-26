//
//  WelcomeView.swift
//  Mac Setup Buddy
//
//  Created by Sebastian Santos on October 4, 2025
//
//  Updated to use centralized Theme system
//

import SwiftUI

struct WelcomeView: View {
    let config: CommandLineConfig
    var onContinue: (() -> Void)? = nil
    
    @State private var isHovered = false
    @State private var stepsAppeared = false
    @State private var buttonAppeared = false
    @State private var iconAppeared = false
    @State private var glowAnimation = false
    
    var body: some View {
        ZStack {
            // Dark gradient background - using Theme
            Theme.Gradients.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Banner at top
                BannerView(
                    imagePath: config.bannerImage,
                    height: 120,
                    contentMode: .fill
                )
                
                Spacer()
                
                VStack(spacing: Theme.Spacing.xl) {
                    // Icon with glow effect
                    ZStack {
                        // Glow layers
                        if glowAnimation {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Theme.Brand.primary.opacity(0.3),
                                            Theme.Brand.primary.opacity(0.1),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 10,
                                        endRadius: 60
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .scaleEffect(glowAnimation ? 1.2 : 0.8)
                                .animation(
                                    .easeInOut(duration: 2).repeatForever(autoreverses: true),
                                    value: glowAnimation
                                )
                        }
                        
                        Circle()
                            .fill(Theme.Gradients.iconCircle)
                            .frame(width: 80, height: 80)
                            .shadow(
                                color: Theme.Shadows.glow(Theme.Brand.primary).color,
                                radius: Theme.Shadows.glow().radius,
                                y: Theme.Shadows.glow().y
                            )
                        
                        Image(systemName: config.welcomeIcon ?? "arrow.down.doc.fill")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(Theme.Text.primary)
                    }
                    .scaleEffect(iconAppeared ? 1 : 0.5)
                    .opacity(iconAppeared ? 1 : 0)
                    .onAppear {
                        withAnimation(Theme.Animation.spring) {
                            iconAppeared = true
                        }
                        glowAnimation = true
                    }
                    
                    // Title and subtitle
                    VStack(spacing: Theme.Spacing.xs) {
                        Text(config.title ?? "Welcome to Mac Setup Buddy")
                            .font(Theme.Typography.largeTitle())
                            .foregroundColor(Theme.Text.primary)
                        
                        Text(config.subtitle ?? "Enterprise Device Setup")
                            .font(Theme.Typography.bodyBold())
                            .foregroundColor(Theme.Text.tertiary)
                    }
                    
                    // Message and steps card
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // Message
                        Text(config.message ?? "Let's configure your Mac for enterprise use.")
                            .font(Theme.Typography.bodyBold())
                            .foregroundColor(Theme.Text.primary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, Theme.Spacing.xxs)
                        
                        // Steps
                        VStack(alignment: .leading, spacing: 14) {
                            if let step1 = config.welcomeStep1 {
                                SimpleStepRow(icon: "checkmark.circle.fill", text: step1, color: Theme.Status.success)
                            }
                            if let step2 = config.welcomeStep2 {
                                SimpleStepRow(icon: "tag.fill", text: step2, color: Theme.Status.warning)
                            }
                            if let step3 = config.welcomeStep3 {
                                SimpleStepRow(icon: "info.circle.fill", text: step3, color: Theme.Status.info)
                            }
                            if let step4 = config.welcomeStep4 {
                                SimpleStepRow(icon: "shield.fill", text: step4, color: Theme.Brand.tertiary)
                            }
                        }
                    }
                    .padding(Theme.Spacing.xl)
                    .glassCard(cornerRadius: Theme.CornerRadius.large)
                    .frame(maxWidth: 650)
                    .opacity(stepsAppeared ? 1 : 0)
                    .offset(y: stepsAppeared ? 0 : 20)
                    .onAppear {
                        withAnimation(.easeOut(duration: Theme.Animation.slow).delay(0.2)) {
                            stepsAppeared = true
                        }
                    }
                    
                    // Time estimate
                    if let timeEstimate = config.welcomeTimeEstimate {
                        Text(timeEstimate)
                            .font(Theme.Typography.caption())
                            .foregroundColor(Theme.Text.tertiary)
                    }
                    
                    // Button
                    Button(action: {
                        onContinue?()
                    }) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Text(config.buttonText ?? "Begin Setup")
                                .font(Theme.Typography.headline())
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, Theme.Spacing.xxl)
                        .padding(.vertical, 14)
                        .background(Theme.Gradients.primaryButton)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.pill))
                        .shadow(
                            color: Theme.Brand.primary.opacity(isHovered ? 0.5 : 0.3),
                            radius: 20
                        )
                        .scaleEffect(isHovered ? 1.05 : 1.0)
                        .animation(Theme.Animation.smooth, value: isHovered)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        isHovered = hovering
                    }
                    .keyboardShortcut(.defaultAction)
                    .opacity(buttonAppeared ? 1 : 0)
                    .offset(y: buttonAppeared ? 0 : 20)
                    .onAppear {
                        withAnimation(.easeOut(duration: Theme.Animation.slow).delay(0.4)) {
                            buttonAppeared = true
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.xxxl)
                
                Spacer()
            }
        }
        .frame(width: config.windowWidth, height: config.windowHeight)
    }
}

// MARK: - Simple Step Row (Updated with Theme)
struct SimpleStepRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(text)
                .font(Theme.Typography.bodyBold())
                .foregroundColor(Theme.Text.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Preview
