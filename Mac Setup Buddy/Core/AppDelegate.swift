//  AppDelegate.swift
//  Mac Setup Buddy
//
//  Created by Sebastian Santos on October 4, 2025
//  Updated: December 2025 - Added persistent blur mode
//
//  PERSISTENT BLUR MODE:
//  Instead of each screen opening/closing its own blur, you can:
//  1. Start blur once: ./Mac Setup Buddy\ Setup --blur-start
//  2. Show screens (blur stays): ./Mac Setup Buddy\ Setup --screen welcome --blur-mode persistent
//  3. Stop blur at end: ./Mac Setup Buddy\ Setup --blur-stop

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private var overlayWindow: NSWindow?
    private var overlayWindows: [NSWindow] = []  // For multi-screen support
    private var isPersistentFlow: Bool = false
    
    // Shared state for persistent overlay management
    private static var sharedOverlayWindows: [NSWindow] = []
    private static var flowModeActive: Bool = false
    
    // PID file for persistent blur process
    private let pidFilePath = "/tmp/macsetupbuddy_blur.pid"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)

        // Parse CLI arguments
        let parsed = CommandLineParser.parseArguments()
        
        // MARK: - Handle Persistent Blur Actions FIRST
        switch parsed.config.persistentBlurAction {
        case .start:
            // Just start blur and keep running
            startPersistentBlurMode(style: parsed.config.backgroundStyle)
            return  // Don't show any window, just blur
            
        case .stop:
            // Signal existing blur process to stop
            stopPersistentBlur()
            NSApplication.shared.terminate(nil)
            return
            
        case .showOnly, .none:
            // Continue with normal window display
            break
        }
        
        // Set flow mode flag
        isPersistentFlow = parsed.config.enableFlow || parsed.config.blurMode == .persistent
        
        // MARK: - Handle Blur Mode
        if parsed.config.blurMode == .persistent {
            // Persistent mode: Don't create blur, just show content window above existing blur
            print("Persistent blur mode: Content window only (blur should be running)")
        } else if isPersistentFlow {
            // Legacy flow mode
            if AppDelegate.sharedOverlayWindows.isEmpty {
                createPersistentOverlay(style: parsed.config.backgroundStyle)
                AppDelegate.flowModeActive = true
            }
        }

        // Build the correct SwiftUI view based on arguments
        let contentView: AnyView = buildContentView(for: parsed.screen, config: parsed.config)

        // Create the SwiftUI hosting window
        createAndShowWindow(contentView: contentView, config: parsed.config)
    }
    
    // MARK: - Build Content View
    private func buildContentView(for screen: ViewState, config: CommandLineConfig) -> AnyView {
        if config.previewMode {
            return AnyView(
                PreviewModeView(config: config, onExit: {
                    self.closeWindowOnly()
                })
            )
        }

        switch screen {
        case .welcome:
            return AnyView(
                WelcomeView(config: config, onContinue: {
                    self.closeWindowOnly()
                })
            )

        case .emailInput:
            return AnyView(
                EmailInputView(config: config, completion: { email in
                    print("Captured email: \(email)")
                    self.closeWindowOnly()
                })
            )

        case .networkCheck:
            // NetworkCheckView not implemented yet - use notification as placeholder
            return AnyView(
                NotificationView(
                    title: config.title ?? "Network Check",
                    message: config.message ?? "Checking network connectivity...",
                    icon: "wifi",
                    buttons: ["Continue"],
                    onAction: { _ in
                        self.closeWindowOnly()
                    }
                )
            )
            
        case .credentials:
            // CredentialInputView not implemented yet - use notification as placeholder
            return AnyView(
                NotificationView(
                    title: config.title ?? "Enterprise Sign-In",
                    message: config.message ?? "SSO configuration",
                    icon: "person.badge.key.fill",
                    buttons: ["Continue"],
                    onAction: { _ in
                        self.closeWindowOnly()
                    }
                )
            )
            
        case .credentialLogin:
            // Fullscreen JAMF Connect-style login screen
            return AnyView(
                CredentialLoginView(
                    config: config,
                    onLogin: { username, password in
                        print("Captured username: \(username)")
                        // Password is not printed for security
                        self.closeWindowOnly()
                    },
                    onCancel: {
                        self.exitWithCode(1)
                    }
                )
            )

        case .progress:
            return AnyView(
                InstallationProgressView(config: config, onComplete: {
                    self.closeWindowOnly()
                })
            )
            
        case .aadProgress:
            return AnyView(
                AADProgressView(config: config, completion: { exitCode in
                    self.exitWithCode(exitCode.rawValue)
                })
            )
            
        case .success:
            return AnyView(SuccessView(email: config.email ?? "user@example.com"))
            
        case .notification:
            return AnyView(
                NotificationView(
                    title: config.notificationTitle ?? config.title ?? "Notice",
                    message: config.notificationMessage ?? config.message ?? "",
                    icon: config.notificationIcon ?? "info.circle.fill",
                    buttons: config.notificationButtons ?? ["OK"],
                    onAction: { buttonIndex in
                        self.exitWithCode(Int32(buttonIndex))
                    }
                )
            )
            
        case .completion, .verification:
            return AnyView(
                CompletionView(config: config, onExit: {
                    self.closeWindowOnly()
                })
            )
            
        case .error:
            return AnyView(
                ErrorRecoveryView(
                    error: .policyFailed(
                        name: config.title ?? "Setup Step",
                        reason: config.message ?? "An error occurred during setup."
                    ),
                    policyName: config.title,
                    diagnosticInfo: config.message ?? "No diagnostic details were provided.",
                    bannerImage: config.bannerImage,
                    onAction: { _ in
                        self.exitWithCode(1)
                    }
                )
            )
        }
    }
    
    // MARK: - Window Creation
    private func createAndShowWindow(contentView: AnyView, config: CommandLineConfig) {
        let hostingController = NSHostingController(rootView: contentView)
        
        var styleMask: NSWindow.StyleMask = [.titled, .resizable, .fullSizeContentView]
        if !config.hideWindowControls && !config.hideControls {
            styleMask.insert(.closable)
            styleMask.insert(.miniaturizable)
        }
        
        let window = NSWindow(contentViewController: hostingController)
        window.setContentSize(NSSize(width: config.windowWidth, height: config.windowHeight))
        window.styleMask = styleMask
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor.clear
        window.delegate = self
        
        // Hide traffic light buttons if requested
        if config.hideWindowControls || config.hideControls {
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        }
        
        // MARK: - Window Level Based on Blur Mode
        if config.blurMode == .persistent {
            // Persistent blur mode: Position above the blur (which is at .screenSaver)
            window.level = .screenSaver + 1
            print("Window level: screenSaver+1 (above persistent blur)")
        } else if isPersistentFlow {
            // Legacy flow mode
            window.level = .screenSaver + 1
            print("Flow mode: Window positioned above persistent overlay")
        } else {
            // Normal mode: Create per-window blur if needed
            window.level = .floating
            
            switch config.backgroundStyle {
            case .solid:
                addBackgroundOverlay(color: NSColor(red: 0.08, green: 0.12, blue: 0.20, alpha: 1.0), to: window)
            case .blur:
                addBlurBackground(to: window)
            case .transparent, .none:
                break
            }
        }
        
        // Center and show
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()

        self.window = window
    }
    
    // MARK: - Persistent Blur Mode (New)
    
    /// Start persistent blur and keep app running
    private func startPersistentBlurMode(style: BackgroundStyle) {
        print("Starting persistent blur mode...")
        
        // Write PID file
        let pid = ProcessInfo.processInfo.processIdentifier
        try? String(pid).write(toFile: pidFilePath, atomically: true, encoding: .utf8)
        
        // Default to blur if no style specified
        let effectiveStyle: BackgroundStyle = (style == .none) ? .blur : style
        
        // Create blur on ALL screens
        for screen in NSScreen.screens {
            let overlay = createBlurOverlayWindow(for: screen, style: effectiveStyle)
            overlay.orderFrontRegardless()
            overlayWindows.append(overlay)
        }
        
        print("Persistent blur started on \(overlayWindows.count) screen(s)")
        print("PID: \(pid) - waiting for termination signal...")
        
        // Set up signal handlers for graceful shutdown
        signal(SIGTERM) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .blurStopRequested, object: nil)
            }
        }
        
        signal(SIGINT) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .blurStopRequested, object: nil)
            }
        }
        
        // Listen for stop notification
        NotificationCenter.default.addObserver(
            forName: .blurStopRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cleanupAndExit()
        }
        
        // Listen for screen configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    /// Create a blur overlay window for a specific screen
    private func createBlurOverlayWindow(for screen: NSScreen, style: BackgroundStyle) -> NSWindow {
        let overlay = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        switch style {
        case .blur:
            let blurView = NSVisualEffectView(frame: NSRect(origin: .zero, size: screen.frame.size))
            blurView.blendingMode = .behindWindow
            blurView.material = .fullScreenUI
            blurView.state = .active
            blurView.wantsLayer = true
            
            // Add slight darkening
            let darkOverlay = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            darkOverlay.wantsLayer = true
            darkOverlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.15).cgColor
            blurView.addSubview(darkOverlay)
            
            overlay.contentView = blurView
            overlay.isOpaque = false
            overlay.backgroundColor = .clear
            
        case .solid:
            overlay.backgroundColor = NSColor(red: 0.08, green: 0.12, blue: 0.20, alpha: 1.0)
            overlay.isOpaque = true
            
        default:
            overlay.backgroundColor = .clear
            overlay.isOpaque = false
        }
        
        // FIXED: Use screenSaver level so blur is visible above desktop
        overlay.level = .screenSaver
        overlay.ignoresMouseEvents = false  // Block clicks on desktop
        overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        overlay.hasShadow = false
        
        return overlay
    }
    
    /// Stop the persistent blur process
    private func stopPersistentBlur() {
        print("Stopping persistent blur...")
        
        // Read PID and send signal
        if let pidString = try? String(contentsOfFile: pidFilePath, encoding: .utf8),
           let pid = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines)) {
            print("Sending SIGTERM to blur process \(pid)")
            kill(pid, SIGTERM)
        }
        
        // Clean up PID file
        try? FileManager.default.removeItem(atPath: pidFilePath)
    }
    
    @objc private func screensChanged() {
        // Recreate blur windows for new screen configuration
        for window in overlayWindows {
            window.close()
        }
        overlayWindows.removeAll()
        
        let style: BackgroundStyle = .blur  // Default to blur
        for screen in NSScreen.screens {
            let overlay = createBlurOverlayWindow(for: screen, style: style)
            overlay.orderFrontRegardless()
            overlayWindows.append(overlay)
        }
    }
    
    private func cleanupAndExit() {
        print("Cleaning up persistent blur...")
        
        // Fade out all overlays
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            for window in overlayWindows {
                window.animator().alphaValue = 0
            }
        }, completionHandler: { [weak self] in
            for window in self?.overlayWindows ?? [] {
                window.close()
            }
            self?.overlayWindows.removeAll()
            
            // Remove PID file
            try? FileManager.default.removeItem(atPath: self?.pidFilePath ?? "")
            
            NSApplication.shared.terminate(nil)
        })
    }
    
    // MARK: - Exit Helpers
    
    /// Close window only (keep blur if persistent)
    private func closeWindowOnly() {
        if isPersistentFlow || CommandLineParser.parseArguments().config.blurMode == .persistent {
            // Persistent mode: just close window, exit 0
            window?.close()
            exit(0)
        } else {
            // Normal mode: cleanup everything
            AppDelegate.cleanupBeforeExit()
            NSApplication.shared.terminate(nil)
        }
    }
    
    private func exitWithCode(_ code: Int32) {
        if isPersistentFlow || CommandLineParser.parseArguments().config.blurMode == .persistent {
            window?.close()
            exit(code)
        } else {
            AppDelegate.cleanupBeforeExit()
            exit(code)
        }
    }
    
    // MARK: - NSApplicationDelegate
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't auto-terminate in persistent blur mode
        return overlayWindows.isEmpty
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        cleanupOverlay()
        AppDelegate.cleanupPersistentOverlay()
        try? FileManager.default.removeItem(atPath: pidFilePath)
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        cleanupOverlay()
        AppDelegate.cleanupPersistentOverlay()
        return .terminateNow
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        if !isPersistentFlow && CommandLineParser.parseArguments().config.blurMode != .persistent {
            cleanupOverlay()
        }
    }
    
    // MARK: - Legacy Overlay Methods (for backward compatibility)
    
    private func createPersistentOverlay(style: BackgroundStyle) {
        guard AppDelegate.sharedOverlayWindows.isEmpty else { return }
        guard let screen = NSScreen.main else { return }
        
        print("Creating legacy persistent overlay")
        
        let overlay = createBlurOverlayWindow(for: screen, style: style)
        overlay.level = .screenSaver
        overlay.orderFrontRegardless()
        
        AppDelegate.sharedOverlayWindows.append(overlay)
        self.overlayWindow = overlay
    }
    
    private func cleanupOverlay() {
        if let overlay = overlayWindow {
            overlay.orderOut(nil)
            overlay.close()
            overlayWindow = nil
        }
    }
    
    static func cleanupPersistentOverlay() {
        for overlay in sharedOverlayWindows {
            overlay.orderOut(nil)
            overlay.close()
        }
        sharedOverlayWindows.removeAll()
        flowModeActive = false
    }
    
    static func cleanupBeforeExit() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.cleanupOverlay()
        }
        cleanupPersistentOverlay()
    }

    // MARK: - Per-Window Background (Legacy)
    
    private func addBackgroundOverlay(color: NSColor, to window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        
        let overlay = NSWindow(contentRect: screen.frame,
                               styleMask: .borderless,
                               backing: .buffered,
                               defer: false)
        overlay.backgroundColor = color
        overlay.isOpaque = true
        overlay.level = .screenSaver
        overlay.ignoresMouseEvents = true
        overlay.orderFrontRegardless()
        
        window.level = .screenSaver + 1
        window.orderFrontRegardless()

        self.overlayWindow = overlay
    }

    private func addBlurBackground(to window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        
        let blurView = NSVisualEffectView(frame: screen.frame)
        blurView.blendingMode = .behindWindow
        blurView.material = .hudWindow
        blurView.state = .active
        
        let overlay = NSWindow(contentRect: screen.frame,
                               styleMask: .borderless,
                               backing: .buffered,
                               defer: false)
        overlay.contentView = blurView
        overlay.level = .screenSaver
        overlay.isOpaque = false
        overlay.orderFrontRegardless()
        
        window.level = .screenSaver + 1
        window.orderFrontRegardless()

        self.overlayWindow = overlay
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let blurStopRequested = Notification.Name("blurStopRequested")
}
