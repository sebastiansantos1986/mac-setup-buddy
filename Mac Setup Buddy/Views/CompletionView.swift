//
//  CompletionView.swift
//  Mac Setup Buddy
//
//  Created by Sebastian Santos on October 4, 2025
//
//  Updated to use centralized Theme system
//

import SwiftUI

struct CompletionView: View {
    let config: CommandLineConfig
    var onExit: (() -> Void)? = nil
    
    @State private var checkmarkScale: CGFloat = 0
    @State private var glowAnimation = false
    @State private var isHovered = false
    @State private var cardsAppeared = false
    
    var body: some View {
        ZStack {
            // Background - using Theme
            Theme.Gradients.background
                .ignoresSafeArea()
            
            // ScrollView for 13" screen compatibility
            ScrollView {
                VStack(spacing: 0) {
                    // Banner at top
                    BannerView(
                        imagePath: config.bannerImage,
                        height: 130,
                        contentMode: .fill
                    )
                    
                    // Main content
                    VStack(spacing: Theme.Spacing.md) {
                        // Success checkmark with glow
                        ZStack {
                            // Glow layers
                            ForEach(0..<2, id: \.self) { index in
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Theme.Status.success.opacity(0.4 - Double(index) * 0.15),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 15,
                                            endRadius: 60 + Double(index) * 20
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                    .scaleEffect(glowAnimation ? 1.2 : 0.8)
                                    .animation(
                                        .easeInOut(duration: 2).repeatForever(autoreverses: true),
                                        value: glowAnimation
                                    )
                            }
                            
                            // Main checkmark circle
                            Circle()
                                .fill(Theme.Gradients.success)
                                .frame(width: 72, height: 72)
                                .shadow(
                                    color: Theme.Status.success.opacity(0.6),
                                    radius: 20,
                                    y: 5
                                )
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.3), .clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .scaleEffect(checkmarkScale)
                        }
                        .padding(.top, Theme.Spacing.md)
                        .onAppear {
                            withAnimation(Theme.Animation.spring) {
                                checkmarkScale = 1
                            }
                            glowAnimation = true
                        }
                        
                        // Title and subtitle
                        VStack(spacing: Theme.Spacing.xs) {
                            Text("Setup Complete!")
                                .font(Theme.Typography.largeTitle())
                                .foregroundColor(Theme.Text.primary)
                            
                            Text(config.message ?? "Your device has been successfully configured")
                                .font(Theme.Typography.body())
                                .foregroundColor(Theme.Text.tertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Theme.Spacing.xxxl)
                        }
                        
                        // User Profile and Device Info cards
                        HStack(spacing: Theme.Spacing.md) {
                            // User Profile Card
                            UserProfileCard(
                                name: config.userName ?? "User",
                                email: config.email ?? "user@company.com",
                                department: config.userDepartment ?? "Department",
                                title: config.userTitle ?? "Title",
                                assetTag: config.assetTag ?? "Asset",
                                isVerified: true
                            )
                            .frame(maxHeight: .infinity)
                            .opacity(cardsAppeared ? 1 : 0)
                            .offset(x: cardsAppeared ? 0 : -50)
                            
                            // Device Info Card with encryption status
                            DeviceInfoCard(
                                deviceName: config.deviceName ?? "Device",
                                deviceModel: config.deviceModel ?? "Model",
                                serialNumber: config.serialNumber ?? "Serial",
                                osVersion: config.osVersion ?? "OS Version",
                                isManaged: true,
                                isEncrypted: config.isEncrypted ?? false
                            )
                            .frame(maxHeight: .infinity)
                            .opacity(cardsAppeared ? 1 : 0)
                            .offset(x: cardsAppeared ? 0 : 50)
                        }
                        .frame(height: 224)
                        .padding(.horizontal, Theme.Spacing.xxxl)
                        .onAppear {
                            withAnimation(.easeOut(duration: Theme.Animation.verySlow).delay(0.5)) {
                                cardsAppeared = true
                            }
                        }
                        
                        // Exit Setup button
                        Button(action: {
                            onExit?()
                            NSApplication.shared.terminate(nil)
                        }) {
                            HStack(spacing: Theme.Spacing.xs) {
                                Text("Exit Setup")
                                    .font(Theme.Typography.headline())
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 18))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 45)
                            .padding(.vertical, 12)
                            .background(Theme.Gradients.primaryButton)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.pill))
                            .shadow(
                                color: Theme.Brand.primary.opacity(isHovered ? 0.5 : 0.3),
                                radius: 20,
                                y: 5
                            )
                            .scaleEffect(isHovered ? 1.05 : 1.0)
                            .animation(Theme.Animation.smooth, value: isHovered)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            isHovered = hovering
                        }
                        .keyboardShortcut(.defaultAction)
                        .padding(.top, Theme.Spacing.xs)
                        .padding(.bottom, Theme.Spacing.lg)
                    }
                }
            }
        }
        .frame(width: config.windowWidth, height: config.windowHeight)
    }
}

// MARK: - User Profile Card Component (Updated with Theme)
struct UserProfileCard: View {
    let name: String
    let email: String
    let department: String
    let title: String
    let assetTag: String
    let isVerified: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header with icon and title
            HStack {
                // User icon with gradient
                ZStack {
                    Circle()
                        .fill(Theme.Gradients.accent)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.Text.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("User Profile")
                        .font(Theme.Typography.headline())
                        .foregroundColor(Theme.Text.primary)
                    
                    HStack(spacing: Theme.Spacing.xxs) {
                        Circle()
                            .fill(isVerified ? Theme.Status.success : Theme.Status.warning)
                            .frame(width: 6, height: 6)
                        
                        Text(isVerified ? "Account verified" : "Pending verification")
                            .font(Theme.Typography.small())
                            .foregroundColor(isVerified ? Theme.Status.success : Theme.Status.warning)
                    }
                }
                
                Spacer()
            }
            
            Divider()
                .background(Theme.Border.subtle)
            
            // User details
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                DetailRow(icon: "person", label: "Name", value: name)
                DetailRow(icon: "envelope", label: "Email", value: email)
                DetailRow(icon: "building.2", label: "Dept", value: department)
                DetailRow(icon: "briefcase", label: "Title", value: title)
                DetailRow(icon: "tag", label: "Asset", value: assetTag, isHighlighted: true)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassCard(cornerRadius: Theme.CornerRadius.large)
    }
}

// MARK: - Device Info Card Component (Updated with Theme)
struct DeviceInfoCard: View {
    let deviceName: String
    let deviceModel: String
    let serialNumber: String
    let osVersion: String
    let isManaged: Bool
    let isEncrypted: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header with icon and title
            HStack {
                // Device icon with gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.7, blue: 0.5),
                                    Color(red: 0.3, green: 0.8, blue: 0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.Text.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Device Info")
                        .font(Theme.Typography.headline())
                        .foregroundColor(Theme.Text.primary)
                    
                    HStack(spacing: Theme.Spacing.xxs) {
                        Circle()
                            .fill(isManaged ? Theme.Status.success : Theme.Status.warning)
                            .frame(width: 6, height: 6)
                        
                        Text(isManaged ? "Fully managed" : "Not managed")
                            .font(Theme.Typography.small())
                            .foregroundColor(isManaged ? Theme.Status.success : Theme.Status.warning)
                    }
                }
                
                Spacer()
            }
            
            Divider()
                .background(Theme.Border.subtle)
            
            // Device details
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                DetailRow(icon: "tv", label: "Name", value: deviceName)
                DetailRow(icon: "internaldrive", label: "Model", value: deviceModel)
                DetailRow(icon: "number", label: "Serial", value: serialNumber)
                DetailRow(icon: "apple.logo", label: "macOS", value: osVersion)
                
                // Encryption status row with special formatting
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: isEncrypted ? "lock.shield.fill" : "lock.shield")
                        .font(.system(size: 14))
                        .foregroundColor(isEncrypted ? Theme.Status.success : Theme.Status.warning)
                        .frame(width: 20)
                    
                    Text("Encryption")
                        .font(Theme.Typography.caption())
                        .foregroundColor(Theme.Text.tertiary)
                        .frame(width: 50, alignment: .leading)
                    
                    HStack(spacing: Theme.Spacing.xxs) {
                        Circle()
                            .fill(isEncrypted ? Theme.Status.success : Theme.Status.warning)
                            .frame(width: 6, height: 6)
                        
                        Text(isEncrypted ? "FileVault Enabled" : "Not Encrypted")
                            .font(Theme.Typography.captionBold())
                            .foregroundColor(isEncrypted ? Theme.Status.success : Theme.Status.warning)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassCard(cornerRadius: Theme.CornerRadius.large)
    }
}

// MARK: - Detail Row Component (Updated with Theme)
struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(isHighlighted ? Theme.Status.warning : Theme.Text.tertiary)
                .frame(width: 20)
            
            Text(label)
                .font(Theme.Typography.caption())
                .foregroundColor(Theme.Text.tertiary)
                .frame(width: 50, alignment: .leading)
            
            Text(value)
                .font(Theme.Typography.captionBold())
                .foregroundColor(isHighlighted ? Theme.Status.warning : Theme.Text.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Preview
