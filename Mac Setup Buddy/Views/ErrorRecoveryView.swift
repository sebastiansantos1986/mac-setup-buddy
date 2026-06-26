//
//  ErrorRecoveryView.swift
//  Mac Setup Buddy
//
//  Dedicated error recovery screen with clear actions and diagnostics
//

import SwiftUI
import AppKit

// MARK: - Error Type
enum InstallationError: Identifiable {
    case policyFailed(name: String, reason: String)
    case policyTimeout(name: String, elapsedTime: Int)
    case networkLost(during: String)
    case diskSpace(required: Int, available: Int)
    case permissionDenied(resource: String)
    case unknown(message: String)
    
    var id: String {
        switch self {
        case .policyFailed(let name, _): return "failed-\(name)"
        case .policyTimeout(let name, _): return "timeout-\(name)"
        case .networkLost(let during): return "network-\(during)"
        case .diskSpace: return "disk"
        case .permissionDenied(let resource): return "permission-\(resource)"
        case .unknown(let message): return "unknown-\(message)"
        }
    }
    
    var icon: String {
        switch self {
        case .policyFailed: return "xmark.circle.fill"
        case .policyTimeout: return "clock.badge.exclamationmark.fill"
        case .networkLost: return "wifi.exclamationmark"
        case .diskSpace: return "externaldrive.badge.xmark"
        case .permissionDenied: return "lock.shield.fill"
        case .unknown: return "exclamationmark.triangle.fill"
        }
    }
    
    var title: String {
        switch self {
        case .policyFailed(let name, _): return "\(name) Failed"
        case .policyTimeout(let name, _): return "\(name) Timed Out"
        case .networkLost: return "Network Connection Lost"
        case .diskSpace: return "Insufficient Disk Space"
        case .permissionDenied: return "Permission Denied"
        case .unknown: return "Installation Error"
        }
    }
    
    var description: String {
        switch self {
        case .policyFailed(_, let reason):
            return reason
        case .policyTimeout(_, let elapsed):
            let mins = elapsed / 60
            return "Installation did not complete after \(mins) minutes. The process may be stuck."
        case .networkLost(let during):
            return "Network connection was lost while installing \(during). Installation cannot continue without network access."
        case .diskSpace(let required, let available):
            return "This installation requires \(required)GB of free space. Only \(available)GB is available."
        case .permissionDenied(let resource):
            return "Unable to access \(resource). Administrator privileges may be required."
        case .unknown(let message):
            return message
        }
    }
    
    var color: Color {
        switch self {
        case .policyTimeout: return Theme.Status.warning
        case .networkLost: return Theme.Status.warning
        default: return Theme.Status.error
        }
    }
    
    var canRetry: Bool {
        switch self {
        case .diskSpace: return false
        case .permissionDenied: return false
        default: return true
        }
    }
    
    var canSkip: Bool {
        switch self {
        case .policyFailed, .policyTimeout: return true
        default: return false
        }
    }
}

// MARK: - Recovery Action
enum RecoveryAction {
    case retry
    case skip
    case contactIT
    case exportLogs
    case quit
}

// MARK: - Error Recovery View
struct ErrorRecoveryView: View {
    let error: InstallationError
    let policyName: String?
    let diagnosticInfo: String
    let bannerImage: String?
    let onAction: (RecoveryAction) -> Void
    
    @State private var isHoveredRetry = false
    @State private var isHoveredSkip = false
    @State private var isHoveredQuit = false
    @State private var showDiagnostics = false
    @State private var glowAnimation = false
    @State private var copied = false
    @State private var exportedPath: String? = nil
    
    init(
        error: InstallationError,
        policyName: String?,
        diagnosticInfo: String,
        bannerImage: String? = nil,
        onAction: @escaping (RecoveryAction) -> Void
    ) {
        self.error = error
        self.policyName = policyName
        self.diagnosticInfo = diagnosticInfo
        self.bannerImage = bannerImage
        self.onAction = onAction
    }
    
    var body: some View {
        ZStack {
            // Background
            Theme.Gradients.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                BannerView(
                    imagePath: bannerImage,
                    height: 120,
                    contentMode: .fill
                )
                
                // Error banner at top
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(error.color)
                    Text("Installation Issue Detected")
                        .font(Theme.Typography.captionBold())
                        .foregroundColor(error.color)
                    Spacer()
                    Text(formattedTime())
                        .font(Theme.Typography.mono(size: 11))
                        .foregroundColor(Theme.Text.muted)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .background(error.color.opacity(0.15))
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Error Icon with glow
                        ZStack {
                            // Glow effect
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [error.color.opacity(0.4), Color.clear],
                                        center: .center,
                                        startRadius: 10,
                                        endRadius: 70
                                    )
                                )
                                .frame(width: 112, height: 112)
                                .scaleEffect(glowAnimation ? 1.2 : 0.9)
                                .animation(
                                    .easeInOut(duration: 2).repeatForever(autoreverses: true),
                                    value: glowAnimation
                                )
                            
                            // Icon circle
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [error.color, error.color.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 74, height: 74)
                                .shadow(color: error.color.opacity(0.5), radius: 20, y: 5)
                            
                            Image(systemName: error.icon)
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundColor(Theme.Text.primary)
                        }
                        .padding(.top, Theme.Spacing.md)
                        .onAppear { glowAnimation = true }
                        
                        // Error title and description
                        VStack(spacing: Theme.Spacing.sm) {
                            Text(error.title)
                                .font(Theme.Typography.title())
                                .foregroundColor(Theme.Text.primary)
                                .multilineTextAlignment(.center)
                            
                            Text(error.description)
                                .font(Theme.Typography.body())
                                .foregroundColor(Theme.Text.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Theme.Spacing.xxl)
                        }
                        
                        // Quick actions card
                        VStack(spacing: Theme.Spacing.md) {
                            Text("What would you like to do?")
                                .font(Theme.Typography.headline())
                                .foregroundColor(Theme.Text.primary)
                            
                            // Action buttons
                            VStack(spacing: Theme.Spacing.sm) {
                                // Retry button (if applicable)
                                if error.canRetry {
                                    ActionButton(
                                        icon: "arrow.clockwise.circle.fill",
                                        title: "Retry Installation",
                                        subtitle: "Attempt to install \(policyName ?? "this item") again",
                                        color: Theme.Brand.primary,
                                        isHovered: $isHoveredRetry
                                    ) {
                                        onAction(.retry)
                                    }
                                }
                                
                                // Skip button (if applicable)
                                if error.canSkip {
                                    ActionButton(
                                        icon: "forward.fill",
                                        title: "Skip & Continue",
                                        subtitle: "Skip this item and continue with remaining installations",
                                        color: Theme.Status.warning,
                                        isHovered: $isHoveredSkip
                                    ) {
                                        onAction(.skip)
                                    }
                                }
                                
                                // Contact IT button
                                ActionButton(
                                    icon: "person.fill.questionmark",
                                    title: "Contact IT Support",
                                    subtitle: "Get help from your IT department",
                                    color: Theme.Status.info,
                                    isHovered: .constant(false)
                                ) {
                                    onAction(.contactIT)
                                }
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .glassCard()
                        .padding(.horizontal, Theme.Spacing.xl)
                        
                        // Diagnostics section
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Button(action: { withAnimation { showDiagnostics.toggle() }}) {
                                HStack {
                                    Image(systemName: "wrench.and.screwdriver")
                                        .foregroundColor(Theme.Text.tertiary)
                                    Text("Diagnostic Information")
                                        .font(Theme.Typography.captionBold())
                                        .foregroundColor(Theme.Text.secondary)
                                    Spacer()
                                    Image(systemName: showDiagnostics ? "chevron.up" : "chevron.down")
                                        .foregroundColor(Theme.Text.tertiary)
                                        .font(.system(size: 12))
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if showDiagnostics {
                                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                    // Diagnostic content
                                    ScrollView {
                                        Text(diagnosticInfo)
                                            .font(Theme.Typography.mono(size: 11))
                                            .foregroundColor(Theme.Text.muted)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .frame(maxHeight: 150)
                                    .padding(Theme.Spacing.sm)
                                    .background(Theme.Background.card)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                            .stroke(Theme.Border.subtle, lineWidth: 1)
                                    )
                                    .cornerRadius(Theme.CornerRadius.small)
                                    
                                    // Copy & Export buttons
                                    HStack(spacing: Theme.Spacing.sm) {
                                        Button(action: copyDiagnostics) {
                                            HStack(spacing: 4) {
                                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                                Text(copied ? "Copied!" : "Copy")
                                            }
                                            .font(Theme.Typography.small())
                                            .foregroundColor(copied ? Theme.Status.success : Theme.Text.secondary)
                                            .padding(.horizontal, Theme.Spacing.sm)
                                            .padding(.vertical, Theme.Spacing.xxs)
                                            .background(Theme.Background.card)
                                            .cornerRadius(Theme.CornerRadius.small)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        Button(action: { exportLogs() }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "square.and.arrow.up")
                                                Text("Export Logs")
                                            }
                                            .font(Theme.Typography.small())
                                            .foregroundColor(Theme.Text.secondary)
                                            .padding(.horizontal, Theme.Spacing.sm)
                                            .padding(.vertical, Theme.Spacing.xxs)
                                            .background(Theme.Background.card)
                                            .cornerRadius(Theme.CornerRadius.small)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        Spacer()
                                        
                                        if exportedPath != nil {
                                            Text("Saved to Desktop")
                                                .font(Theme.Typography.small())
                                                .foregroundColor(Theme.Status.success)
                                        }
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Background.card)
                        .cornerRadius(Theme.CornerRadius.medium)
                        .padding(.horizontal, Theme.Spacing.xl)
                        
                        Spacer(minLength: Theme.Spacing.xl)
                        
                        // Quit button at bottom
                        Button(action: { onAction(.quit) }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Quit Setup")
                            }
                            .font(Theme.Typography.body())
                            .foregroundColor(Theme.Text.tertiary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.bottom, Theme.Spacing.xl)
                    }
                }
            }
        }
    }
    
    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: Date())
    }
    
    private func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnosticInfo, forType: .string)
        copied = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
    
    private func exportLogs() {
        let desktopPath = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let fileName = "MacSetupBuddy_Diagnostics_\(Date().timeIntervalSince1970).txt"
        let filePath = desktopPath.appendingPathComponent(fileName)
        
        do {
            try diagnosticInfo.write(to: filePath, atomically: true, encoding: .utf8)
            exportedPath = filePath.path
            onAction(.exportLogs)
        } catch {
            print("Failed to export logs: \(error)")
        }
    }
}

// MARK: - Action Button Component
struct ActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    @Binding var isHovered: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.bodyBold())
                        .foregroundColor(Theme.Text.primary)
                    
                    Text(subtitle)
                        .font(Theme.Typography.small())
                        .foregroundColor(Theme.Text.tertiary)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color.opacity(isHovered ? 1 : 0.5))
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .fill(isHovered ? color.opacity(0.1) : Theme.Background.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .stroke(isHovered ? color.opacity(0.3) : Theme.Border.subtle, lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(Theme.Animation.smooth, value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Inline Error Banner (for embedding in other views)
struct InlineErrorBanner: View {
    let error: InstallationError
    let onRetry: (() -> Void)?
    let onSkip: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: error.icon)
                    .foregroundColor(error.color)
                    .font(.system(size: 18))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(error.title)
                        .font(Theme.Typography.captionBold())
                        .foregroundColor(Theme.Text.primary)
                    
                    if !isExpanded {
                        Text(error.description)
                            .font(Theme.Typography.small())
                            .foregroundColor(Theme.Text.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: Theme.Spacing.xs) {
                    if let onRetry = onRetry, error.canRetry {
                        Button(action: onRetry) {
                            Text("Retry")
                                .font(Theme.Typography.small())
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.Brand.primary)
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, 4)
                                .background(Theme.Brand.primary.opacity(0.15))
                                .cornerRadius(Theme.CornerRadius.small)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if let onSkip = onSkip, error.canSkip {
                        Button(action: onSkip) {
                            Text("Skip")
                                .font(Theme.Typography.small())
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.Status.warning)
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, 4)
                                .background(Theme.Status.warning.opacity(0.15))
                                .cornerRadius(Theme.CornerRadius.small)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if let onDismiss = onDismiss {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.Text.tertiary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(Theme.Spacing.sm)
            .background(error.color.opacity(0.1))
            .overlay(
                Rectangle()
                    .fill(error.color)
                    .frame(width: 4),
                alignment: .leading
            )
        }
        .cornerRadius(Theme.CornerRadius.small)
    }
}

// MARK: - Preview
