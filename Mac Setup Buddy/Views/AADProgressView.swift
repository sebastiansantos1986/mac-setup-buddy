//
//  AADProgressView.swift
//  Mac Setup Buddy
//
//  Created by Sebastian Santos on October 4, 2025
//
//  Updated to use centralized Theme system
//

import SwiftUI
import Foundation

struct AADProgressView: View {
    let config: CommandLineConfig
    let completion: (ExitCode) -> Void

    @State private var isAnimating: Bool = false
    @State private var progressMessage: String = ""
    @State private var simulationTimer: Timer?
    @State private var pulseAnimation = false
    @State private var rotationAngle = 0.0
    @State private var currentStep = 0
    @State private var wavePhase = 0.0

    var body: some View {
        ZStack {
            // Dynamic gradient background - using Theme
            LinearGradient(
                gradient: Gradient(colors: [
                    Theme.Background.tertiary,
                    Color(red: 0.08, green: 0.12, blue: 0.22),
                    Color(red: 0.12, green: 0.08, blue: 0.2)
                ]),
                startPoint: pulseAnimation ? .topLeading : .bottomTrailing,
                endPoint: pulseAnimation ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }

            // Animated wave background
            GeometryReader { geometry in
                ForEach(0..<5, id: \.self) { index in
                    Wave(
                        amplitude: 30,
                        frequency: 0.5,
                        phase: wavePhase + Double(index) * 0.5,
                        color: Theme.Brand.primary.opacity(0.1 - Double(index) * 0.02)
                    )
                    .offset(y: CGFloat(index * 50))
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    wavePhase = .pi * 2
                }
            }

            VStack(spacing: 0) {
                // Banner if provided
                if config.bannerImage != nil {
                    BannerView(
                        imagePath: config.bannerImage,
                        height: 190,
                        contentMode: .fill
                    )
                    .overlay(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Cover strip to hide any gaps
                    Rectangle()
                        .fill(Theme.Background.tertiary)
                        .frame(height: 2)
                        .offset(y: -1)
                }

                // Main content
                VStack(spacing: Theme.Spacing.sm) {
                    // Enhanced animated icon
                    ZStack {
                        // Multiple glow layers for depth
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Theme.Brand.primary.opacity(0.3 - Double(index) * 0.1),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 5,
                                        endRadius: 40 + Double(index) * 20
                                    )
                                )
                                .frame(width: 100 + CGFloat(index) * 30,
                                       height: 100 + CGFloat(index) * 30)
                                .scaleEffect(pulseAnimation ? 1.1 : 0.9)
                                .animation(
                                    .easeInOut(duration: 2 + Double(index) * 0.5)
                                    .repeatForever(autoreverses: true),
                                    value: pulseAnimation
                                )
                        }

                        // Main icon circle
                        Circle()
                            .fill(Theme.Gradients.primaryButton)
                            .frame(width: 85, height: 85)
                            .shadow(
                                color: Theme.Brand.primary.opacity(0.6),
                                radius: 20,
                                y: 5
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.4), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1
                                    )
                            )

                        Image(systemName: config.aadIcon ?? "magnifyingglass")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(Theme.Text.primary)
                            .rotationEffect(.degrees(rotationAngle))
                            .onAppear {
                                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                                    rotationAngle = 360
                                }
                            }
                    }
                    .padding(.top, Theme.Spacing.sm)

                    // Glass morphism card for content
                    VStack(spacing: Theme.Spacing.xl) {
                        Text(config.message ?? "Looking up your profile in Azure Active Directory...")
                            .font(Theme.Typography.rounded(size: 17, weight: .semibold))
                            .foregroundColor(Theme.Text.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.xl)

                        // Enhanced progress indicator
                        VStack(spacing: Theme.Spacing.lg) {
                            if config.showAADProgress {
                                // Custom animated dots with wave effect
                                HStack(spacing: Theme.Spacing.sm) {
                                    ForEach(0..<4, id: \.self) { index in
                                        Circle()
                                            .fill(Theme.Gradients.primaryButton)
                                            .frame(width: 12, height: 12)
                                            .scaleEffect(isAnimating ? 1.0 : 0.5)
                                            .offset(y: isAnimating ? -10 : 0)
                                            .animation(
                                                Animation.easeInOut(duration: 0.6)
                                                    .repeatForever()
                                                    .delay(Double(index) * 0.15),
                                                value: isAnimating
                                            )
                                    }
                                }

                                // Progress bar
                                let progress = Double(currentStep) / 7.0
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        // Background track
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Theme.Background.card)
                                            .frame(height: 8)

                                        // Progress fill
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Theme.Gradients.primaryButton)
                                            .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                                            .animation(Theme.Animation.smooth, value: progress)

                                        // Glow effect
                                        Circle()
                                            .fill(
                                                RadialGradient(
                                                    colors: [Theme.Brand.secondary, .clear],
                                                    center: .center,
                                                    startRadius: 2,
                                                    endRadius: 15
                                                )
                                            )
                                            .frame(width: 20, height: 20)
                                            .offset(x: geometry.size.width * CGFloat(progress) - 10)
                                            .blur(radius: 3)
                                    }
                                }
                                .frame(height: 8)
                            }

                            // Progress message with typing effect
                            Text(progressMessage)
                                .font(Theme.Typography.mono(size: 14))
                                .foregroundColor(Theme.Brand.secondary.opacity(0.9))
                                .padding(.horizontal, Theme.Spacing.lg)
                                .padding(.vertical, Theme.Spacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                        .fill(Color.black.opacity(0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                                .stroke(Theme.Brand.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .animation(Theme.Animation.smooth, value: progressMessage)
                        }
                    }
                    .padding(36)
                    .glassCard(cornerRadius: Theme.CornerRadius.xlarge)
                    .shadow(color: Color.black.opacity(0.3), radius: 10, y: 10)

                    Spacer()

                    // Cancel button
                    Button(action: {
                        simulationTimer?.invalidate()
                        completion(.failure)
                    }) {
                        Text(config.aadCancelButtonText ?? "Cancel")
                            .font(Theme.Typography.rounded(size: 15, weight: .semibold))
                            .foregroundColor(Theme.Text.secondary)
                            .padding(.horizontal, Theme.Spacing.xl)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(
                                ZStack {
                                    Capsule()
                                        .fill(Theme.Background.card)

                                    Capsule()
                                        .stroke(Theme.Border.highlighted, lineWidth: 1)
                                }
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.bottom, Theme.Spacing.xl)
                .background(Theme.Background.tertiary)
            }
        }
        .frame(width: config.windowWidth, height: config.windowHeight)
        .onAppear {
            setupProgress()
            startAnimation()
            if config.aadAutoProgress ?? true {
                startProgressSimulation()
            }
        }
        .onDisappear {
            simulationTimer?.invalidate()
            simulationTimer = nil
        }
    }

    private func setupProgress() {
        if let customMessage = config.aadProgressMessage {
            progressMessage = customMessage
        } else if let email = config.email {
            progressMessage = "Searching: \(email)"
        } else {
            progressMessage = "Initializing search..."
        }
    }

    private func startAnimation() {
        isAnimating = true
    }

    private func startProgressSimulation() {
        let progressSteps = config.aadProgressSteps ?? [
            "🔍 Connecting to Azure Active Directory...",
            "🔐 Authenticating with directory services...",
            "📊 Searching user database...",
            "✓ User found: validating credentials...",
            "📁 Retrieving user profile attributes...",
            "👥 Checking group memberships...",
            "✅ Authentication complete!"
        ]

        var currentStepIndex = 0
        let stepDuration: TimeInterval = config.aadStepDuration ?? 1.2

        simulationTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            if currentStepIndex < progressSteps.count {
                withAnimation(Theme.Animation.smooth) {
                    progressMessage = progressSteps[currentStepIndex]
                    self.currentStep = currentStepIndex
                }
                currentStepIndex += 1
            } else {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    completion(.success)
                }
            }
        }
    }
}

// MARK: - Wave Shape (Updated with Theme)
struct Wave: View {
    let amplitude: CGFloat
    let frequency: CGFloat
    let phase: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midHeight = height / 2

                path.move(to: CGPoint(x: 0, y: midHeight))

                for x in stride(from: 0, to: width, by: 1) {
                    let relativeX = x / width
                    let y = sin(relativeX * frequency * .pi * 2 + phase) * amplitude + midHeight
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                path.addLine(to: CGPoint(x: width, y: height))
                path.addLine(to: CGPoint(x: 0, y: height))
                path.closeSubpath()
            }
            .fill(color)
        }
    }
}

// MARK: - Preview
