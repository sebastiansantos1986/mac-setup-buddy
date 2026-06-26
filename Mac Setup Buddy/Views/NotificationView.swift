//
//  NotificationView.swift
//  Mac Setup Buddy
//
//  Created by Sebastian Santos on 10/3/25.
//
//  Updated to use centralized Theme system
//

import SwiftUI

struct NotificationView: View {
    let title: String
    let message: String
    let icon: String
    let buttons: [String]
    var onAction: (Int) -> Void
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    @State private var iconRotation: Double = 0
    @State private var glowAnimation = false
    @State private var hoveredButtonIndex: Int? = nil
    
    // Determine notification type based on icon
    private var notificationType: NotificationType {
        if icon.contains("checkmark") || icon.contains("success") {
            return .success
        } else if icon.contains("exclamation") || icon.contains("warning") {
            return .warning
        } else if icon.contains("xmark") || icon.contains("error") {
            return .error
        } else {
            return .info
        }
    }
    
    var body: some View {
        ZStack {
            // Background - using Theme
            Theme.Background.primary
                .ignoresSafeArea()
            
            Theme.Gradients.background
                .ignoresSafeArea()
            
            // Main notification card
            VStack(spacing: 0) {
                // Top accent bar with gradient
                notificationType.gradient
                    .frame(height: 4)
                
                // Content area
                VStack(spacing: Theme.Spacing.xl) {
                    // Icon with animated glow
                    ZStack {
                        // Glow layers
                        ForEach(0..<2, id: \.self) { index in
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            notificationType.themeColor.opacity(0.3 - Double(index) * 0.1),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 10,
                                        endRadius: 50 + Double(index) * 20
                                    )
                                )
                                .frame(width: 120 + CGFloat(index) * 40,
                                       height: 120 + CGFloat(index) * 40)
                                .scaleEffect(glowAnimation ? 1.1 : 0.9)
                                .animation(
                                    .easeInOut(duration: 2 + Double(index) * 0.5)
                                    .repeatForever(autoreverses: true),
                                    value: glowAnimation
                                )
                        }
                        
                        // Icon circle
                        Circle()
                            .fill(notificationType.gradient)
                            .frame(width: 80, height: 80)
                            .shadow(color: notificationType.themeColor.opacity(0.5), radius: 15, y: 5)
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
                        
                        // Icon
                        Image(systemName: icon)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(Theme.Text.primary)
                            .rotationEffect(.degrees(iconRotation))
                    }
                    .padding(.top, Theme.Spacing.lg)
                    
                    // Title and message
                    VStack(spacing: Theme.Spacing.sm) {
                        Text(title)
                            .font(Theme.Typography.title())
                            .foregroundColor(Theme.Text.primary)
                            .multilineTextAlignment(.center)
                        
                        Text(parseNewlines(message))
                            .font(Theme.Typography.body())
                            .foregroundColor(Theme.Text.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, Theme.Spacing.xl)
                    }
                    
                    // Additional info card (optional)
                    if notificationType == .success {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(notificationType.themeColor)
                            Text("Completed at \(currentTime())")
                                .font(Theme.Typography.caption())
                                .foregroundColor(Theme.Text.tertiary)
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                .fill(Theme.Background.card)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                        .stroke(notificationType.themeColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    
                    // Buttons
                    HStack(spacing: Theme.Spacing.md) {
                        ForEach(buttons.indices, id: \.self) { index in
                            Button(action: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    scale = 0.9
                                    opacity = 0
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    onAction(index)
                                }
                            }) {
                                Text(buttons[index])
                                    .font(Theme.Typography.headline())
                                    .foregroundColor(Theme.Text.primary)
                                    .frame(minWidth: 120)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, Theme.Spacing.xl)
                                    .background(
                                        Group {
                                            if index == 0 {
                                                // Primary button with gradient
                                                notificationType.gradient
                                                    .opacity(hoveredButtonIndex == index ? 1 : 0.9)
                                                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                                                    .shadow(
                                                        color: notificationType.themeColor.opacity(hoveredButtonIndex == index ? 0.5 : 0.3),
                                                        radius: 10,
                                                        y: 5
                                                    )
                                            } else {
                                                // Secondary button with border
                                                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                                    .fill(Theme.Background.card.opacity(hoveredButtonIndex == index ? 0.15 : 0.08))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                                            .stroke(Theme.Border.highlighted, lineWidth: 1)
                                                    )
                                            }
                                        }
                                    )
                                    .scaleEffect(hoveredButtonIndex == index ? 1.03 : 1.0)
                                    .animation(Theme.Animation.smooth, value: hoveredButtonIndex)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onHover { hovering in
                                withAnimation(Theme.Animation.smooth) {
                                    hoveredButtonIndex = hovering ? index : nil
                                }
                            }
                            .keyboardShortcut(index == 0 ? .defaultAction : .cancelAction)
                        }
                    }
                    .padding(.bottom, Theme.Spacing.xl)
                }
                .padding(.top, Theme.Spacing.sm)
            }
            .frame(maxWidth: 520)
            .glassCard(cornerRadius: Theme.CornerRadius.xlarge)
            .shadow(color: notificationType.themeColor.opacity(0.2), radius: 30, y: 10)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(Theme.Animation.spring) {
                scale = 1
                opacity = 1
            }
            
            withAnimation(.easeInOut(duration: Theme.Animation.verySlow)) {
                iconRotation = notificationType == .success ? 360 : 0
            }
            
            glowAnimation = true
        }
    }
    
    private func parseNewlines(_ text: String) -> String {
        return text.replacingOccurrences(of: "\\n", with: "\n")
    }
    
    private func currentTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

// MARK: - Notification Type (Updated with Theme)
enum NotificationType {
    case success
    case warning
    case error
    case info
    
    /// Theme-based color
    var themeColor: Color {
        switch self {
        case .success: return Theme.Status.success
        case .warning: return Theme.Status.warning
        case .error: return Theme.Status.error
        case .info: return Theme.Status.info
        }
    }
    
    /// Gradient for this notification type
    var gradient: LinearGradient {
        switch self {
        case .success:
            return LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.8, blue: 0.3),
                    Color(red: 0.1, green: 0.6, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .warning:
            return LinearGradient(
                colors: [Theme.Status.warning, Theme.Status.warning.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .error:
            return LinearGradient(
                colors: [
                    Color(red: 0.9, green: 0.3, blue: 0.3),
                    Color(red: 0.7, green: 0.2, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .info:
            return LinearGradient(
                colors: [Theme.Brand.primary, Theme.Brand.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    /// Legacy color property (for compatibility)
    var color: Color {
        return themeColor
    }
    
    /// Legacy gradientColors property (for compatibility)
    var gradientColors: [Color] {
        switch self {
        case .success:
            return [Color(red: 0.2, green: 0.8, blue: 0.3), Color(red: 0.1, green: 0.6, blue: 0.2)]
        case .warning:
            return [Theme.Status.warning, Theme.Status.warning.opacity(0.8)]
        case .error:
            return [Color(red: 0.9, green: 0.3, blue: 0.3), Color(red: 0.7, green: 0.2, blue: 0.2)]
        case .info:
            return [Theme.Brand.primary, Theme.Brand.secondary]
        }
    }
}

// MARK: - Preview
