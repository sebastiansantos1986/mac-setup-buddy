//
//  Documentation.md
//  Mac Setup Buddy
//
//  Created by Sebastian Santos on 10/4/25.
//

# Mac Setup Buddy - Technical Documentation

## Overview
Mac Setup Buddy is a macOS application built with SwiftUI that provides a modern, customizable interface for device provisioning and setup workflows. It features a blur background system, multiple view types, and extensive command-line customization options.

## Architecture

### Core Technologies
- **SwiftUI** - Modern declarative UI framework
  - [Apple Documentation](https://developer.apple.com/documentation/swiftui)
- **AppKit** - macOS native framework integration
  - [Apple Documentation](https://developer.apple.com/documentation/appkit)
- **Combine** - Reactive programming for data flow
  - [Apple Documentation](https://developer.apple.com/documentation/combine)

### Key Components

#### 1. Application Delegate (`AppDelegate.swift`)
Manages the application lifecycle and window creation using `NSApplicationDelegate`.
- [NSApplicationDelegate](https://developer.apple.com/documentation/appkit/nsapplicationdelegate)
- [NSWindow](https://developer.apple.com/documentation/appkit/nswindow)
- [NSWindowDelegate](https://developer.apple.com/documentation/appkit/nswindowdelegate)

#### 2. Blur Background System
Creates fullscreen blur overlays using `NSVisualEffectView`:
```swift
NSVisualEffectView(frame: screen.frame)
blurView.blendingMode = .behindWindow
blurView.material = .hudWindow
```
- [NSVisualEffectView](https://developer.apple.com/documentation/appkit/nsvisualeffectview)
- [NSVisualEffectView.Material](https://developer.apple.com/documentation/appkit/nsvisualeffectview/material)
- [NSVisualEffectView.BlendingMode](https://developer.apple.com/documentation/appkit/nsvisualeffectview/blendingmode)

#### 3. SwiftUI Views
All views use SwiftUI's declarative syntax:
- [View Protocol](https://developer.apple.com/documentation/swiftui/view)
- [@State Property Wrapper](https://developer.apple.com/documentation/swiftui/state)
- [@StateObject](https://developer.apple.com/documentation/swiftui/stateobject)
- [@ObservedObject](https://developer.apple.com/documentation/swiftui/observedobject)

## Available Views

### 1. Welcome Screen (`WelcomeView.swift`)
**Purpose**: Initial setup screen with customizable steps
**Command**: `-welcome-screen` or `-welcome_screen`

**Parameters**:
- `-title` - Main welcome title
- `-subtitle` - Subtitle text
- `-message` - Welcome message
- `-banner` - Banner image (local path or URL)
- `-buttonText` - Action button text
- `-timeEstimate` - Time estimate text
- `-step1` through `-step4` - Custom step descriptions
- `-width` - Window width (default: 900)
- `-height` - Window height (default: 700)

### 2. Email Input (`EmailInputView.swift`)
**Purpose**: Capture user email address
**Command**: `-email-prompt` or `-email_prompt`

**Parameters**:
- `-title` - Form title
- `-message` - Instructions
- `-placeholder` - Input field placeholder
- `-banner` - Banner image

### 3. Installation Progress (`InstallationProgressView.swift`)
**Purpose**: Display JAMF policy installation progress
**Command**: `-jamf_policy` or `-jamf-policy`

**Parameters**:
- `-title` - Progress title
- `-subtitle` - Subtitle
- `-enableLogMonitor` - Enable log file monitoring (true/false)
- `-autoCloseDelay` - Seconds before auto-close (default: 5)
- `-showCountdown` - Show countdown timer (true/false)

### 4. AAD Progress (`AADProgressView.swift`)
**Purpose**: Azure Active Directory lookup animation
**Command**: `-aad` or `-aad-progress`

**Parameters**:
- `-message` - Progress message
- `-email` - User email to display
- `-icon` - SF Symbol name
- `-autoProgress` - Auto-advance through steps (true/false)
- `-stepDuration` - Duration between steps (seconds)

### 5. Completion View (`CompletionView.swift`)
**Purpose**: Setup completion with user/device info
**Command**: `-completion` or `-complete`

**Parameters**:
- `-userName` - User's full name
- `-email` - User email
- `-department` - Department name
- `-title` - Job title
- `-assetTag` - Asset tag number
- `-deviceName` - Computer name
- `-deviceModel` - Hardware model
- `-serialNumber` - Serial number
- `-osVersion` - macOS version

### 6. Notification (`NotificationView.swift`)
**Purpose**: Display notification messages
**Command**: `-notification`

**Parameters**:
- `-notificationTitle` - Notification title
- `-notificationMessage` - Message content
- `-notificationIcon` - SF Symbol name

## Background Styles

Control background overlay with `-background` or `-bg`:
- `blur` - macOS blur effect
- `solid` - Solid black overlay
- `transparent` - Transparent background
- `none` - No background modification

## Key SwiftUI Concepts Used

### 1. View Modifiers
```swift
.frame(width: 100, height: 100)
.background(Color.blue)
.cornerRadius(10)
```
- [View Modifiers](https://developer.apple.com/documentation/swiftui/viewmodifier)

### 2. Property Wrappers
```swift
@State private var isAnimating = false
@Published var currentView: ViewState
```
- [@State](https://developer.apple.com/documentation/swiftui/state)
- [@Published](https://developer.apple.com/documentation/combine/published)

### 3. Animations
```swift
withAnimation(.easeInOut(duration: 0.3)) {
    // Animated changes
}
```
- [Animation](https://developer.apple.com/documentation/swiftui/animation)
- [withAnimation](https://developer.apple.com/documentation/swiftui/withanimation(_:_:))

### 4. Gradients
```swift
LinearGradient(colors: [...], startPoint: .top, endPoint: .bottom)
RadialGradient(colors: [...], center: .center, startRadius: 5, endRadius: 50)
```
- [LinearGradient](https://developer.apple.com/documentation/swiftui/lineargradient)
- [RadialGradient](https://developer.apple.com/documentation/swiftui/radialgradient)

## Advanced Features

### Banner System (`BannerView.swift`)
Loads images from local files or URLs:
```swift
// Local file
-banner ~/Desktop/banner.png

// URL
-banner https://example.com/image.jpg
```
Uses `URLSession` for network requests and `FileManager` for local files:
- [URLSession](https://developer.apple.com/documentation/foundation/urlsession)
- [FileManager](https://developer.apple.com/documentation/foundation/filemanager)

### Glass Morphism Effects
Achieved using materials and opacity:
```swift
.background(.ultraThinMaterial)
.background(Color.white.opacity(0.05))
```
- [Material](https://developer.apple.com/documentation/swiftui/material)

### SF Symbols
Icon system used throughout:
```swift
Image(systemName: "checkmark.circle.fill")
```
- [SF Symbols](https://developer.apple.com/sf-symbols/)
- [Image](https://developer.apple.com/documentation/swiftui/image)

## Command Line Parsing

The application uses `CommandLine.arguments` to parse parameters:
- [CommandLine](https://developer.apple.com/documentation/swift/commandline)

## Usage Examples

### Basic Welcome Screen
```bash
./Mac Setup Buddy\ Setup -welcome-screen -background blur -width 900 -height 750
```

### Email Capture with Banner
```bash
./Mac Setup Buddy\ Setup -email-prompt \
    -background blur \
    -banner ~/Desktop/logo.png \
    -title "Email Verification" \
    -message "Enter your corporate email"
```

### JAMF Installation Progress
```bash
./Mac Setup Buddy\ Setup -jamf_policy \
    -background blur \
    -width 1000 \
    -height 750 \
    -title "Installing Software" \
    -autoCloseDelay 10
```

### Success Notification
```bash
./Mac Setup Buddy\ Setup -notification \
    -background blur \
    -notificationTitle "Setup Complete" \
    -notificationMessage "Your device is ready" \
    -notificationIcon "checkmark.circle.fill"
```

## File Structure

```
Mac Setup Buddy/
├── AppDelegate.swift           # Application lifecycle & blur system
├── MacSetupBuddyApp.swift  # Main app entry point
├── CommandLineConfig.swift    # Configuration structures
├── CommandLineParser.swift    # CLI argument parsing
├── Views/
│   ├── WelcomeView.swift     # Welcome screen
│   ├── EmailInputView.swift  # Email capture
│   ├── InstallationProgressView.swift # JAMF progress
│   ├── AADProgressView.swift # Azure AD lookup
│   ├── CompletionView.swift  # Completion screen
│   ├── NotificationView.swift # Notifications
│   ├── SuccessView.swift     # Success display
│   └── FullscreenLockView.swift # Lock screen
├── Components/
│   ├── BannerView.swift      # Banner image loader
│   └── VisualEffectBlur.swift # NSViewRepresentable for blur
└── Assets.xcassets/          # App icons and images
```

## Building and Running

### From Xcode
1. Open `Mac Setup Buddy.xcodeproj`
2. Select target device (Mac)
3. Build: ⌘B
4. Run: ⌘R

### From Command Line
```bash
# Build
xcodebuild -project "Mac Setup Buddy.xcodeproj" -scheme "Mac Setup Buddy" build

# Run from DerivedData
./Library/Developer/Xcode/DerivedData/.../Mac Setup Buddy\ Setup.app/Contents/MacOS/Mac Setup Buddy\ Setup [options]
```

## Key Apple Technologies

- **SwiftUI**: Modern UI framework
  - [SwiftUI Overview](https://developer.apple.com/xcode/swiftui/)
  - [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)

- **AppKit Integration**: macOS-specific features
  - [AppKit Framework](https://developer.apple.com/documentation/appkit)
  - [NSWindow Programming](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/WinPanel/Introduction.html)

- **Combine Framework**: Reactive programming
  - [Combine Framework](https://developer.apple.com/documentation/combine)
  - [Using Combine](https://developer.apple.com/documentation/combine/receiving-and-handling-events-with-combine)

## Troubleshooting

### Common Issues

1. **Blur not appearing**: Ensure `-background blur` is specified
2. **Window cut off**: Increase `-height` parameter (750+ for views with banners)
3. **Banner not loading**: Check file path or URL accessibility
4. **App crashes**: Use quotes for multi-word arguments (`-title "My Title"`)

### Debug Mode
Add debug output to CommandLineParser:
```swift
print("🔥 Received arguments: \(arguments)")
print("🎯 Parsed screen: \(screen)")
print("🎨 Background: \(config.backgroundStyle)")
```

## Security Considerations

- The app requires screen recording permissions for blur overlay
- Network access needed for URL-based banners
- File system access for local images and JAMF logs
- No data is stored persistently

## Performance Notes

- Blur effects use GPU acceleration via Core Animation
- Animations use SwiftUI's built-in optimization
- Image loading is asynchronous to prevent UI blocking
- Timer-based progress updates use efficient scheduling

## Contributing

When adding new views:
1. Create SwiftUI View file
2. Add to ViewState enum
3. Update CommandLineParser
4. Add to AppDelegate switch statement
5. Document command-line parameters

## Resources

- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [WWDC Videos](https://developer.apple.com/videos/swiftui)
- [Swift Forums](https://forums.swift.org/c/swiftui)

---

*This documentation covers Mac Setup Buddy v1.0 - October 2025*
