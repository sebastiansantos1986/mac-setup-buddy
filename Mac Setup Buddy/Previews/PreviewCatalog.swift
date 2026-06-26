//
//  PreviewCatalog.swift
//  Mac Setup Buddy
//
//  Centralized SwiftUI previews for the main setup screens.
//

#if DEBUG
import SwiftUI

private enum PreviewData {
    static var baseConfig: CommandLineConfig {
        var config = CommandLineConfig()
        config.windowWidth = 980
        config.windowHeight = 680
        config.bannerTitle = "Mac Setup Buddy"
        config.bannerSubtitle = "Device setup made simple"
        config.title = "Welcome to Mac Setup Buddy"
        config.subtitle = "Device Setup & Configuration"
        config.message = "Let's get your Mac configured for secure access. This process will verify your account, prepare your device, and install required apps."
        config.buttonText = "Begin Setup"
        config.welcomeIcon = "sparkles"
        config.welcomeTimeEstimate = "About 10 minutes"
        config.welcomeStep1 = "User account verification"
        config.welcomeStep2 = "Device registration"
        config.welcomeStep3 = "Required app installation"
        config.welcomeStep4 = "Security and readiness checks"
        return config
    }

    static var emailConfig: CommandLineConfig {
        var config = baseConfig
        config.windowWidth = 860
        config.windowHeight = 640
        config.title = "User Authentication"
        config.message = "Please enter your work email address"
        config.emailPlaceholder = "chris.brett@example.com"
        return config
    }

    static var deploymentConfig: CommandLineConfig {
        var config = baseConfig
        config.windowWidth = 1280
        config.windowHeight = 780
        config.title = "Software Deployment"
        config.subtitle = "Installing 10 of 11 components"
        config.enableLogMonitor = true
        config.showCountdown = true
        config.autoCloseDelay = 5
        config.installationItems = [
            InstallationItem(
                policyUUID: "rosetta",
                trigger: "install-rosetta",
                name: "Rosetta 2",
                description: "Intel app support",
                icon: "cpu",
                status: .completed,
                progress: 1
            ),
            InstallationItem(
                policyUUID: "connect",
                trigger: "install-connect",
                name: "Identity Agent",
                description: "Authentication service",
                icon: "person.badge.key",
                status: .completed,
                progress: 1
            ),
            InstallationItem(
                policyUUID: "teams",
                trigger: "install-teams",
                name: "Microsoft Teams",
                description: "Collaboration platform",
                icon: "bubble.left.and.bubble.right.fill",
                status: .installing,
                progress: 0.45
            ),
            InstallationItem(
                policyUUID: "browser",
                trigger: "install-browser",
                name: "Google Chrome",
                description: "Managed browser",
                icon: "globe",
                status: .pending,
                progress: 0
            )
        ]
        return config
    }

    static var completionConfig: CommandLineConfig {
        var config = baseConfig
        config.windowWidth = 980
        config.windowHeight = 720
        config.title = "Setup Complete"
        config.message = "Your Mac is ready to use"
        config.buttonText = "Finish"
        config.userName = "Brett, Chris"
        config.email = "chris.brett@example.com"
        config.userDepartment = "IT - User Experience"
        config.userTitle = "Director, End User Services"
        config.assetTag = "MBA-226TCF"
        config.deviceName = "MBA-226TCF"
        config.deviceModel = "MacBook Air"
        config.serialNumber = "LNHX226TCF"
        config.osVersion = "15.7.3"
        config.isEncrypted = true
        return config
    }

    static let diagnosticInfo = """
    Screen: Software Deployment
    Policy: Microsoft Teams
    Network: Wi-Fi connected
    Security: FileVault enabled
    Last event: Package download timed out after retry 2
    """
}

struct MacSetupBuddyPreviewCatalog_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            WelcomeView(config: PreviewData.baseConfig)
                .preferredColorScheme(.light)
                .previewDisplayName("Welcome - Light")

            EmailInputView(config: PreviewData.emailConfig) { _ in }
                .preferredColorScheme(.light)
                .previewDisplayName("User Authentication - Light")

            InstallationProgressView(config: PreviewData.deploymentConfig)
                .preferredColorScheme(.light)
                .previewDisplayName("Software Deployment - Light")

            ErrorRecoveryView(
                error: .policyTimeout(name: "Microsoft Teams", elapsedTime: 720),
                policyName: "Microsoft Teams",
                diagnosticInfo: PreviewData.diagnosticInfo,
                onAction: { _ in }
            )
            .frame(width: 900, height: 680)
            .preferredColorScheme(.light)
            .previewDisplayName("Error Recovery - Light")

            CompletionView(config: PreviewData.completionConfig)
                .preferredColorScheme(.light)
                .previewDisplayName("Setup Complete - Light")

            WelcomeView(config: PreviewData.baseConfig)
                .preferredColorScheme(.dark)
                .previewDisplayName("Welcome - Dark")

            EmailInputView(config: PreviewData.emailConfig) { _ in }
                .preferredColorScheme(.dark)
                .previewDisplayName("User Authentication - Dark")

            InstallationProgressView(config: PreviewData.deploymentConfig)
                .preferredColorScheme(.dark)
                .previewDisplayName("Software Deployment - Dark")

            ErrorRecoveryView(
                error: .policyTimeout(name: "Microsoft Teams", elapsedTime: 720),
                policyName: "Microsoft Teams",
                diagnosticInfo: PreviewData.diagnosticInfo,
                onAction: { _ in }
            )
            .frame(width: 900, height: 680)
            .preferredColorScheme(.dark)
            .previewDisplayName("Error Recovery - Dark")

            CompletionView(config: PreviewData.completionConfig)
                .preferredColorScheme(.dark)
                .previewDisplayName("Setup Complete - Dark")
        }
    }
}
#endif
