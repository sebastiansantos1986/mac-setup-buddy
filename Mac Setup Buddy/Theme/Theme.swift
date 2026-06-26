//
//  Theme.swift
//  Mac Setup Buddy
//
//  Created by Sebastian Santos
//  Centralized theming - change colors here to rebrand the entire app
//

import SwiftUI
import AppKit

private extension NSColor {
    static func themeColor(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

private extension Color {
    static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? dark : light
        })
    }
}

// MARK: - App Theme
/// Centralized theme configuration for Mac Setup Buddy
/// To rebrand: modify the colors in this file only
struct Theme {
    
    // MARK: - Brand Colors
    struct Brand {
        /// Primary brand color - used for main actions and highlights
        static let primary = Color.adaptive(
            light: .themeColor(0.04, 0.52, 0.68),
            dark: .themeColor(0.22, 0.64, 0.95)
        )
        
        /// Secondary brand color - used for accents
        static let secondary = Color.adaptive(
            light: .themeColor(0.08, 0.70, 0.64),
            dark: .themeColor(0.14, 0.82, 0.78)
        )
        
        /// Tertiary - used for special highlights
        static let tertiary = Color.adaptive(
            light: .themeColor(0.94, 0.32, 0.26),
            dark: .themeColor(1.00, 0.46, 0.34)
        )
    }
    
    // MARK: - Background Colors
    struct Background {
        /// Main app background - soft blue-tinted white
        static let primary = Color.adaptive(
            light: .themeColor(0.94, 0.98, 1.00),
            dark: .themeColor(0.045, 0.055, 0.085)
        )
        
        /// Secondary background - cool surface
        static let secondary = Color.adaptive(
            light: .themeColor(0.88, 0.95, 0.98),
            dark: .themeColor(0.070, 0.080, 0.120)
        )
        
        /// Tertiary background - for depth variation
        static let tertiary = Color.adaptive(
            light: .themeColor(0.82, 0.91, 0.95),
            dark: .themeColor(0.095, 0.105, 0.150)
        )
        
        /// Card background with transparency
        static let card = Color.adaptive(
            light: .themeColor(1.00, 1.00, 1.00, 0.94),
            dark: .themeColor(0.105, 0.115, 0.165, 0.94)
        )
        
        /// Elevated card background
        static let cardElevated = Color.adaptive(
            light: .themeColor(1.00, 1.00, 1.00, 0.985),
            dark: .themeColor(0.125, 0.135, 0.195, 0.97)
        )
        
        /// Overlay for modals/sheets
        static let overlay = Color.adaptive(
            light: .themeColor(0.38, 0.52, 0.62, 0.18),
            dark: .themeColor(0.02, 0.03, 0.05, 0.42)
        )
    }
    
    // MARK: - Text Colors
    struct Text {
        /// Primary text - charcoal
        static let primary = Color.adaptive(
            light: .themeColor(0.09, 0.13, 0.18),
            dark: .themeColor(0.93, 0.96, 1.00)
        )
        
        /// Secondary text
        static let secondary = Color.adaptive(
            light: .themeColor(0.28, 0.36, 0.44),
            dark: .themeColor(0.72, 0.77, 0.84)
        )
        
        /// Tertiary text - labels, hints
        static let tertiary = Color.adaptive(
            light: .themeColor(0.43, 0.52, 0.60),
            dark: .themeColor(0.56, 0.62, 0.70)
        )
        
        /// Disabled text
        static let disabled = Color.adaptive(
            light: .themeColor(0.58, 0.66, 0.73),
            dark: .themeColor(0.38, 0.43, 0.51)
        )
        
        /// Muted text - very subtle
        static let muted = Color.adaptive(
            light: .themeColor(0.47, 0.57, 0.66),
            dark: .themeColor(0.50, 0.56, 0.64)
        )
    }
    
    // MARK: - Status Colors
    struct Status {
        /// Success state - bright green
        static let success = Color.adaptive(
            light: .themeColor(0.07, 0.62, 0.33),
            dark: .themeColor(0.18, 0.82, 0.46)
        )
        
        /// Warning state - orange
        static let warning = Color.adaptive(
            light: .themeColor(0.92, 0.48, 0.09),
            dark: .themeColor(1.00, 0.62, 0.18)
        )
        
        /// Error state - red
        static let error = Color.adaptive(
            light: .themeColor(0.78, 0.17, 0.21),
            dark: .themeColor(1.00, 0.36, 0.39)
        )
        
        /// Info state - blue
        static let info = Brand.primary
        
        /// Pending state - gray
        static let pending = Text.muted
    }
    
    // MARK: - Border Colors
    struct Border {
        /// Default border
        static let primary = Color.adaptive(
            light: .themeColor(0.60, 0.76, 0.86, 0.42),
            dark: .themeColor(0.58, 0.66, 0.78, 0.24)
        )
        
        /// Subtle border
        static let subtle = Color.adaptive(
            light: .themeColor(0.64, 0.80, 0.90, 0.26),
            dark: .themeColor(0.66, 0.72, 0.86, 0.14)
        )
        
        /// Highlighted border
        static let highlighted = Brand.primary.opacity(0.35)
        
        /// Focus border - for inputs
        static let focus = Brand.primary.opacity(0.5)
    }
    
    // MARK: - Gradients
    struct Gradients {
        /// Main background gradient
        static let background = LinearGradient(
            gradient: Gradient(colors: [
                Background.primary,
                Color.adaptive(
                    light: .themeColor(0.985, 0.995, 1.00),
                    dark: .themeColor(0.060, 0.070, 0.105)
                ),
                Background.secondary
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        /// Banner gradient - sky to teal
        static let banner = LinearGradient(
            gradient: Gradient(colors: [
                Color.adaptive(light: .themeColor(0.80, 0.94, 1.00), dark: .themeColor(0.13, 0.18, 0.34)),
                Color.adaptive(light: .themeColor(0.64, 0.88, 0.94), dark: .themeColor(0.10, 0.30, 0.50)),
                Color.adaptive(light: .themeColor(0.46, 0.79, 0.82), dark: .themeColor(0.08, 0.43, 0.48))
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        /// Primary button gradient
        static let primaryButton = LinearGradient(
            colors: [Brand.tertiary, Brand.secondary],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        /// Success gradient
        static let success = LinearGradient(
            colors: [
                Color.adaptive(light: .themeColor(0.22, 0.78, 0.46), dark: .themeColor(0.30, 0.88, 0.55)),
                Status.success
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        /// Friendly accent gradient
        static let accent = LinearGradient(
            colors: [
                Brand.tertiary,
                Brand.secondary
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        /// Icon circle gradient
        static let iconCircle = LinearGradient(
            colors: [
                Color.adaptive(light: .themeColor(0.74, 0.92, 0.96), dark: .themeColor(0.18, 0.35, 0.52)),
                Color.adaptive(light: .themeColor(0.40, 0.78, 0.84), dark: .themeColor(0.12, 0.62, 0.68))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        /// Glass border gradient
        static let glassBorder = LinearGradient(
            colors: [
                Color.adaptive(light: .themeColor(1, 1, 1, 0.95), dark: .themeColor(1, 1, 1, 0.18)),
                Brand.primary.opacity(0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        /// Shimmer effect gradient
        static let shimmer = LinearGradient(
            colors: [
                Color.white.opacity(0.0),
                Color.white.opacity(0.24),
                Color.white.opacity(0.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // MARK: - Shadows
    struct Shadows {
        /// Primary shadow for cards
        static func card(_ color: Color = .black) -> (color: Color, radius: CGFloat, y: CGFloat) {
            return (Color.adaptive(light: .themeColor(0.14, 0.26, 0.34, 0.13), dark: .themeColor(0, 0, 0, 0.36)), 18, 9)
        }
        
        /// Glow shadow for buttons
        static func glow(_ color: Color = Brand.primary) -> (color: Color, radius: CGFloat, y: CGFloat) {
            return (color.opacity(0.22), 18, 5)
        }
        
        /// Subtle shadow
        static func subtle() -> (color: Color, radius: CGFloat, y: CGFloat) {
            return (Color.adaptive(light: .themeColor(0.14, 0.26, 0.34, 0.09), dark: .themeColor(0, 0, 0, 0.28)), 8, 3)
        }
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 20
        static let pill: CGFloat = 25
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
    }
    
    // MARK: - Typography
    struct Typography {
        /// Large title - 32pt bold
        static func largeTitle() -> Font {
            .system(size: 32, weight: .bold)
        }
        
        /// Title - 28pt bold
        static func title() -> Font {
            .system(size: 28, weight: .bold)
        }
        
        /// Title 2 - 24pt semibold
        static func title2() -> Font {
            .system(size: 24, weight: .semibold)
        }
        
        /// Title 3 - 20pt semibold
        static func title3() -> Font {
            .system(size: 20, weight: .semibold)
        }
        
        /// Headline - 17pt semibold
        static func headline() -> Font {
            .system(size: 17, weight: .semibold)
        }
        
        /// Body - 15pt regular
        static func body() -> Font {
            .system(size: 15, weight: .regular)
        }
        
        /// Body bold - 15pt medium
        static func bodyBold() -> Font {
            .system(size: 15, weight: .medium)
        }
        
        /// Caption - 13pt regular
        static func caption() -> Font {
            .system(size: 13, weight: .regular)
        }
        
        /// Caption bold - 13pt medium
        static func captionBold() -> Font {
            .system(size: 13, weight: .medium)
        }
        
        /// Small - 11pt regular
        static func small() -> Font {
            .system(size: 11, weight: .regular)
        }
        
        /// Monospace - for code/logs
        static func mono(size: CGFloat = 12) -> Font {
            .system(size: size, weight: .medium, design: .monospaced)
        }
        
        /// Rounded - for friendly text
        static func rounded(size: CGFloat = 15, weight: Font.Weight = .medium) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
    }
    
    // MARK: - Animation Durations
    struct Animation {
        static let quick: Double = 0.15
        static let normal: Double = 0.3
        static let slow: Double = 0.5
        static let verySlow: Double = 0.8
        
        /// Spring animation preset
        static var spring: SwiftUI.Animation {
            .spring(response: 0.6, dampingFraction: 0.8)
        }
        
        /// Bounce animation preset
        static var bounce: SwiftUI.Animation {
            .spring(response: 0.5, dampingFraction: 0.7)
        }
        
        /// Smooth ease in out
        static var smooth: SwiftUI.Animation {
            .easeInOut(duration: normal)
        }
    }
}

// MARK: - Convenience View Modifiers

extension View {
    /// Apply standard card styling
    func themeCard(cornerRadius: CGFloat = Theme.CornerRadius.large) -> some View {
        self
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Theme.Background.cardElevated)
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Theme.Border.primary, lineWidth: 1)
                }
            )
    }
    
    /// Apply glass morphism effect
    func glassCard(cornerRadius: CGFloat = Theme.CornerRadius.large) -> some View {
        self
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Theme.Background.cardElevated)
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Theme.Gradients.glassBorder, lineWidth: 1)
                }
            )
            .shadow(
                color: Theme.Shadows.card().color,
                radius: Theme.Shadows.card().radius,
                y: Theme.Shadows.card().y
            )
    }
    
    /// Apply primary button styling
    func themePrimaryButton(isHovered: Bool = false) -> some View {
        self
            .font(Theme.Typography.headline())
            .foregroundColor(.white)
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.vertical, 14)
            .background(Theme.Gradients.primaryButton)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.pill))
            .shadow(
                color: Theme.Shadows.glow().color.opacity(isHovered ? 0.6 : 0.3),
                radius: Theme.Shadows.glow().radius,
                y: Theme.Shadows.glow().y
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(Theme.Animation.smooth, value: isHovered)
    }
    
    /// Apply secondary button styling
    func themeSecondaryButton(isHovered: Bool = false) -> some View {
        self
            .font(Theme.Typography.headline())
            .foregroundColor(Theme.Text.secondary)
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.pill)
                    .fill(Theme.Background.cardElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.pill)
                            .stroke(Theme.Border.highlighted, lineWidth: 1)
                    )
            )
    }
    
    /// Apply status badge styling
    func statusBadge(status: StatusType) -> some View {
        self
            .font(Theme.Typography.small())
            .foregroundColor(status.color)
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                    .fill(status.color.opacity(0.15))
            )
    }
}

// MARK: - Status Type Helper
enum StatusType {
    case success
    case warning
    case error
    case info
    case pending
    
    var color: Color {
        switch self {
        case .success: return Theme.Status.success
        case .warning: return Theme.Status.warning
        case .error: return Theme.Status.error
        case .info: return Theme.Status.info
        case .pending: return Theme.Status.pending
        }
    }
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        case .pending: return "clock.fill"
        }
    }
}

// MARK: - Preview
