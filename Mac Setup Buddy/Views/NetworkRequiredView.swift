//
//  NetworkRequiredView.swift
//  Mac Setup Buddy
//
//  Blocks setup until the Mac has network connectivity.
//

import SwiftUI

struct NetworkRequiredView: View {
    let config: CommandLineConfig
    var onContinue: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var hostResults: [String: Bool] = [:]
    @State private var isCheckingHosts = false
    @State private var glowAnimation = false
    @State private var isHoveredContinue = false
    @State private var isHoveredRetry = false

    private var isReady: Bool {
        networkMonitor.isConnected && !isCheckingHosts && hostResults.values.allSatisfy { $0 }
    }

    var body: some View {
        ZStack {
            Theme.Gradients.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                BannerView(imagePath: config.bannerImage, height: 150, contentMode: .fill)

                Spacer(minLength: Theme.Spacing.lg)

                VStack(spacing: Theme.Spacing.lg) {
                    statusIcon

                    VStack(spacing: Theme.Spacing.xs) {
                        Text(isReady ? "Network Connected" : "Network Required")
                            .font(Theme.Typography.largeTitle())
                            .foregroundColor(Theme.Text.primary)

                        Text(isReady ? "Your Mac can reach the required network services." : "Connect to Wi-Fi or Ethernet before setup can continue.")
                            .font(Theme.Typography.body())
                            .foregroundColor(Theme.Text.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.xxxl)
                    }

                    detailsCard

                    HStack(spacing: Theme.Spacing.md) {
                        Button(action: refreshChecks) {
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: "arrow.clockwise")
                                Text(isCheckingHosts ? "Checking..." : "Check Again")
                            }
                            .font(Theme.Typography.captionBold())
                            .foregroundColor(Theme.Text.secondary)
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.pill)
                                    .fill(Theme.Background.cardElevated)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.CornerRadius.pill)
                                            .stroke(Theme.Border.highlighted, lineWidth: 1)
                                    )
                            )
                            .scaleEffect(isHoveredRetry ? 1.03 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveredRetry = $0 }

                        Button(action: { onContinue?() }) {
                            HStack(spacing: Theme.Spacing.xs) {
                                Text("Continue")
                                Image(systemName: "arrow.right.circle.fill")
                            }
                            .font(Theme.Typography.headline())
                            .foregroundColor(.white.opacity(isReady ? 1 : 0.45))
                            .padding(.horizontal, 42)
                            .padding(.vertical, 13)
                            .background(
                                Group {
                                    if isReady {
                                        Theme.Gradients.primaryButton
                                    } else {
                                        LinearGradient(
                                            colors: [
                                                Theme.Brand.tertiary.opacity(0.35),
                                                Theme.Brand.secondary.opacity(0.35)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    }
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.pill))
                            .shadow(
                                color: Theme.Brand.primary.opacity(isHoveredContinue && isReady ? 0.45 : 0.2),
                                radius: 18,
                                y: 5
                            )
                            .scaleEffect(isHoveredContinue && isReady ? 1.04 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .disabled(!isReady)
                        .onHover { isHoveredContinue = $0 }
                        .keyboardShortcut(.defaultAction)
                    }

                    Button(action: { onCancel?() }) {
                        Text("Quit Setup")
                            .font(Theme.Typography.captionBold())
                            .foregroundColor(Theme.Text.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Spacing.xxxl)

                Spacer(minLength: Theme.Spacing.lg)
            }
        }
        .frame(width: config.windowWidth, height: config.windowHeight)
        .onAppear {
            glowAnimation = true
            refreshChecks()
        }
        .onChange(of: networkMonitor.isConnected) { _, _ in
            refreshChecks()
        }
    }

    private var statusIcon: some View {
        let color = isReady ? Theme.Status.success : Theme.Status.warning

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.38), .clear],
                        center: .center,
                        startRadius: 18,
                        endRadius: 82
                    )
                )
                .frame(width: 150, height: 150)
                .scaleEffect(glowAnimation ? 1.16 : 0.9)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: glowAnimation)

            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 92, height: 92)

            Image(systemName: isReady ? "wifi.circle.fill" : "wifi.exclamationmark")
                .font(.system(size: 52, weight: .semibold))
                .foregroundColor(color)
        }
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            NetworkRequirementRow(
                icon: "network",
                title: "Network Status",
                value: networkMonitor.isConnected ? networkMonitor.connectionType.rawValue : "Disconnected",
                isPassing: networkMonitor.isConnected
            )

            if let hosts = config.networkCheckHosts, !hosts.isEmpty {
                Divider().background(Theme.Border.subtle)

                ForEach(hosts, id: \.self) { host in
                    NetworkRequirementRow(
                        icon: "server.rack",
                        title: host,
                        value: hostStatusText(for: host),
                        isPassing: hostResults[host] ?? false
                    )
                }
            }

            if !networkMonitor.isConnected {
                Divider().background(Theme.Border.subtle)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Try this:")
                        .font(Theme.Typography.captionBold())
                        .foregroundColor(Theme.Text.primary)

                    TroubleshootingRow(icon: "wifi", text: "Join a trusted Wi-Fi network")
                    TroubleshootingRow(icon: "cable.connector", text: "Connect an Ethernet adapter")
                    TroubleshootingRow(icon: "lock.shield", text: "Sign into captive portal if your network requires it")
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: 680)
        .glassCard(cornerRadius: Theme.CornerRadius.large)
    }

    private func hostStatusText(for host: String) -> String {
        if isCheckingHosts {
            return "Checking"
        }

        guard let result = hostResults[host] else {
            return "Not checked"
        }

        return result ? "Reachable" : "Not reachable"
    }

    private func refreshChecks() {
        guard networkMonitor.isConnected else {
            hostResults = [:]
            isCheckingHosts = false
            return
        }

        let hosts = config.networkCheckHosts ?? []
        guard !hosts.isEmpty else {
            hostResults = [:]
            isCheckingHosts = false
            return
        }

        isCheckingHosts = true
        hostResults = Dictionary(uniqueKeysWithValues: hosts.map { ($0, false) })

        let group = DispatchGroup()
        var results: [String: Bool] = [:]

        for host in hosts {
            group.enter()
            networkMonitor.checkHost(host) { reachable in
                results[host] = reachable
                group.leave()
            }
        }

        group.notify(queue: .main) {
            hostResults = results
            isCheckingHosts = false
        }
    }
}

struct NetworkRequirementRow: View {
    let icon: String
    let title: String
    let value: String
    let isPassing: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(isPassing ? Theme.Status.success : Theme.Status.warning)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.captionBold())
                    .foregroundColor(Theme.Text.primary)

                Text(value)
                    .font(Theme.Typography.small())
                    .foregroundColor(Theme.Text.secondary)
            }

            Spacer()

            Image(systemName: isPassing ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(isPassing ? Theme.Status.success : Theme.Status.warning)
        }
    }
}

struct NetworkGateView: View {
    let config: CommandLineConfig
    let content: AnyView
    var onCancel: (() -> Void)? = nil

    @State private var isUnlocked = false

    var body: some View {
        if isUnlocked {
            content
        } else {
            NetworkRequiredView(
                config: config,
                onContinue: { isUnlocked = true },
                onCancel: onCancel
            )
        }
    }
}

#if DEBUG
struct NetworkRequiredView_Previews: PreviewProvider {
    static var previews: some View {
        var config = CommandLineConfig()
        config.windowWidth = 900
        config.windowHeight = 680
        config.networkCheckHosts = ["https://apple.com", "https://example.com"]
        return NetworkRequiredView(config: config)
    }
}
#endif
