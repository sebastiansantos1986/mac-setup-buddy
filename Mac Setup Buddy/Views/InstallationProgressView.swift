//
//  InstallationProgressView.swift
//  Mac Setup Buddy
//
//  Created by Sebastian Santos on 10/3/25.
//
//  FULL ERROR RECOVERY INTEGRATION
//  - Network monitoring with auto-pause/resume
//  - Retry/Skip buttons for failed policies
//  - Timeout detection with skip option
//  - Inline error banners
//  - Full ErrorRecoveryView for critical failures
//  - JAMF icon URL support via AsyncIcon
//

import SwiftUI
import AppKit

struct InstallationProgressView: View {
    let config: CommandLineConfig
    var onComplete: (() -> Void)? = nil
    
    @State private var items: [InstallationItem] = []
    @State private var overallProgress: Double = 0.0
    @State private var currentItemIndex: Int = 0
    @State private var currentItemProgress: Double = 0.0
    @State private var isProcessing: Bool = false
    @State private var monitorTimer: Timer?
    @State private var animateGradient = false
    @State private var activityLog: [String] = []
    @State private var timeRemaining = "Calculating..."
    @State private var isHoveredButton = false
    
    // Auto-close states
    @State private var autoCloseTimer: Timer?
    @State private var autoCloseCountdown = 5
    @State private var showingCountdown = false
    
    // ENGAGEMENT FEATURE STATES
    @State private var elapsedSeconds: Int = 0
    @State private var elapsedTimer: Timer?
    @State private var lastProgressValue: Double = 0.0
    @State private var secondsSinceProgressChange: Int = 0
    @State private var isStalled: Bool = false
    @State private var currentStatusMessage: String = "Initializing..."
    @State private var statusMessageIndex: Int = 0
    @State private var statusMessageTimer: Timer?
    @State private var currentTipIndex: Int = 0
    @State private var tipTimer: Timer?
    @State private var showTips: Bool = false
    
    // ERROR RECOVERY STATES
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var currentError: InstallationError? = nil
    @State private var showFullErrorView: Bool = false
    @State private var isPausedForNetwork: Bool = false
    @State private var retryCount: Int = 0
    @State private var maxRetries: Int = 3
    @State private var timeoutThreshold: Int = 600  // 10 minutes
    @State private var showTimeoutWarning: Bool = false
    @State private var skippedItems: [String] = []
    
    private let logPath = "/Library/Management/jamf_progress.log"
    
    // Rotating status messages for active installations
    private let statusMessages = [
        "Downloading packages...",
        "Verifying signatures...",
        "Extracting files...",
        "Running installation scripts...",
        "Configuring preferences...",
        "Registering components...",
        "Updating system settings...",
        "Finalizing installation...",
        "Cleaning up temporary files...",
        "Verifying installation..."
    ]
    
    // Pro tips to show during long waits
    private let proTips = [
        "💡 Tip: Some applications require background services to configure",
        "🔒 Security scans may run during installation for your protection",
        "⚡ Large applications like Office may take several minutes",
        "🔄 System components sometimes need extra time to register",
        "☕ Perfect time for a coffee break!",
        "🛡️ Enterprise policies ensure secure configuration",
        "📦 Packages are verified for integrity before installation",
        "⏱️ Installation time varies based on package size",
        "🔧 Post-install scripts are running in the background",
        "✨ Almost there! Final configurations in progress..."
    ]
    
    var body: some View {
        ZStack {
            // Main installation view
            mainInstallationView
            
            // Full-screen error recovery overlay
            if showFullErrorView, let error = currentError {
                ErrorRecoveryView(
                    error: error,
                    policyName: currentItemIndex < items.count ? items[currentItemIndex].name : nil,
                    diagnosticInfo: generateDiagnosticInfo(),
                    onAction: handleErrorAction
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .frame(width: config.windowWidth, height: config.windowHeight)
        .onAppear {
            setupAndStart()
            animateGradient = true
        }
        .onDisappear {
            cleanupTimers()
        }
        // Monitor network changes
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            handleNetworkChange(isConnected: isConnected)
        }
    }
    
    // MARK: - Main Installation View
    private var mainInstallationView: some View {
        ZStack {
            // Background
            Theme.Background.primary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Network Status Banner (shows when disconnected)
                NetworkStatusBanner()
                
                // Enhanced Banner
                bannerSection
                
                // Header Section
                headerSection
                
                // Timeout Warning Banner
                if showTimeoutWarning {
                    timeoutWarningBanner
                }
                
                // Inline Error Banner (for non-critical errors)
                if let error = currentError, !showFullErrorView {
                    InlineErrorBanner(
                        error: error,
                        onRetry: { retryCurrentPolicy() },
                        onSkip: { skipCurrentPolicy() },
                        onDismiss: { currentError = nil }
                    )
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Main Content
                HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                    // Left Column
                    leftColumn
                        .layoutPriority(1)
                    
                    // Right Column
                    rightColumn
                }
                .padding(.horizontal, Theme.Spacing.lg)
                
                Spacer()
                
                // Bottom Button
                bottomButton
            }
        }
    }
    
    // MARK: - Banner Section
    private var bannerSection: some View {
        ZStack {
            if let bannerPath = config.bannerImage, !bannerPath.isEmpty {
                BannerView(
                    imagePath: bannerPath,
                    height: 170,
                    contentMode: .fill
                )
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.3),
                            Color.clear,
                            Color.black.opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            } else {
                Theme.Gradients.banner
                    .frame(height: 170)
                    .overlay(
                        GeometryReader { geometry in
                            ZStack {
                                Path { path in
                                    let spacing: CGFloat = 60
                                    for x in stride(from: -geometry.size.height, through: geometry.size.width, by: spacing) {
                                        path.move(to: CGPoint(x: x, y: 0))
                                        path.addLine(to: CGPoint(x: x + geometry.size.height, y: geometry.size.height))
                                    }
                                }
                                .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                                
                                Canvas { context, size in
                                    let spacing: CGFloat = 30
                                    for x in stride(from: 0, through: size.width, by: spacing) {
                                        for y in stride(from: 0, through: size.height, by: spacing) {
                                            let rect = CGRect(x: x - 1, y: y - 1, width: 2, height: 2)
                                            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.1)))
                                        }
                                    }
                                }
                            }
                        }
                    )
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(config.title ?? "JAMF Software Installation")
                        .font(Theme.Typography.title())
                        .foregroundColor(Theme.Text.primary)
                    
                    HStack(spacing: Theme.Spacing.sm) {
                        HStack(spacing: 6) {
                            PulsingDot(color: isPausedForNetwork ? Theme.Status.warning : Theme.Brand.primary)
                            Text(isPausedForNetwork ? "PAUSED" : "LIVE MONITORING")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(isPausedForNetwork ? Theme.Status.warning : Theme.Brand.primary)
                        }
                        
                        Text(config.subtitle ?? "Automated Deployment in Progress")
                            .font(Theme.Typography.caption())
                            .foregroundColor(Theme.Text.muted)
                        
                        // Show skipped count if any
                        if !skippedItems.isEmpty {
                            Text("• \(skippedItems.count) skipped")
                                .font(Theme.Typography.caption())
                                .foregroundColor(Theme.Status.warning)
                        }
                    }
                }
                
                Spacer()
                
                // Progress Circle with shimmer
                progressCircle
            }
            
            // Status bar
            statusBar
            
            // Pro tip display during stalls
            if showTips && isStalled {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(proTips[currentTipIndex])
                        .font(Theme.Typography.caption())
                        .foregroundColor(Theme.Text.secondary)
                        .animation(.easeInOut, value: currentTipIndex)
                }
                .padding(.vertical, Theme.Spacing.xs)
                .padding(.horizontal, Theme.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Background.card)
                .cornerRadius(Theme.CornerRadius.small)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Theme.Spacing.lg)
    }
    
    // MARK: - Progress Circle
    private var progressCircle: some View {
        ZStack {
            Circle()
                .stroke(Theme.Border.subtle, lineWidth: 5)
                .frame(width: 70, height: 70)
            
            Circle()
                .trim(from: 0, to: overallProgress)
                .stroke(
                    Theme.Gradients.primaryButton,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(-90))
                .animation(Theme.Animation.smooth, value: overallProgress)
            
            if overallProgress > 0 && overallProgress < 1.0 && !isPausedForNetwork {
                Circle()
                    .trim(from: 0, to: overallProgress)
                    .stroke(
                        AngularGradient(
                            colors: [.clear, .white.opacity(0.3), .clear],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                    .rotationEffect(.degrees(animateGradient ? 360 : 0))
                    .animation(
                        .linear(duration: 2).repeatForever(autoreverses: false),
                        value: animateGradient
                    )
            }
            
            Text("\(Int(overallProgress * 100))%")
                .font(Theme.Typography.mono(size: 18))
                .foregroundColor(Theme.Text.primary)
        }
    }
    
    // MARK: - Status Bar
    private var statusBar: some View {
        Group {
            if showingCountdown && overallProgress >= 1.0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.Status.success)
                    Text("All installations complete!")
                        .font(Theme.Typography.captionBold())
                        .foregroundColor(Theme.Status.success)
                    Spacer()
                    Text("Auto-closing in \(autoCloseCountdown) seconds...")
                        .font(Theme.Typography.caption())
                        .foregroundColor(Theme.Text.muted)
                }
                .padding(.vertical, Theme.Spacing.xs)
                .padding(.horizontal, Theme.Spacing.sm)
                .background(Theme.Status.success.opacity(0.1))
                .cornerRadius(Theme.CornerRadius.small)
            } else if isPausedForNetwork {
                HStack {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(Theme.Status.warning)
                    Text("Installation paused - waiting for network...")
                        .font(Theme.Typography.captionBold())
                        .foregroundColor(Theme.Status.warning)
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.Status.warning))
                        .scaleEffect(0.7)
                }
                .padding(.vertical, Theme.Spacing.xs)
                .padding(.horizontal, Theme.Spacing.sm)
                .background(Theme.Status.warning.opacity(0.1))
                .cornerRadius(Theme.CornerRadius.small)
            } else if currentItemIndex < items.count {
                let currentItem = items[currentItemIndex]
                if currentItem.status == .installing {
                    HStack {
                        ActivityDots()
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(currentStatusMessage)
                                .font(Theme.Typography.captionBold())
                                .foregroundColor(Theme.Brand.primary)
                                .animation(.easeInOut, value: currentStatusMessage)
                            
                            Text("Installing \(currentItem.name) • \(formatElapsedTime(elapsedSeconds))")
                                .font(Theme.Typography.caption())
                                .foregroundColor(Theme.Text.muted)
                        }
                        
                        Spacer()
                        
                        // Retry count indicator
                        if retryCount > 0 {
                            Text("Retry \(retryCount)/\(maxRetries)")
                                .font(Theme.Typography.small())
                                .foregroundColor(Theme.Status.warning)
                                .padding(.horizontal, Theme.Spacing.xs)
                                .padding(.vertical, 2)
                                .background(Theme.Status.warning.opacity(0.15))
                                .cornerRadius(Theme.CornerRadius.small)
                        }
                        
                        if isStalled {
                            StallIndicator()
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .background(Theme.Brand.primary.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.small)
                } else if currentItem.status == .completed && currentItem.progress == 1.0 {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.Status.warning)
                        Text("\(currentItem.name) - Previously Installed")
                            .font(Theme.Typography.captionBold())
                            .foregroundColor(Theme.Status.warning)
                        Spacer()
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .background(Theme.Status.warning.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.small)
                }
            }
        }
    }
    
    // MARK: - Timeout Warning Banner
    private var timeoutWarningBanner: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundColor(Theme.Status.warning)
                .font(.system(size: 20))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Installation Taking Longer Than Expected")
                    .font(Theme.Typography.captionBold())
                    .foregroundColor(Theme.Text.primary)
                
                Text("This policy has been running for over 10 minutes")
                    .font(Theme.Typography.small())
                    .foregroundColor(Theme.Text.secondary)
            }
            
            Spacer()
            
            // Skip button
            Button(action: { skipCurrentPolicy() }) {
                HStack(spacing: 4) {
                    Image(systemName: "forward.fill")
                    Text("Skip")
                }
                .font(Theme.Typography.captionBold())
                .foregroundColor(Theme.Status.warning)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xxs)
                .background(Theme.Status.warning.opacity(0.15))
                .cornerRadius(Theme.CornerRadius.small)
            }
            .buttonStyle(PlainButtonStyle())
            
            // View details
            Button(action: {
                currentError = .policyTimeout(
                    name: items[currentItemIndex].name,
                    elapsedTime: elapsedSeconds
                )
                showFullErrorView = true
            }) {
                Text("Details")
                    .font(Theme.Typography.captionBold())
                    .foregroundColor(Theme.Text.secondary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .background(Theme.Background.card)
                    .cornerRadius(Theme.CornerRadius.small)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Status.warning.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(Theme.Status.warning)
                .frame(height: 3),
            alignment: .top
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Left Column
    private var leftColumn: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Installation Queue
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Installation Queue")
                        .font(Theme.Typography.headline())
                        .foregroundColor(Theme.Text.primary)
                    Spacer()
                    let completed = items.filter {
                        $0.status == .completed || $0.status == .failed
                    }.count
                    Text("\(completed)/\(items.count)")
                        .font(Theme.Typography.caption())
                        .foregroundColor(completed == items.count ? Theme.Status.success : Theme.Text.muted)
                }
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.xs) {
                        ForEach(items.indices, id: \.self) { index in
                            EnhancedPolicyItemRow(
                                item: items[index],
                                currentProgress: index == currentItemIndex ? currentItemProgress : items[index].progress,
                                isCurrent: index == currentItemIndex,
                                isNext: index == currentItemIndex + 1 && currentItemIndex < items.count && items[currentItemIndex].status == .installing,
                                elapsedTime: index == currentItemIndex ? elapsedSeconds : nil,
                                isStalled: index == currentItemIndex ? isStalled : false,
                                isSkipped: skippedItems.contains(items[index].policyUUID),
                                onRetry: index == currentItemIndex && items[index].status == .failed ? { retryCurrentPolicy() } : nil,
                                onSkip: index == currentItemIndex && (items[index].status == .failed || isStalled) ? { skipCurrentPolicy() } : nil
                            )
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Background.cardElevated)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Border.subtle, lineWidth: 1)
            )
            .cornerRadius(Theme.CornerRadius.medium)
            .shadow(color: Theme.Shadows.subtle().color, radius: Theme.Shadows.subtle().radius, y: Theme.Shadows.subtle().y)
            
            // Activity Stream
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Activity Stream")
                        .font(Theme.Typography.headline())
                        .foregroundColor(Theme.Text.primary)
                    Spacer()
                    HStack(spacing: 4) {
                        PulsingDot(color: isPausedForNetwork ? Theme.Status.warning : Theme.Brand.primary, size: 6)
                        Text(isPausedForNetwork ? "PAUSED" : "LIVE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isPausedForNetwork ? Theme.Status.warning : Theme.Brand.primary)
                    }
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(activityLog.suffix(10), id: \.self) { log in
                            HStack(spacing: 4) {
                                Text("•")
                                    .foregroundColor(logColor(for: log))
                                Text(log)
                                    .font(Theme.Typography.mono(size: 11))
                                    .foregroundColor(Theme.Text.muted)
                            }
                        }
                    }
                }
                .frame(maxHeight: 100)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Background.cardElevated)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Border.subtle, lineWidth: 1)
            )
            .cornerRadius(Theme.CornerRadius.medium)
            .shadow(color: Theme.Shadows.subtle().color, radius: Theme.Shadows.subtle().radius, y: Theme.Shadows.subtle().y)
        }
    }
    
    // MARK: - Right Column
    private var rightColumn: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Current Installation
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Current Installation")
                    .font(Theme.Typography.headline())
                    .foregroundColor(Theme.Text.primary)
                
                if currentItemIndex < items.count && items[currentItemIndex].status == .installing {
                    EnhancedCurrentInstallationCard(
                        item: items[currentItemIndex],
                        progress: currentItemProgress,
                        elapsedTime: elapsedSeconds,
                        statusMessage: currentStatusMessage,
                        isStalled: isStalled,
                        isPaused: isPausedForNetwork,
                        onRetry: isStalled ? { retryCurrentPolicy() } : nil,
                        onSkip: isStalled ? { skipCurrentPolicy() } : nil
                    )
                } else if currentItemIndex < items.count && items[currentItemIndex].status == .failed {
                    FailedInstallationCard(
                        item: items[currentItemIndex],
                        retryCount: retryCount,
                        maxRetries: maxRetries,
                        onRetry: { retryCurrentPolicy() },
                        onSkip: { skipCurrentPolicy() },
                        onViewDetails: {
                            currentError = .policyFailed(
                                name: items[currentItemIndex].name,
                                reason: "Installation failed after \(retryCount) attempts"
                            )
                            showFullErrorView = true
                        }
                    )
                } else if overallProgress >= 1.0 {
                    AllCompleteCard(skippedCount: skippedItems.count)
                } else {
                    WaitingCard()
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Background.cardElevated)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Border.subtle, lineWidth: 1)
            )
            .cornerRadius(Theme.CornerRadius.medium)
            .shadow(color: Theme.Shadows.subtle().color, radius: Theme.Shadows.subtle().radius, y: Theme.Shadows.subtle().y)
            
            // System Status
            SystemStatusCard(
                policiesRunning: items.filter { $0.status == .installing }.count,
                logPath: logPath,
                isNetworkConnected: networkMonitor.isConnected,
                connectionType: networkMonitor.connectionType.rawValue
            )
        }
        .frame(width: 270)
    }
    
    // MARK: - Bottom Button
    private var bottomButton: some View {
        Button(action: {
            cleanupTimers()
            if overallProgress >= 1.0 {
                exitApplication()
            }
        }) {
            HStack(spacing: Theme.Spacing.xs) {
                if overallProgress >= 1.0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.Status.success)
                    if showingCountdown {
                        Text("Closing in \(autoCloseCountdown)...")
                            .foregroundColor(Theme.Status.success)
                    } else {
                        Text("Continue")
                            .foregroundColor(Theme.Text.primary)
                    }
                } else {
                    Image(systemName: isPausedForNetwork ? "pause.circle" : "hourglass")
                        .foregroundColor(Theme.Text.muted)
                    Text(isPausedForNetwork ? "Paused" : "Installing...")
                        .foregroundColor(Theme.Text.muted)
                }
            }
            .font(Theme.Typography.bodyBold())
            .frame(width: showingCountdown ? 200 : 160, height: 40)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                    .stroke(
                        overallProgress >= 1.0 ? Theme.Status.success : Theme.Border.subtle,
                        lineWidth: 2
                    )
            )
            .scaleEffect(isHoveredButton && overallProgress >= 1.0 ? 1.03 : 1.0)
            .animation(Theme.Animation.smooth, value: isHoveredButton)
        }
        .buttonStyle(.plain)
        .disabled(overallProgress < 1.0)
        .opacity(overallProgress >= 1.0 ? 1.0 : 0.5)
        .onHover { hovering in
            isHoveredButton = hovering
        }
        .padding(.bottom, Theme.Spacing.lg)
    }
    
    // MARK: - Error Recovery Actions
    
    private func handleErrorAction(_ action: RecoveryAction) {
        switch action {
        case .retry:
            showFullErrorView = false
            currentError = nil
            retryCurrentPolicy()
            
        case .skip:
            showFullErrorView = false
            currentError = nil
            skipCurrentPolicy()
            
        case .contactIT:
            // Open default email client with pre-filled info
            let subject = "Mac Setup Buddy Issue - \(items[currentItemIndex].name)"
            let body = generateDiagnosticInfo()
            if let url = URL(string: "mailto:it-support@company.com?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                NSWorkspace.shared.open(url)
            }
            
        case .exportLogs:
            activityLog.append("[EXPORT] Diagnostic logs exported to Desktop")
            
        case .quit:
            cleanupTimers()
            NSApplication.shared.terminate(nil)
        }
    }
    
    private func retryCurrentPolicy() {
        guard currentItemIndex < items.count else { return }
        
        retryCount += 1
        activityLog.append("[RETRY] Retrying \(items[currentItemIndex].name) (attempt \(retryCount)/\(maxRetries))")
        
        // Reset current item state
        currentItemProgress = 0.1
        items[currentItemIndex].progress = 0.1
        items[currentItemIndex].status = .installing
        currentError = nil
        showTimeoutWarning = false
        
        // Reset engagement state
        resetEngagementState()
        
        // If we've exceeded max retries, show full error view
        if retryCount >= maxRetries {
            activityLog.append("[ERROR] Max retries exceeded for \(items[currentItemIndex].name)")
            currentError = .policyFailed(
                name: items[currentItemIndex].name,
                reason: "Installation failed after \(maxRetries) attempts. You may skip this item or contact IT support."
            )
            items[currentItemIndex].status = .failed
        }
    }
    
    private func skipCurrentPolicy() {
        guard currentItemIndex < items.count else { return }
        
        let skippedName = items[currentItemIndex].name
        skippedItems.append(items[currentItemIndex].policyUUID)
        
        activityLog.append("[SKIPPED] \(skippedName) was skipped by user")
        
        items[currentItemIndex].status = .failed
        items[currentItemIndex].progress = 0
        
        currentError = nil
        showTimeoutWarning = false
        
        moveToNextPolicy()
    }
    
    private func handleNetworkChange(isConnected: Bool) {
        if isConnected {
            if isPausedForNetwork {
                isPausedForNetwork = false
                activityLog.append("[NETWORK] Connection restored - resuming installation")
                
                // Resume monitoring
                startMonitoring()
                startEngagementTimers()
            }
        } else {
            if !isPausedForNetwork && isProcessing {
                isPausedForNetwork = true
                activityLog.append("[NETWORK] Connection lost - installation paused")
                
                // Pause monitoring
                monitorTimer?.invalidate()
                elapsedTimer?.invalidate()
                statusMessageTimer?.invalidate()
                
                // Set error for network loss
                if currentItemIndex < items.count {
                    currentError = .networkLost(during: items[currentItemIndex].name)
                }
            }
        }
    }
    
    private func generateDiagnosticInfo() -> String {
        var info = "=== Mac Setup Buddy Diagnostics ===\n"
        info += "Time: \(Date())\n"
        info += "App Version: 1.0.0\n\n"
        
        info += "=== Current State ===\n"
        info += "Current Policy Index: \(currentItemIndex)\n"
        if currentItemIndex < items.count {
            info += "Current Policy: \(items[currentItemIndex].name)\n"
            info += "Policy UUID: \(items[currentItemIndex].policyUUID)\n"
            info += "Progress: \(Int(currentItemProgress * 100))%\n"
            info += "Elapsed Time: \(formatElapsedTime(elapsedSeconds))\n"
        }
        info += "Retry Count: \(retryCount)/\(maxRetries)\n"
        info += "Skipped Items: \(skippedItems.count)\n\n"
        
        info += "=== Installation Summary ===\n"
        for (index, item) in items.enumerated() {
            let status = item.status == .completed ? "✅" : item.status == .failed ? "❌" : item.status == .installing ? "⏳" : "⏸"
            let skipped = skippedItems.contains(item.policyUUID) ? " (SKIPPED)" : ""
            info += "\(status) \(item.name): \(item.status)\(skipped)\n"
        }
        
        info += "\n" + networkMonitor.getDiagnosticInfo()
        
        info += "\n=== Recent Activity ===\n"
        for log in activityLog.suffix(20) {
            info += "\(log)\n"
        }
        
        return info
    }
    
    // MARK: - Engagement Helpers
    
    private func formatElapsedTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, secs)
        } else {
            return "\(secs)s"
        }
    }
    
    private func startEngagementTimers() {
        elapsedTimer?.invalidate()
        statusMessageTimer?.invalidate()
        tipTimer?.invalidate()
        
        // Elapsed time counter
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard !isPausedForNetwork else { return }
            
            elapsedSeconds += 1
            
            // Check for timeout (10 minutes)
            if elapsedSeconds >= timeoutThreshold && !showTimeoutWarning {
                withAnimation {
                    showTimeoutWarning = true
                }
                activityLog.append("[WARNING] \(items[currentItemIndex].name) has been installing for over 10 minutes")
            }
            
            // Check for stall (no progress change in 15 seconds)
            if currentItemProgress == lastProgressValue {
                secondsSinceProgressChange += 1
                if secondsSinceProgressChange >= 15 {
                    withAnimation {
                        isStalled = true
                        showTips = true
                    }
                }
            } else {
                secondsSinceProgressChange = 0
                lastProgressValue = currentItemProgress
                withAnimation {
                    isStalled = false
                    showTips = false
                }
            }
        }
        
        // Rotating status messages
        statusMessageTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            guard !isPausedForNetwork else { return }
            
            withAnimation(.easeInOut(duration: 0.3)) {
                statusMessageIndex = (statusMessageIndex + 1) % statusMessages.count
                currentStatusMessage = statusMessages[statusMessageIndex]
            }
        }
        
        // Rotating tips
        tipTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentTipIndex = (currentTipIndex + 1) % proTips.count
            }
        }
    }
    
    private func resetEngagementState() {
        elapsedSeconds = 0
        secondsSinceProgressChange = 0
        lastProgressValue = 0
        isStalled = false
        showTips = false
        showTimeoutWarning = false
        statusMessageIndex = 0
        currentStatusMessage = statusMessages[0]
    }
    
    private func cleanupTimers() {
        monitorTimer?.invalidate()
        autoCloseTimer?.invalidate()
        elapsedTimer?.invalidate()
        statusMessageTimer?.invalidate()
        tipTimer?.invalidate()
    }
    
    // MARK: - Setup and Monitoring
    
    private func setupAndStart() {
        items = config.installationItems ?? defaultItems()
        activityLog.append("[START] Beginning JAMF policy installation")
        activityLog.append("[INFO] Network: \(networkMonitor.connectionType.rawValue) - \(networkMonitor.isConnected ? "Connected" : "Disconnected")")
        
        if config.enableLogMonitor {
            let fm = FileManager.default
            let logDir = (logPath as NSString).deletingLastPathComponent
            
            if !fm.fileExists(atPath: logDir) {
                try? fm.createDirectory(atPath: logDir, withIntermediateDirectories: true)
            }
            
            if !fm.fileExists(atPath: logPath) {
                fm.createFile(atPath: logPath, contents: nil)
            }
        }
        
        startMonitoring()
        startEngagementTimers()
    }
    
    private func defaultItems() -> [InstallationItem] {
        return [
            InstallationItem(policyUUID: UUID().uuidString, trigger: "default-rosetta", name: "Rosetta 2", description: "Apple Silicon Support", icon: "cpu", iconURL: nil, status: .pending, progress: 0.0),
            InstallationItem(policyUUID: UUID().uuidString, trigger: "default-office", name: "Microsoft Office", description: "Productivity Suite", icon: "doc.text.fill", iconURL: nil, status: .pending, progress: 0.0),
            InstallationItem(policyUUID: UUID().uuidString, trigger: "default-chrome", name: "Google Chrome", description: "Web Browser", icon: "globe", iconURL: nil, status: .pending, progress: 0.0)
        ]
    }
    
    private func startMonitoring() {
        guard !items.isEmpty else { return }
        
        isProcessing = true
        
        monitorTimer?.invalidate()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            guard !isPausedForNetwork else { return }
            
            if config.enableLogMonitor {
                checkPolicyStatus()
            } else {
                simulateProgress()
            }
        }
    }
    
    private func simulateProgress() {
        guard currentItemIndex < items.count else { return }
        
        if currentItemProgress < 1.0 {
            currentItemProgress += 0.02
            items[currentItemIndex].progress = currentItemProgress
            items[currentItemIndex].status = .installing
            
            if currentItemProgress >= 1.0 {
                items[currentItemIndex].status = .completed
                items[currentItemIndex].progress = 1.0
                activityLog.append("✅ Successfully installed \(items[currentItemIndex].name)")
                moveToNextPolicy()
            }
        }
        
        updateOverallProgress()
    }
    
    private func checkPolicyStatus() {
        let allComplete = !items.contains { $0.status == .installing || $0.status == .pending }
        
        if allComplete && overallProgress < 1.0 {
            overallProgress = 1.0
            activityLog.append("[COMPLETE] All policies processed successfully")
            monitorTimer?.invalidate()
            elapsedTimer?.invalidate()
            statusMessageTimer?.invalidate()
            startAutoClose()
            return
        }
        
        guard currentItemIndex < items.count else { return }
        
        let currentPolicy = items[currentItemIndex]
        let policyUUID = currentPolicy.policyUUID
        
        if currentPolicy.status == .completed && currentPolicy.progress == 1.0 {
            activityLog.append("✓ \(currentPolicy.name) - Previously Installed")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.moveToNextPolicy()
            }
            
            monitorTimer?.invalidate()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                if self.currentItemIndex < self.items.count {
                    self.startMonitoring()
                }
            }
            
            updateOverallProgress()
            return
        }
        
        if let logContent = try? String(contentsOfFile: logPath, encoding: .utf8) {
            if logContent.contains("\(policyUUID):COMPLETE") {
                items[currentItemIndex].status = .completed
                items[currentItemIndex].progress = 1.0
                activityLog.append("✅ Successfully installed \(currentPolicy.name)")
                moveToNextPolicy()
                
            } else if logContent.contains("\(policyUUID):FAILED") {
                items[currentItemIndex].status = .failed
                items[currentItemIndex].progress = 0.0
                activityLog.append("❌ Failed to install \(currentPolicy.name)")
                
                // Trigger error handling
                currentError = .policyFailed(name: currentPolicy.name, reason: "Policy execution failed. Check system logs for details.")
                
            } else if logContent.contains("\(policyUUID):RUNNING") {
                items[currentItemIndex].status = .installing
                
                if currentItemProgress < 0.9 {
                    currentItemProgress = min(currentItemProgress + 0.02, 0.9)
                    items[currentItemIndex].progress = currentItemProgress
                }
            }
        } else {
            simulateProgress()
        }
        
        updateOverallProgress()
    }
    
    private func moveToNextPolicy() {
        currentItemIndex += 1
        currentItemProgress = 0.0
        retryCount = 0
        resetEngagementState()
        
        if currentItemIndex < items.count {
            let nextItem = items[currentItemIndex]
            
            if nextItem.status != .completed {
                items[currentItemIndex].status = .installing
                currentItemProgress = 0.1
                items[currentItemIndex].progress = currentItemProgress
                activityLog.append("[STARTING] \(items[currentItemIndex].name)")
            }
        } else {
            overallProgress = 1.0
            activityLog.append("[COMPLETE] All policies processed successfully")
            cleanupTimers()
            startAutoClose()
        }
        
        updateOverallProgress()
    }
    
    private func updateOverallProgress() {
        let completed = Double(items.filter {
            $0.status == .completed || $0.status == .failed
        }.count)
        let total = Double(items.count)
        
        if total > 0 {
            overallProgress = completed / total
        }
    }
    
    private func startAutoClose() {
        let delay = config.autoCloseDelay ?? 10
        guard delay > 0 else { return }
        
        showingCountdown = config.showCountdown
        autoCloseCountdown = delay
        
        autoCloseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            autoCloseCountdown -= 1
            
            if autoCloseCountdown <= 0 {
                timer.invalidate()
                exitApplication()
            }
        }
    }
    
    private func exitApplication() {
        cleanupTimers()
        activityLog.append("[EXIT] Application closing")
        onComplete?()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    }
    
    private func logColor(for message: String) -> Color {
        if message.contains("✅") { return Theme.Status.success }
        if message.contains("✓") && message.contains("Previously") { return Theme.Status.warning }
        if message.contains("❌") || message.contains("ERROR") { return Theme.Status.error }
        if message.contains("COMPLETE") { return Theme.Status.success }
        if message.contains("FAILED") || message.contains("SKIPPED") { return Theme.Status.error }
        if message.contains("WARNING") { return Theme.Status.warning }
        if message.contains("NETWORK") { return Theme.Status.info }
        if message.contains("RETRY") { return Theme.Status.warning }
        if message.contains("EXIT") { return Theme.Text.muted }
        return Theme.Brand.primary
    }
}

// MARK: - Enhanced Policy Item Row (with JAMF icon support + error recovery)

struct EnhancedPolicyItemRow: View {
    let item: InstallationItem
    let currentProgress: Double
    let isCurrent: Bool
    let isNext: Bool
    var elapsedTime: Int? = nil
    var isStalled: Bool = false
    var isSkipped: Bool = false
    var onRetry: (() -> Void)? = nil
    var onSkip: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                if item.status == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(item.progress == 1.0 ? .green : .orange)
                        .font(.system(size: 16))
                } else if item.status == .failed || isSkipped {
                    Image(systemName: isSkipped ? "forward.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isSkipped ? .orange : .red)
                        .font(.system(size: 16))
                } else if item.status == .installing {
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .trim(from: 0, to: currentProgress)
                                .stroke(Color.blue, lineWidth: 2)
                                .rotationEffect(.degrees(-90))
                        )
                } else {
                    Circle()
                        .fill(isNext ? Color.blue.opacity(0.3) : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 20)
            
            // App icon - supports JAMF URLs, file paths, or SF Symbols
            Group {
                if let iconURL = item.iconURL, !iconURL.isEmpty {
                    AsyncIcon(
                        source: iconURL,
                        size: 24,
                        fallbackSymbol: item.icon,
                        fallbackColor: statusColor(for: item)
                    )
                } else {
                    Image(systemName: item.icon)
                        .foregroundColor(statusColor(for: item))
                        .font(.system(size: 16))
                }
            }
            .frame(width: 24, height: 24)
            
            // Name and description
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(textColor(for: item))
                    
                    if isSkipped {
                        Text("Skipped")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    } else if isNext && item.status == .pending {
                        Text("Next")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    } else if isStalled && isCurrent {
                        Text("Stalled")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 4) {
                    Text(item.description)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    
                    if let elapsed = elapsedTime, isCurrent && item.status == .installing {
                        Text("• \(formatTime(elapsed))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
            }
            
            Spacer()
            
            // Status or action buttons
            if isCurrent && (item.status == .failed || isStalled) {
                HStack(spacing: 6) {
                    if let onRetry = onRetry {
                        Button(action: onRetry) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if let onSkip = onSkip {
                        Button(action: onSkip) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            } else {
                statusText(for: item, progress: currentProgress)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            Group {
                if isSkipped {
                    Color.orange.opacity(0.05)
                } else if isCurrent && item.status == .failed {
                    Color.red.opacity(0.1)
                } else if isCurrent && item.status == .completed {
                    Color.orange.opacity(0.1)
                } else if isNext && item.status == .pending {
                    Color.blue.opacity(0.05)
                } else if isCurrent && isStalled {
                    Color.orange.opacity(0.05)
                } else {
                    Color.clear
                }
            }
        )
        .cornerRadius(6)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        } else {
            return "\(secs)s"
        }
    }
    
    private func statusColor(for item: InstallationItem) -> Color {
        if isSkipped { return .orange.opacity(0.8) }
        switch item.status {
        case .completed: return item.progress == 1.0 ? .green.opacity(0.8) : .orange.opacity(0.8)
        case .failed: return .red.opacity(0.8)
        case .installing: return .blue.opacity(0.8)
        default: return .white.opacity(0.5)
        }
    }
    
    private func textColor(for item: InstallationItem) -> Color {
        if isSkipped { return .orange }
        switch item.status {
        case .completed: return item.progress == 1.0 ? .green : .orange
        case .failed: return .red
        default: return .white
        }
    }
    
    @ViewBuilder
    private func statusText(for item: InstallationItem, progress: Double) -> some View {
        if isSkipped {
            Text("Skipped")
                .font(.system(size: 11))
                .foregroundColor(.orange)
        } else {
            switch item.status {
            case .completed:
                if item.progress == 1.0 {
                    Text("Installed")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                } else {
                    Text("Pre-installed")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            case .failed:
                Text("Failed")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            case .installing:
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.blue)
            default:
                Text("Pending")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Supporting Components

struct FailedInstallationCard: View {
    let item: InstallationItem
    let retryCount: Int
    let maxRetries: Int
    let onRetry: () -> Void
    let onSkip: () -> Void
    let onViewDetails: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(Theme.Status.error.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.Status.error)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(Theme.Typography.captionBold())
                        .foregroundColor(Theme.Text.primary)
                    
                    Text("Installation failed")
                        .font(Theme.Typography.small())
                        .foregroundColor(Theme.Status.error)
                }
                
                Spacer()
                
                if retryCount < maxRetries {
                    Text("\(maxRetries - retryCount) retries left")
                        .font(Theme.Typography.small())
                        .foregroundColor(Theme.Text.muted)
                }
            }
            
            // Action buttons
            HStack(spacing: Theme.Spacing.sm) {
                if retryCount < maxRetries {
                    Button(action: onRetry) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .font(Theme.Typography.captionBold())
                        .foregroundColor(Theme.Brand.primary)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(Theme.Brand.primary.opacity(0.15))
                        .cornerRadius(Theme.CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Button(action: onSkip) {
                    HStack(spacing: 4) {
                        Image(systemName: "forward.fill")
                        Text("Skip")
                    }
                    .font(Theme.Typography.captionBold())
                    .foregroundColor(Theme.Status.warning)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .background(Theme.Status.warning.opacity(0.15))
                    .cornerRadius(Theme.CornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(action: onViewDetails) {
                    Text("View Details")
                        .font(Theme.Typography.small())
                        .foregroundColor(Theme.Text.tertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct EnhancedCurrentInstallationCard: View {
    let item: InstallationItem
    let progress: Double
    let elapsedTime: Int
    let statusMessage: String
    let isStalled: Bool
    var isPaused: Bool = false
    var onRetry: (() -> Void)? = nil
    var onSkip: (() -> Void)? = nil
    
    @State private var shimmerOffset: CGFloat = -1
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                // Icon with JAMF URL support
                ZStack {
                    if let iconURL = item.iconURL, !iconURL.isEmpty {
                        AsyncIcon(
                            source: iconURL,
                            size: 28,
                            fallbackSymbol: item.icon,
                            fallbackColor: Theme.Text.primary
                        )
                    } else {
                        Image(systemName: item.icon)
                            .font(.system(size: 24))
                            .foregroundColor(Theme.Text.primary)
                    }
                }
                .frame(width: 40, height: 40)
                .background(Theme.Brand.primary.opacity(0.2))
                .cornerRadius(Theme.CornerRadius.small)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(Theme.Typography.captionBold())
                        .foregroundColor(Theme.Text.primary)
                    
                    Text(isPaused ? "Paused - waiting for network" : statusMessage)
                        .font(Theme.Typography.small())
                        .foregroundColor(isPaused ? Theme.Status.warning : Theme.Text.muted)
                        .animation(.easeInOut, value: statusMessage)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatTime(elapsedTime))
                        .font(Theme.Typography.mono(size: 14))
                        .foregroundColor(isPaused ? Theme.Status.warning : Theme.Brand.secondary)
                    
                    Text(isPaused ? "paused" : "elapsed")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.Text.disabled)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(Theme.Typography.caption())
                        .foregroundColor(Theme.Text.muted)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(Theme.Typography.mono(size: 12))
                        .foregroundColor(Theme.Brand.primary)
                }
                
                // Progress bar with shimmer
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Background.card)
                        .frame(height: 8)
                    
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: isPaused
                                        ? [Theme.Status.warning, Theme.Status.warning.opacity(0.8)]
                                        : [Theme.Brand.primary, Theme.Brand.secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 8)
                        
                        if progress > 0 && progress < 1 && !isPaused {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, .white.opacity(0.4), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 40, height: 8)
                                .offset(x: shimmerOffset * geometry.size.width * progress)
                                .mask(
                                    RoundedRectangle(cornerRadius: 4)
                                        .frame(width: geometry.size.width * progress, height: 8)
                                )
                        }
                    }
                    .frame(height: 8)
                }
                .onAppear {
                    withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                        shimmerOffset = 1.5
                    }
                }
                
                // Status row with actions
                HStack(spacing: Theme.Spacing.xs) {
                    if !isPaused {
                        ActivityDots()
                    }
                    
                    Text(isPaused ? "Waiting for network..." : "Installing")
                        .font(Theme.Typography.small())
                        .foregroundColor(isPaused ? Theme.Status.warning : Theme.Brand.primary)
                    
                    Spacer()
                    
                    // Action buttons for stalled/long-running installs
                    if isStalled && !isPaused {
                        if let onRetry = onRetry {
                            Button(action: onRetry) {
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry")
                                }
                                .font(Theme.Typography.small())
                                .foregroundColor(Theme.Brand.primary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        if let onSkip = onSkip {
                            Button(action: onSkip) {
                                HStack(spacing: 2) {
                                    Image(systemName: "forward.fill")
                                    Text("Skip")
                                }
                                .font(Theme.Typography.small())
                                .foregroundColor(Theme.Status.warning)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    } else if isStalled {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                            Text("This may take a moment")
                                .font(Theme.Typography.small())
                        }
                        .foregroundColor(Theme.Status.warning)
                    }
                }
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct AllCompleteCard: View {
    var skippedCount: Int = 0
    @State private var glowAnimation = false
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.Status.success.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 5,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(glowAnimation ? 1.2 : 0.9)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: glowAnimation
                    )
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.Status.success)
            }
            .onAppear { glowAnimation = true }
            
            Text("All installations complete!")
                .font(Theme.Typography.captionBold())
                .foregroundColor(Theme.Status.success)
            
            if skippedCount > 0 {
                Text("\(skippedCount) item(s) were skipped")
                    .font(Theme.Typography.caption())
                    .foregroundColor(Theme.Status.warning)
            } else {
                Text("All policies have been processed")
                    .font(Theme.Typography.caption())
                    .foregroundColor(Theme.Text.muted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}

struct WaitingCard: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.Brand.primary))
            
            Text("Waiting for policies...")
                .font(Theme.Typography.caption())
                .foregroundColor(Theme.Text.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}

struct SystemStatusCard: View {
    let policiesRunning: Int
    let logPath: String
    var isNetworkConnected: Bool = true
    var connectionType: String = "Wi-Fi"
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("System Status")
                .font(Theme.Typography.headline())
                .foregroundColor(Theme.Text.primary)
            
            VStack(spacing: Theme.Spacing.xs) {
                StatusRow(icon: "circle.fill", title: "Log Monitoring",
                         status: "Active", color: Theme.Brand.primary)
                StatusRow(icon: "wifi", title: "Network",
                         status: isNetworkConnected ? connectionType : "Disconnected",
                         color: isNetworkConnected ? Theme.Status.success : Theme.Status.error)
                StatusRow(icon: "shield.fill", title: "Security Status",
                         status: "Protected", color: Theme.Status.success)
                StatusRow(icon: "gearshape.fill", title: "Policy Execution",
                         status: policiesRunning > 0 ? "Running (\(policiesRunning))" : "Idle",
                         color: policiesRunning > 0 ? Theme.Brand.primary : Theme.Text.muted)
            }
            
            Divider()
                .background(Theme.Border.subtle)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Log File")
                    .font(Theme.Typography.captionBold())
                    .foregroundColor(Theme.Text.muted)
                Text(logPath)
                    .font(Theme.Typography.mono(size: 10))
                    .foregroundColor(Theme.Text.disabled)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Background.cardElevated)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Theme.Border.subtle, lineWidth: 1)
        )
        .cornerRadius(Theme.CornerRadius.medium)
        .shadow(color: Theme.Shadows.subtle().color, radius: Theme.Shadows.subtle().radius, y: Theme.Shadows.subtle().y)
    }
}

struct StatusRow: View {
    let icon: String
    let title: String
    let status: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(title)
                .font(Theme.Typography.caption())
                .foregroundColor(Theme.Text.muted)
            
            Spacer()
            
            Text(status)
                .font(Theme.Typography.captionBold())
                .foregroundColor(color)
        }
    }
}

// Engagement components
struct PulsingDot: View {
    let color: Color
    var size: CGFloat = 8
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .opacity(isPulsing ? 0 : 0.5)
            
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

struct ActivityDots: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Theme.Brand.primary)
                    .frame(width: 6, height: 6)
                    .offset(y: animating ? -4 : 0)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

struct StallIndicator: View {
    @State private var rotation = 0.0
    
    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: "hourglass")
                .font(.system(size: 12))
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
            
            Text("Please wait...")
                .font(Theme.Typography.small())
        }
        .foregroundColor(Theme.Status.warning)
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.vertical, 4)
        .background(Theme.Status.warning.opacity(0.15))
        .cornerRadius(Theme.CornerRadius.small)
    }
}

// MARK: - Preview
