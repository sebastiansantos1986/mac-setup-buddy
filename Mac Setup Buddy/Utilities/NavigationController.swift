//
//  NavigationController.swift
//  Mac Setup Buddy
//
//  Enables persistent blur while switching between views
//  Updated: December 2025 - Added networkCheck, credentials, completion cases
//

import SwiftUI
import Combine

// Navigation state manager
class NavigationState: ObservableObject {
    @Published var currentView: ViewState = .welcome
    @Published var config: CommandLineConfig = CommandLineConfig()
    @Published var shouldExit: Bool = false
}

// Main container view that keeps blur persistent
struct NavigationContainer: View {
    @StateObject private var navState = NavigationState()
    let initialConfig: CommandLineConfig
    let initialScreen: ViewState
    
    init(config: CommandLineConfig, screen: ViewState) {
        self.initialConfig = config
        self.initialScreen = screen
    }
    
    var body: some View {
        ZStack {
            // Content that changes while blur stays
            Group {
                switch navState.currentView {
                case .welcome:
                    WelcomeView(config: navState.config, onContinue: {
                        // Navigate to next screen
                        withAnimation(.easeInOut(duration: 0.3)) {
                            navState.currentView = .emailInput
                        }
                    })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    
                case .emailInput:
                    EmailInputView(config: navState.config, completion: { email in
                        print("Captured email: \(email)")
                        navState.config.email = email
                        // Navigate to next screen (network check if enabled, otherwise progress)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if navState.config.enableNetworkCheck {
                                navState.currentView = .networkCheck
                            } else {
                                navState.currentView = .progress
                            }
                        }
                    })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    
                case .networkCheck:
                    // Network check screen - placeholder using notification
                    NotificationView(
                        title: "Network Check",
                        message: "Verifying connectivity to required services...",
                        icon: "wifi",
                        buttons: ["Continue"],
                        onAction: { _ in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                navState.currentView = .progress
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    
                case .credentials:
                    // Credentials/SSO screen - placeholder using notification
                    NotificationView(
                        title: "Enterprise Sign-In",
                        message: "Configure single sign-on for enterprise applications.",
                        icon: "person.badge.key.fill",
                        buttons: ["Continue"],
                        onAction: { _ in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                navState.currentView = .progress
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    
                case .credentialLogin:
                    // Fullscreen JAMF Connect-style login
                    CredentialLoginView(
                        config: navState.config,
                        onLogin: { username, password in
                            print("Captured username: \(username)")
                            navState.config.email = username
                            withAnimation(.easeInOut(duration: 0.3)) {
                                navState.currentView = .progress
                            }
                        },
                        onCancel: {
                            NSApplication.shared.terminate(nil)
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    
                case .progress:
                    InstallationProgressView(config: navState.config, onComplete: {
                        // Navigate to completion
                        withAnimation(.easeInOut(duration: 0.3)) {
                            navState.currentView = .verification
                        }
                    })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    
                case .aadProgress:
                    AADProgressView(config: navState.config, completion: { _ in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            navState.currentView = .verification
                        }
                    })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    
                case .verification:
                    CompletionView(config: navState.config, onExit: {
                        NSApplication.shared.terminate(nil)
                    })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    
                case .completion:
                    CompletionView(config: navState.config, onExit: {
                        NSApplication.shared.terminate(nil)
                    })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    
                case .success:
                    SuccessView(email: navState.config.email ?? "user@company.com")
                        .transition(.opacity)
                    
                case .notification:
                    NotificationView(
                        title: navState.config.notificationTitle ?? "Notice",
                        message: navState.config.notificationMessage ?? "",
                        icon: navState.config.notificationIcon ?? "info.circle.fill",
                        buttons: navState.config.notificationButtons ?? ["OK"],
                        onAction: { index in
                            NSApplication.shared.terminate(nil)
                        }
                    )
                    .transition(.opacity)
                    
                case .error:
                    CompletionView(config: navState.config, onExit: {
                        NSApplication.shared.terminate(nil)
                    })
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: navState.currentView)
        }
        .frame(width: navState.config.windowWidth, height: navState.config.windowHeight)
        .onAppear {
            navState.config = initialConfig
            navState.currentView = initialScreen
        }
    }
}

// Add navigation buttons overlay for testing
struct NavigationDebugOverlay: View {
    @ObservedObject var navState: NavigationState
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                // Debug navigation buttons
                HStack(spacing: 10) {
                    Button("Welcome") {
                        withAnimation {
                            navState.currentView = .welcome
                        }
                    }
                    Button("Email") {
                        withAnimation {
                            navState.currentView = .emailInput
                        }
                    }
                    Button("Progress") {
                        withAnimation {
                            navState.currentView = .progress
                        }
                    }
                    Button("AAD") {
                        withAnimation {
                            navState.currentView = .aadProgress
                        }
                    }
                    Button("Complete") {
                        withAnimation {
                            navState.currentView = .verification
                        }
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
                .padding()
            }
            Spacer()
        }
    }
}
