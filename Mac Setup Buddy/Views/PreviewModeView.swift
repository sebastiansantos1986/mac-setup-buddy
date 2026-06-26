//
//  PreviewModeView.swift
//  Mac Setup Buddy
//
//  Runtime screen gallery for admins to test branding and copy without running setup actions.
//

import SwiftUI

private enum PreviewScreen: String, CaseIterable, Identifiable {
    case welcome = "Welcome"
    case authentication = "Authentication"
    case deployment = "Deployment"
    case recovery = "Recovery"
    case completion = "Completion"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .welcome: return "sparkles"
        case .authentication: return "envelope.fill"
        case .deployment: return "shippingbox.fill"
        case .recovery: return "exclamationmark.triangle.fill"
        case .completion: return "checkmark.circle.fill"
        }
    }
}

struct PreviewModeView: View {
    let config: CommandLineConfig
    var onExit: (() -> Void)? = nil

    @State private var selectedScreen: PreviewScreen = .welcome

    private var previewConfig: CommandLineConfig {
        var preview = config
        preview.windowWidth = 940
        preview.windowHeight = 640
        preview.bannerTitle = config.bannerTitle ?? "Mac Setup Buddy"
        preview.bannerSubtitle = config.bannerSubtitle ?? "Device setup made simple"
        preview.title = config.title ?? "Welcome to Mac Setup Buddy"
        preview.subtitle = config.subtitle ?? "Device Setup & Configuration"
        preview.message = config.message ?? "Let's get your Mac configured for secure access. This process will verify your account, prepare your device, and install required apps."
        preview.buttonText = config.buttonText ?? "Begin Setup"
        preview.welcomeIcon = config.welcomeIcon ?? "sparkles"
        preview.welcomeTimeEstimate = config.welcomeTimeEstimate ?? "About 10 minutes"
        preview.welcomeStep1 = config.welcomeStep1 ?? "User account verification"
        preview.welcomeStep2 = config.welcomeStep2 ?? "Device registration"
        preview.welcomeStep3 = config.welcomeStep3 ?? "Required app installation"
        preview.welcomeStep4 = config.welcomeStep4 ?? "Security and readiness checks"
        preview.emailPlaceholder = config.emailPlaceholder ?? "chris.brett@example.com"
        preview.userName = config.userName ?? "Brett, Chris"
        preview.email = config.email ?? "chris.brett@example.com"
        preview.userDepartment = config.userDepartment ?? "IT - User Experience"
        preview.userTitle = config.userTitle ?? "Director, End User Services"
        preview.assetTag = config.assetTag ?? "MBA-226TCF"
        preview.deviceName = config.deviceName ?? "MBA-226TCF"
        preview.deviceModel = config.deviceModel ?? "MacBook Air"
        preview.serialNumber = config.serialNumber ?? "LNHX226TCF"
        preview.osVersion = config.osVersion ?? "15.7.3"
        preview.isEncrypted = config.isEncrypted ?? true
        preview.enableLogMonitor = false
        preview.showCountdown = true
        preview.autoCloseDelay = 5

        if preview.installationItems == nil {
            preview.installationItems = [
                InstallationItem(policyUUID: "rosetta", trigger: "install-rosetta", name: "Rosetta 2", description: "Intel app support", icon: "cpu", iconURL: nil, status: .completed, progress: 1),
                InstallationItem(policyUUID: "identity-agent", trigger: "install-identity", name: "Identity Agent", description: "Authentication service", icon: "person.badge.key", iconURL: nil, status: .completed, progress: 1),
                InstallationItem(policyUUID: "teams", trigger: "install-teams", name: "Microsoft Teams", description: "Collaboration platform", icon: "bubble.left.and.bubble.right.fill", iconURL: nil, status: .installing, progress: 0.38),
                InstallationItem(policyUUID: "chrome", trigger: "install-chrome", name: "Google Chrome", description: "Managed browser", icon: "globe", iconURL: nil, status: .pending, progress: 0)
            ]
        }

        return preview
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()
                .background(Theme.Border.subtle)

            ZStack {
                Theme.Background.primary
                    .ignoresSafeArea()

                VStack(spacing: Theme.Spacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Preview Mode")
                                .font(Theme.Typography.title3())
                                .foregroundColor(Theme.Text.primary)

                            Text("Review screens without running installs or policies")
                                .font(Theme.Typography.caption())
                                .foregroundColor(Theme.Text.secondary)
                        }

                        Spacer()

                        Button(action: { onExit?() }) {
                            Label("Close", systemImage: "xmark.circle.fill")
                                .font(Theme.Typography.captionBold())
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Theme.Text.secondary)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)

                    previewSurface
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.lg)
                }
            }
        }
        .frame(width: config.windowWidth, height: config.windowHeight)
        .background(Theme.Background.secondary)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Screens")
                .font(Theme.Typography.captionBold())
                .foregroundColor(Theme.Text.muted)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.lg)

            ForEach(PreviewScreen.allCases) { screen in
                Button {
                    withAnimation(Theme.Animation.smooth) {
                        selectedScreen = screen
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: screen.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 22)

                        Text(screen.rawValue)
                            .font(Theme.Typography.captionBold())

                        Spacer()
                    }
                    .foregroundColor(selectedScreen == screen ? .white : Theme.Text.secondary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                            .fill(selectedScreen == screen ? Theme.Brand.primary : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text("Uses your JSON config, custom banner, and the current macOS light/dark appearance.")
                .font(Theme.Typography.small())
                .foregroundColor(Theme.Text.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Theme.Spacing.md)
        }
        .frame(width: 210)
        .background(Theme.Background.card)
    }

    @ViewBuilder
    private var previewSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                .fill(Theme.Background.secondary)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                        .stroke(Theme.Border.subtle, lineWidth: 1)
                )

            Group {
                switch selectedScreen {
                case .welcome:
                    WelcomeView(config: previewConfig)
                case .authentication:
                    EmailInputView(config: emailPreviewConfig) { _ in }
                case .deployment:
                    InstallationProgressView(config: deploymentPreviewConfig)
                case .recovery:
                    ErrorRecoveryView(
                        error: .policyTimeout(name: "Microsoft Teams", elapsedTime: 720),
                        policyName: "Microsoft Teams",
                        diagnosticInfo: diagnosticInfo,
                        bannerImage: config.bannerImage,
                        onAction: { _ in }
                    )
                case .completion:
                    CompletionView(config: completionPreviewConfig)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            .scaleEffect(scaleForSelectedScreen)
        }
    }

    private var emailPreviewConfig: CommandLineConfig {
        var preview = previewConfig
        preview.windowWidth = 860
        preview.windowHeight = 620
        preview.title = "User Authentication"
        preview.message = "Please enter your work email address"
        return preview
    }

    private var deploymentPreviewConfig: CommandLineConfig {
        var preview = previewConfig
        preview.windowWidth = 1040
        preview.windowHeight = 640
        preview.title = "Software Deployment"
        preview.subtitle = "Installing 10 of 11 components"
        return preview
    }

    private var completionPreviewConfig: CommandLineConfig {
        var preview = previewConfig
        preview.windowWidth = 940
        preview.windowHeight = 640
        preview.title = "Setup Complete!"
        preview.message = "Your Mac is ready to use"
        preview.buttonText = "Exit Setup"
        return preview
    }

    private var scaleForSelectedScreen: CGFloat {
        switch selectedScreen {
        case .deployment:
            return 0.84
        case .recovery:
            return 0.88
        default:
            return 0.92
        }
    }

    private var diagnosticInfo: String {
        """
        Screen: Software Deployment
        Policy: Microsoft Teams
        Network: Wi-Fi connected
        Security: FileVault enabled
        Last event: Package download timed out after retry 2
        """
    }
}

#if DEBUG
struct PreviewModeView_Previews: PreviewProvider {
    static var previews: some View {
        var config = CommandLineConfig()
        config.previewMode = true
        config.windowWidth = 1180
        config.windowHeight = 780
        return PreviewModeView(config: config)
    }
}
#endif
