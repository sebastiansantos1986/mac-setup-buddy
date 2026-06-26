//
//  PersistentBlurWindow.swift
//  Mac Setup Buddy
//
//  Created by Claude - December 2025
//
//  Manages a persistent fullscreen blur background that stays open
//  across multiple window invocations, similar to Apple's Setup Assistant.
//
//  Usage from bash:
//    # Start blur at beginning of setup
//    ./Mac Setup Buddy\ Setup --blur-start
//
//    # Show screens (blur already running, windows appear on top)
//    ./Mac Setup Buddy\ Setup --screen welcome --blur-mode persistent
//    ./Mac Setup Buddy\ Setup --screen email --blur-mode persistent
//    ./Mac Setup Buddy\ Setup --screen progress --blur-mode persistent
//
//    # Stop blur at end of setup
//    ./Mac Setup Buddy\ Setup --blur-stop
//

import SwiftUI
import AppKit

// MARK: - Persistent Blur Manager (Singleton)

class PersistentBlurManager {
    static let shared = PersistentBlurManager()
    
    private var blurWindows: [NSWindow] = []
    private var pidFile: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("macsetupbuddy_blur.pid")
    }
    private var isRunning = false
    
    private init() {}
    
    // MARK: - Public API
    
    /// Start the persistent blur on all screens
    func start() {
        guard !isRunning else {
            print("Blur already running")
            return
        }
        
        // Create blur windows for all screens
        for screen in NSScreen.screens {
            let blurWindow = createBlurWindow(for: screen)
            blurWindows.append(blurWindow)
        }
        
        // Write PID file so other invocations know blur is running
        writePIDFile()
        isRunning = true
        
        // Fade in all blur windows
        for window in blurWindows {
            window.alphaValue = 0
            window.orderFront(nil)
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.4
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 1
            }
        }
        
        // Listen for screen configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        print("Persistent blur started")
    }
    
    /// Stop the persistent blur
    func stop(animated: Bool = true) {
        guard isRunning else { return }
        
        if animated {
            // Fade out
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                for window in blurWindows {
                    window.animator().alphaValue = 0
                }
            }, completionHandler: { [weak self] in
                self?.closeAllBlurWindows()
            })
        } else {
            closeAllBlurWindows()
        }
    }
    
    /// Check if persistent blur is currently active (from any process)
    func isBlurActive() -> Bool {
        // Check if PID file exists and process is running
        guard FileManager.default.fileExists(atPath: pidFile.path) else {
            return false
        }
        
        // Read PID and check if process exists
        if let pidString = try? String(contentsOf: pidFile, encoding: .utf8),
           let pid = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines)) {
            // Check if process is running
            return kill(pid, 0) == 0
        }
        
        return false
    }
    
    /// Send signal to running blur process to stop
    func signalStop() {
        guard let pidString = try? String(contentsOf: pidFile, encoding: .utf8),
              let pid = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            print("No blur process found")
            return
        }
        
        // Send SIGTERM to the blur process
        kill(pid, SIGTERM)
        print("Sent stop signal to blur process \(pid)")
        
        // Clean up PID file
        try? FileManager.default.removeItem(at: pidFile)
    }
    
    // MARK: - Private Methods
    
    private func createBlurWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Configure window
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false  // Blocks clicks
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.hasShadow = false
        
        // Create blur view
        let blurView = NSVisualEffectView(frame: screen.frame)
        blurView.blendingMode = .behindWindow
        blurView.material = .fullScreenUI
        blurView.state = .active
        blurView.wantsLayer = true
        
        // Add slight darkening overlay
        let overlayView = NSView(frame: screen.frame)
        overlayView.wantsLayer = true
        overlayView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.15).cgColor
        blurView.addSubview(overlayView)
        
        window.contentView = blurView
        
        return window
    }
    
    private func closeAllBlurWindows() {
        for window in blurWindows {
            window.close()
        }
        blurWindows.removeAll()
        isRunning = false
        
        // Remove PID file
        try? FileManager.default.removeItem(at: pidFile)
        
        NotificationCenter.default.removeObserver(self)
        print("Persistent blur stopped")
    }
    
    private func writePIDFile() {
        let pid = ProcessInfo.processInfo.processIdentifier
        try? String(pid).write(to: pidFile, atomically: true, encoding: .utf8)
    }
    
    @objc private func screensChanged() {
        // Recreate blur windows for new screen configuration
        closeAllBlurWindows()
        
        for screen in NSScreen.screens {
            let blurWindow = createBlurWindow(for: screen)
            blurWindow.alphaValue = 1
            blurWindow.orderFront(nil)
            blurWindows.append(blurWindow)
        }
        
        isRunning = true
        writePIDFile()
    }
}

// MARK: - Blur-Only App Delegate

/// A minimal app delegate that just runs the blur and waits for termination
class BlurOnlyAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start the blur
        PersistentBlurManager.shared.start()
        
        // Set up signal handler for graceful shutdown
        signal(SIGTERM) { _ in
            DispatchQueue.main.async {
                PersistentBlurManager.shared.stop(animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        
        signal(SIGINT) { _ in
            DispatchQueue.main.async {
                PersistentBlurManager.shared.stop(animated: false)
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        PersistentBlurManager.shared.stop(animated: false)
    }
}

// MARK: - Content Window Helper

/// Creates content windows that appear ABOVE the persistent blur
class ContentWindowController {
    
    /// Create a window for content that floats above the blur
    static func createContentWindow(
        size: CGSize,
        content: some View,
        hideControls: Bool = true
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Configure to float above blur
        window.level = .modalPanel  // Above .floating (where blur is)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.hasShadow = true
        
        // Hide controls if requested
        if hideControls {
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        }
        
        // Wrap content with glass background
        let wrappedContent = content
            .frame(width: size.width, height: size.height)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        
        window.contentView = NSHostingView(rootView: wrappedContent)
        
        return window
    }
    
    /// Show window with fade-in animation
    static func showWithAnimation(_ window: NSWindow) {
        window.center()
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }
    
    /// Hide window with fade-out animation
    static func hideWithAnimation(_ window: NSWindow, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.close()
            completion?()
        })
    }
}

// MARK: - SwiftUI View Extension for Persistent Blur Mode

extension View {
    /// Apply styling for persistent blur mode (glass card appearance)
    func persistentBlurStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
    }
}
