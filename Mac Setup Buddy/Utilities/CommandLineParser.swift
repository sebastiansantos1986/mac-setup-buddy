import Foundation

// BLUR ARGUMENT PARSER FILE
// This file parses command line arguments to determine if blur should be activated
// It reads -background blur or -bg blur from command line
// ALL TYPE DEFINITIONS ARE IN CommandLineConfig.swift

// MARK: - Command Line Parser
class CommandLineParser {

    static func parseArguments() -> (screen: ViewState, config: CommandLineConfig) {
        let arguments = CommandLine.arguments
        var config = CommandLineConfig()
        var screen: ViewState = .welcome

        print("Received arguments: \(arguments.joined(separator: " "))")

        // MARK: - JSON Configuration File
        // Check for config file first, then let explicit CLI flags override it.
        for i in 0..<arguments.count {
            if arguments[i] == "-config" || arguments[i] == "--config" ||
               arguments[i] == "-config-file" || arguments[i] == "--config-file" {
                if i + 1 < arguments.count {
                    config.configFilePath = arguments[i + 1]
                    print("Using configuration file: \(arguments[i + 1])")
                }
            }
        }

        if let configPath = config.configFilePath,
           let loadedConfig = ConfigurationLoader.shared.loadFromJSON(path: NSString(string: configPath).expandingTildeInPath) {
            config = loadedConfig.toCommandLineConfig()
            config.configFilePath = configPath
            screen = screenFromString(loadedConfig.ui?.defaultScreen) ?? screen
            print("Loaded JSON configuration")
        }

        if arguments.contains("--preview") || arguments.contains("-preview") ||
            arguments.contains("--preview-mode") || arguments.contains("-preview-mode") {
            config.previewMode = true
            config.windowWidth = max(config.windowWidth, 1180)
            config.windowHeight = max(config.windowHeight, 780)
            screen = .welcome
            print("Preview Mode enabled")
        }

        // MARK: - Persistent Blur Control (Priority)
        // Check for blur-only commands first
        if arguments.contains("--blur-start") {
            config.persistentBlurAction = .start
            config.blurMode = .persistent
            print("Action: Start persistent blur")
            return (.welcome, config)  // Screen doesn't matter for blur-only
        }
        
        if arguments.contains("--blur-stop") {
            config.persistentBlurAction = .stop
            print("Action: Stop persistent blur")
            return (.welcome, config)  // Screen doesn't matter for blur-stop
        }
        
        // MARK: - Blur Mode Parsing
        for i in 0..<arguments.count {
            if arguments[i] == "--blur-mode" || arguments[i] == "-blur-mode" {
                if i + 1 < arguments.count {
                    if let mode = BlurMode(rawValue: arguments[i + 1].lowercased()) {
                        config.blurMode = mode
                        print("Blur mode: \(mode)")
                    }
                }
            }
        }

        // MARK: Flow Mode Parsing
        if arguments.contains("-flow") {
            config.enableFlow = true
            config.blurMode = .persistent  // Flow mode implies persistent blur
            print("Flow mode enabled - blur will persist between screens")
        }

        // MARK: Background Style
        for i in 0..<arguments.count {
            if arguments[i] == "-background" || arguments[i] == "-bg" || arguments[i] == "--background" {
                if i + 1 < arguments.count {
                    if let style = BackgroundStyle(rawValue: arguments[i + 1].lowercased()) {
                        config.backgroundStyle = style
                    }
                }
            }
            if arguments[i] == "-hideControls" || arguments[i] == "--hideControls" ||
               arguments[i] == "--hide-controls" || arguments[i] == "-hide-controls" ||
               arguments[i] == "-hide_status_bar" || arguments[i] == "--hide_status_bar" {
                config.hideWindowControls = true
                config.hideControls = true
                print("Window controls will be hidden")
            }
        }

        // MARK: - New --screen Syntax (v2.0)
        // This unified syntax replaces the old -welcome-screen, -email-prompt, etc.
        for i in 0..<arguments.count {
            if arguments[i] == "--screen" || arguments[i] == "-screen" {
                if i + 1 < arguments.count {
                    let screenName = arguments[i + 1].lowercased()
                    if let selectedScreen = screenFromString(screenName) {
                        screen = selectedScreen
                        if screen == .aadProgress {
                            config.showAADProgress = true
                        }
                    } else {
                        print("WARNING: Unknown screen '\(screenName)', defaulting to welcome")
                        screen = .welcome
                    }
                    print("Screen selected via --screen: \(screenName) -> \(screen)")
                }
            }
        }
        
        // MARK: Screen Selection (Legacy flags)
        if arguments.contains("-welcome-screen") || arguments.contains("-welcome_screen") {
            screen = .welcome
            
            // WELCOME SCREEN CUSTOMIZATION
            for i in 0..<arguments.count {
                switch arguments[i] {
                case "-title", "--title":
                    if i + 1 < arguments.count { config.title = arguments[i + 1] }
                case "-subtitle", "--subtitle":
                    if i + 1 < arguments.count { config.subtitle = arguments[i + 1] }
                case "-message", "--message":
                    if i + 1 < arguments.count { config.message = arguments[i + 1] }
                case "-banner", "-bannerImage", "--banner":
                    if i + 1 < arguments.count { config.bannerImage = arguments[i + 1] }
                case "-bannerTitle", "--bannerTitle":
                    if i + 1 < arguments.count { config.bannerTitle = arguments[i + 1] }
                case "-bannerSubtitle", "--bannerSubtitle":
                    if i + 1 < arguments.count { config.bannerSubtitle = arguments[i + 1] }
                case "-icon", "-welcomeIcon", "--icon":
                    if i + 1 < arguments.count { config.welcomeIcon = arguments[i + 1] }
                case "-buttonText", "--buttonText":
                    if i + 1 < arguments.count { config.buttonText = arguments[i + 1] }
                case "-timeEstimate", "--timeEstimate":
                    if i + 1 < arguments.count { config.timeEstimate = arguments[i + 1] }
                case "-step1", "--step1":
                    if i + 1 < arguments.count { config.welcomeStep1 = arguments[i + 1] }
                case "-step2", "--step2":
                    if i + 1 < arguments.count { config.welcomeStep2 = arguments[i + 1] }
                case "-step3", "--step3":
                    if i + 1 < arguments.count { config.welcomeStep3 = arguments[i + 1] }
                case "-step4", "--step4":
                    if i + 1 < arguments.count { config.welcomeStep4 = arguments[i + 1] }
                case "-width", "--width":
                    if i + 1 < arguments.count, let width = Double(arguments[i + 1]) {
                        config.windowWidth = width
                    }
                case "-height", "--height":
                    if i + 1 < arguments.count, let height = Double(arguments[i + 1]) {
                        config.windowHeight = height
                    }
                default:
                    break
                }
            }

        } else if arguments.contains("-email_prompt") || arguments.contains("-email-prompt") {
            screen = .emailInput

            for i in 0..<arguments.count {
                switch arguments[i] {
                case "-title", "--title":
                    if i + 1 < arguments.count { config.title = arguments[i + 1] }
                case "-message", "--message":
                    if i + 1 < arguments.count { config.message = arguments[i + 1] }
                case "-placeholder", "--placeholder":
                    if i + 1 < arguments.count { config.emailPlaceholder = arguments[i + 1] }
                case "-banner", "-bannerImage", "--banner":
                    if i + 1 < arguments.count { config.bannerImage = arguments[i + 1] }
                case "-width", "--width":
                    if i + 1 < arguments.count, let width = Double(arguments[i + 1]) {
                        config.windowWidth = width
                    }
                case "-height", "--height":
                    if i + 1 < arguments.count, let height = Double(arguments[i + 1]) {
                        config.windowHeight = height
                    }
                default:
                    break
                }
            }

        } else if arguments.contains("-jamf_policy") || arguments.contains("-jamf-policy") {
            screen = .progress
            
            for i in 0..<arguments.count {
                switch arguments[i] {
                case "-policies", "--policies":
                    if i + 1 < arguments.count {
                        let policiesString = arguments[i + 1]
                        config.installationItems = parsePolicies(policiesString)
                        print("DEBUG: Parsed \(config.installationItems?.count ?? 0) policies")
                    }
                case "-title", "--title":
                    if i + 1 < arguments.count { config.title = arguments[i + 1] }
                case "-subtitle", "--subtitle":
                    if i + 1 < arguments.count { config.subtitle = arguments[i + 1] }
                case "-banner", "-bannerImage", "--banner":
                    if i + 1 < arguments.count { config.bannerImage = arguments[i + 1] }
                case "-enableLogMonitor", "--enableLogMonitor":
                    if i + 1 < arguments.count {
                        config.enableLogMonitor = arguments[i + 1].lowercased() == "true"
                    }
                case "-autoCloseDelay", "--autoCloseDelay":
                    if i + 1 < arguments.count, let delay = Int(arguments[i + 1]) {
                        config.autoCloseDelay = delay
                    }
                case "-showCountdown", "--showCountdown":
                    if i + 1 < arguments.count {
                        config.showCountdown = arguments[i + 1].lowercased() == "true"
                    }
                case "-width", "--width":
                    if i + 1 < arguments.count, let width = Double(arguments[i + 1]) {
                        config.windowWidth = width
                    }
                case "-height", "--height":
                    if i + 1 < arguments.count, let height = Double(arguments[i + 1]) {
                        config.windowHeight = height
                    }
                default:
                    break
                }
            }

        } else if arguments.contains("-user_info") || arguments.contains("-user-info") {
            screen = .success

        } else if arguments.contains("-completion") || arguments.contains("-complete") {
            screen = .completion
            
            config.isEncrypted = EncryptionChecker.checkFileVaultStatus()
            print("FileVault encryption status: \(config.isEncrypted ?? false)")
            
            for i in 0..<arguments.count {
                switch arguments[i] {
                case "-userName", "--userName", "-username":
                    if i + 1 < arguments.count { config.userName = arguments[i + 1] }
                case "-email", "--email":
                    if i + 1 < arguments.count { config.email = arguments[i + 1] }
                case "-department", "--department":
                    if i + 1 < arguments.count { config.userDepartment = arguments[i + 1] }
                case "-title", "--title":
                    if i + 1 < arguments.count { config.userTitle = arguments[i + 1] }
                case "-message", "--message":
                    if i + 1 < arguments.count { config.message = arguments[i + 1] }
                case "-assetTag", "--assetTag":
                    if i + 1 < arguments.count { config.assetTag = arguments[i + 1] }
                case "-deviceName", "--deviceName":
                    if i + 1 < arguments.count { config.deviceName = arguments[i + 1] }
                case "-deviceModel", "--deviceModel":
                    if i + 1 < arguments.count { config.deviceModel = arguments[i + 1] }
                case "-serialNumber", "--serialNumber":
                    if i + 1 < arguments.count { config.serialNumber = arguments[i + 1] }
                case "-osVersion", "--osVersion":
                    if i + 1 < arguments.count { config.osVersion = arguments[i + 1] }
                case "-isEncrypted", "--isEncrypted":
                    if i + 1 < arguments.count {
                        config.isEncrypted = arguments[i + 1].lowercased() == "true"
                    }
                case "-banner", "-bannerImage", "--banner":
                    if i + 1 < arguments.count { config.bannerImage = arguments[i + 1] }
                case "-width", "--width":
                    if i + 1 < arguments.count, let width = Double(arguments[i + 1]) {
                        config.windowWidth = width
                    }
                case "-height", "--height":
                    if i + 1 < arguments.count, let height = Double(arguments[i + 1]) {
                        config.windowHeight = height
                    }
                default:
                    break
                }
            }
            
        } else if arguments.contains("-aad-progress") || arguments.contains("-aad_progress") {
            screen = .aadProgress
            
            for i in 0..<arguments.count {
                switch arguments[i] {
                case "-message", "--message":
                    if i + 1 < arguments.count { config.message = arguments[i + 1] }
                case "-email", "--email":
                    if i + 1 < arguments.count { config.email = arguments[i + 1] }
                case "-icon", "-aadIcon", "--icon":
                    if i + 1 < arguments.count { config.aadIcon = arguments[i + 1] }
                case "-progressMessage", "--progressMessage":
                    if i + 1 < arguments.count { config.aadProgressMessage = arguments[i + 1] }
                case "-cancelButton", "--cancelButton":
                    if i + 1 < arguments.count { config.aadCancelButtonText = arguments[i + 1] }
                case "-autoProgress", "--autoProgress":
                    if i + 1 < arguments.count {
                        config.aadAutoProgress = arguments[i + 1].lowercased() == "true"
                    }
                case "-stepDuration", "--stepDuration":
                    if i + 1 < arguments.count, let duration = Double(arguments[i + 1]) {
                        config.aadStepDuration = duration
                    }
                case "-width", "--width":
                    if i + 1 < arguments.count, let width = Double(arguments[i + 1]) {
                        config.windowWidth = width
                    }
                case "-height", "--height":
                    if i + 1 < arguments.count, let height = Double(arguments[i + 1]) {
                        config.windowHeight = height
                    }
                case "-banner", "-bannerImage", "--banner":
                    if i + 1 < arguments.count { config.bannerImage = arguments[i + 1] }
                default:
                    break
                }
            }
            config.showAADProgress = true
            
        } else if arguments.contains("-notification") || arguments.contains("--notification") {
            screen = .notification
            
            for i in 0..<arguments.count {
                switch arguments[i] {
                case "-title", "--title":
                    if i + 1 < arguments.count {
                        config.notificationTitle = arguments[i + 1]
                        config.title = arguments[i + 1]
                    }
                case "-message", "--message":
                    if i + 1 < arguments.count {
                        config.notificationMessage = arguments[i + 1]
                        config.message = arguments[i + 1]
                    }
                case "-icon", "--icon":
                    if i + 1 < arguments.count {
                        config.notificationIcon = arguments[i + 1]
                    }
                case "-button", "--button":
                    if i + 1 < arguments.count {
                        config.notificationButtons = [arguments[i + 1]]
                    }
                case "-buttons", "--buttons":
                    if i + 1 < arguments.count {
                        config.notificationButtons = arguments[i + 1].components(separatedBy: ",")
                    }
                case "-autoCloseDelay", "--autoCloseDelay":
                    if i + 1 < arguments.count, let delay = Int(arguments[i + 1]) {
                        config.autoCloseDelay = delay
                    }
                case "-showCountdown", "--showCountdown":
                    if i + 1 < arguments.count {
                        config.showCountdown = arguments[i + 1].lowercased() == "true"
                    }
                case "-banner", "-bannerImage", "--banner":
                    if i + 1 < arguments.count { config.bannerImage = arguments[i + 1] }
                case "-width", "--width":
                    if i + 1 < arguments.count, let width = Double(arguments[i + 1]) {
                        config.windowWidth = width
                    }
                case "-height", "--height":
                    if i + 1 < arguments.count, let height = Double(arguments[i + 1]) {
                        config.windowHeight = height
                    }
                default:
                    break
                }
            }
        
        } else if arguments.contains("-credential-login") || arguments.contains("-login") || arguments.contains("--login") {
            screen = .credentialLogin
            
            // Set default fullscreen dimensions for login
            config.windowWidth = 1440
            config.windowHeight = 900
            
            for i in 0..<arguments.count {
                switch arguments[i] {
                case "-title", "--title":
                    if i + 1 < arguments.count { config.title = arguments[i + 1] }
                case "-message", "--message":
                    if i + 1 < arguments.count { config.message = arguments[i + 1] }
                case "-banner", "-bannerImage", "--banner", "-logo":
                    if i + 1 < arguments.count { config.bannerImage = arguments[i + 1] }
                case "-width", "--width":
                    if i + 1 < arguments.count, let width = Double(arguments[i + 1]) {
                        config.windowWidth = width
                    }
                case "-height", "--height":
                    if i + 1 < arguments.count, let height = Double(arguments[i + 1]) {
                        config.windowHeight = height
                    }
                    
                // NEW: Credential Login specific options
                case "-infoMessage", "--infoMessage", "-loginMessage", "--loginMessage":
                    if i + 1 < arguments.count { config.loginInfoMessage = arguments[i + 1] }
                case "-oktaDomain", "--oktaDomain", "-okta":
                    if i + 1 < arguments.count { config.oktaDomain = arguments[i + 1] }
                case "-createUser", "--createUser", "-createLocalUser":
                    if i + 1 < arguments.count {
                        config.createLocalUser = arguments[i + 1].lowercased() == "true"
                    }
                case "-showLanguage", "--showLanguage", "-languageSelector":
                    if i + 1 < arguments.count {
                        config.showLanguageSelector = arguments[i + 1].lowercased() == "true"
                    }
                case "-showNetwork", "--showNetwork", "-networkSelector":
                    if i + 1 < arguments.count {
                        config.showNetworkSelector = arguments[i + 1].lowercased() == "true"
                    }
                case "-helpContact", "--helpContact", "-helpInfo":
                    if i + 1 < arguments.count { config.helpContactInfo = arguments[i + 1] }
                case "-allowedDomains", "--allowedDomains":
                    if i + 1 < arguments.count {
                        config.allowedDomains = arguments[i + 1].components(separatedBy: ",")
                    }
                default:
                    break
                }
            }
        }
        
        // MARK: - Parse common flags for --screen syntax
        parseCommonFlags(arguments: arguments, config: &config)

        // DEBUG OUTPUT
        print("Parsed screen = \(screen)")
        print("Background = \(config.backgroundStyle)")
        print("Blur mode = \(config.blurMode)")
        print("Flow mode = \(config.enableFlow)")
        print("Preview mode = \(config.previewMode)")
        print("Title = \(config.title ?? "none")")

        return (screen, config)
    }

    private static func screenFromString(_ value: String?) -> ViewState? {
        guard let value else { return nil }

        switch value.lowercased() {
        case "welcome":
            return .welcome
        case "email", "authentication", "user-authentication":
            return .emailInput
        case "networkcheck", "network-check", "network":
            return .networkCheck
        case "credentials", "creds", "sso":
            return .credentials
        case "login", "credential-login", "jamf-login", "fullscreen-login":
            return .credentialLogin
        case "aad", "azure", "aad-progress":
            return .aadProgress
        case "progress", "install", "installation", "software-deployment":
            return .progress
        case "completion", "complete", "done", "setup-complete":
            return .completion
        case "notification", "notify", "alert":
            return .notification
        case "error", "recovery", "error-recovery":
            return .error
        default:
            return nil
        }
    }
    
    // MARK: - Parse Common Flags
    private static func parseCommonFlags(arguments: [String], config: inout CommandLineConfig) {
        for i in 0..<arguments.count {
            switch arguments[i] {
            case "-title", "--title":
                if i + 1 < arguments.count && config.title == nil {
                    config.title = arguments[i + 1]
                }
            case "-subtitle", "--subtitle":
                if i + 1 < arguments.count && config.subtitle == nil {
                    config.subtitle = arguments[i + 1]
                }
            case "-message", "--message":
                if i + 1 < arguments.count && config.message == nil {
                    config.message = arguments[i + 1]
                }
            case "-banner", "-bannerImage", "--banner":
                if i + 1 < arguments.count && config.bannerImage == nil {
                    config.bannerImage = arguments[i + 1]
                }
            case "-icon", "--icon":
                if i + 1 < arguments.count {
                    config.welcomeIcon = arguments[i + 1]
                    config.aadIcon = arguments[i + 1]
                    config.notificationIcon = arguments[i + 1]
                }
            case "-email", "--email":
                if i + 1 < arguments.count { config.email = arguments[i + 1] }
            case "-width", "--width":
                if i + 1 < arguments.count, let width = Double(arguments[i + 1]) {
                    config.windowWidth = width
                }
            case "-height", "--height":
                if i + 1 < arguments.count, let height = Double(arguments[i + 1]) {
                    config.windowHeight = height
                }
            case "-autoCloseDelay", "--autoCloseDelay":
                if i + 1 < arguments.count, let delay = Int(arguments[i + 1]) {
                    config.autoCloseDelay = delay
                }
            case "-showCountdown", "--showCountdown":
                if i + 1 < arguments.count {
                    config.showCountdown = arguments[i + 1].lowercased() == "true"
                }
            case "-policies", "--policies":
                if i + 1 < arguments.count {
                    config.installationItems = parsePolicies(arguments[i + 1])
                }
            case "-enableLogMonitor", "--enableLogMonitor":
                if i + 1 < arguments.count {
                    config.enableLogMonitor = arguments[i + 1].lowercased() == "true"
                }
            case "-userName", "--userName", "-username":
                if i + 1 < arguments.count { config.userName = arguments[i + 1] }
            case "-department", "--department":
                if i + 1 < arguments.count { config.userDepartment = arguments[i + 1] }
            case "-assetTag", "--assetTag":
                if i + 1 < arguments.count { config.assetTag = arguments[i + 1] }
            case "-deviceName", "--deviceName":
                if i + 1 < arguments.count { config.deviceName = arguments[i + 1] }
            case "-deviceModel", "--deviceModel":
                if i + 1 < arguments.count { config.deviceModel = arguments[i + 1] }
            case "-serialNumber", "--serialNumber":
                if i + 1 < arguments.count { config.serialNumber = arguments[i + 1] }
            case "-osVersion", "--osVersion":
                if i + 1 < arguments.count { config.osVersion = arguments[i + 1] }
            case "-placeholder", "--placeholder":
                if i + 1 < arguments.count { config.emailPlaceholder = arguments[i + 1] }
            case "-buttonText", "--buttonText":
                if i + 1 < arguments.count { config.buttonText = arguments[i + 1] }
            case "-button", "--button":
                if i + 1 < arguments.count { config.notificationButtons = [arguments[i + 1]] }
            case "-buttons", "--buttons":
                if i + 1 < arguments.count {
                    config.notificationButtons = arguments[i + 1].components(separatedBy: ",")
                }
            case "-autoProgress", "--autoProgress":
                if i + 1 < arguments.count {
                    config.aadAutoProgress = arguments[i + 1].lowercased() == "true"
                }
            case "-stepDuration", "--stepDuration":
                if i + 1 < arguments.count, let duration = Double(arguments[i + 1]) {
                    config.aadStepDuration = duration
                }
            default:
                break
            }
        }
    }
    
    // MARK: - Policy Parsing
    private static func parsePolicies(_ policiesString: String) -> [InstallationItem] {
        var items: [InstallationItem] = []
        
        let policyStrings = policiesString.components(separatedBy: ";")
        
        for policyString in policyStrings {
            let fields = policyString.components(separatedBy: "|")
            
            // Minimum 6 fields required, 7th (iconURL) is optional
            guard fields.count >= 6 else {
                print("WARNING: Invalid policy format (expected 6+ fields, got \(fields.count)): \(policyString)")
                continue
            }
            
            let policyUUID = fields[0]
            let trigger = fields[1]
            let name = fields[2]
            let description = fields[3]
            let category = fields[4]
            let statusString = fields[5]
            let iconURL: String? = fields.count > 6 ? fields[6] : nil  // NEW: Optional 7th field
            
            // Determine fallback icon based on category
            let icon: String
            switch category.lowercased() {
            case "system":
                icon = "cpu"
            case "security":
                icon = "shield.fill"
            case "application":
                icon = "app.fill"
            case "configuration":
                icon = "gearshape.fill"
            default:
                icon = "doc.fill"
            }
            
            let status: ItemStatus
            let progress: Double
            
            switch statusString.lowercased() {
            case "previously_installed":
                status = .completed
                progress = 1.0
            case "installing":
                status = .installing
                progress = 0.0
            case "completed":
                status = .completed
                progress = 1.0
            case "failed":
                status = .failed
                progress = 0.0
            default:
                status = .pending
                progress = 0.0
            }
            
            let item = InstallationItem(
                policyUUID: policyUUID,
                trigger: trigger,
                name: name,
                description: description,
                icon: icon,
                iconURL: iconURL,  // NEW: Include icon URL
                status: status,
                progress: progress
            )
            
            items.append(item)
            print("DEBUG: Parsed policy - UUID: \(policyUUID), Name: \(name), Status: \(statusString), IconURL: \(iconURL ?? "none")")
        }
        
        return items
    }
}
