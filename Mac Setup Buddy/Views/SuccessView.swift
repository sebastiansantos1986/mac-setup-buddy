//
//  SuccessView.swift
//  Mac Setup Buddy
//
//  Created by Sebastian Santos on 10/3/25.
//
//  Updated to use centralized Theme system
//

import SwiftUI

struct SuccessView: View {
    let email: String
    
    @State private var checkmarkScale: CGFloat = 0
    @State private var glowAnimation = false
    @State private var contentAppeared = false

    var body: some View {
        ZStack {
            // Background - using Theme
            Theme.Gradients.background
                .ignoresSafeArea()
            
            VStack(spacing: Theme.Spacing.xl) {
                Spacer()
                
                // Success checkmark with glow
                ZStack {
                    // Glow layers
                    ForEach(0..<2, id: \.self) { index in
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Theme.Status.success.opacity(0.4 - Double(index) * 0.15),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: 60 + Double(index) * 30
                                )
                            )
                            .frame(width: 140 + CGFloat(index) * 40,
                                   height: 140 + CGFloat(index) * 40)
                            .scaleEffect(glowAnimation ? 1.2 : 0.8)
                            .animation(
                                .easeInOut(duration: 2 + Double(index) * 0.5)
                                .repeatForever(autoreverses: true),
                                value: glowAnimation
                            )
                    }
                    
                    // Main checkmark circle
                    Circle()
                        .fill(Theme.Gradients.success)
                        .frame(width: 80, height: 80)
                        .shadow(
                            color: Theme.Status.success.opacity(0.6),
                            radius: 20,
                            y: 5
                        )
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
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(Theme.Text.primary)
                }
                .scaleEffect(checkmarkScale)
                .onAppear {
                    withAnimation(Theme.Animation.spring) {
                        checkmarkScale = 1
                    }
                    glowAnimation = true
                }

                // Title and subtitle
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Setup Complete")
                        .font(Theme.Typography.largeTitle())
                        .foregroundColor(Theme.Text.primary)

                    Text("Provisioned for:")
                        .font(Theme.Typography.body())
                        .foregroundColor(Theme.Text.tertiary)
                    
                    // Email badge
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(Theme.Brand.primary)
                            .font(.system(size: 14))
                        
                        Text(email)
                            .font(Theme.Typography.bodyBold())
                            .foregroundColor(Theme.Text.primary)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .fill(Theme.Background.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                    .stroke(Theme.Brand.primary.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 20)
                .onAppear {
                    withAnimation(.easeOut(duration: Theme.Animation.slow).delay(0.3)) {
                        contentAppeared = true
                    }
                }
                
                Spacer()
                
                // Completion info
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(Theme.Text.disabled)
                        .font(.system(size: 12))
                    Text("Completed at \(currentTime())")
                        .font(Theme.Typography.caption())
                        .foregroundColor(Theme.Text.disabled)
                }
                .padding(.bottom, Theme.Spacing.xl)
                .opacity(contentAppeared ? 1 : 0)
            }
            .padding(Theme.Spacing.xxxl)
        }
    }
    
    private func currentTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

