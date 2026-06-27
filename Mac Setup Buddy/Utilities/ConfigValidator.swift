//
//  ConfigValidator.swift
//  Mac Setup Buddy
//
//  Lightweight validation for admin JSON configuration files.
//

import Foundation

struct ConfigValidationResult {
    var errors: [String] = []
    var warnings: [String] = []

    var isValid: Bool {
        errors.isEmpty
    }

    var formattedOutput: String {
        var output: [String] = []
        output.append(isValid ? "Config valid" : "Config invalid")

        if !errors.isEmpty {
            output.append("")
            output.append("Errors:")
            output.append(contentsOf: errors.map { "- \($0)" })
        }

        if !warnings.isEmpty {
            output.append("")
            output.append("Warnings:")
            output.append(contentsOf: warnings.map { "- \($0)" })
        }

        return output.joined(separator: "\n")
    }
}

enum ConfigValidator {
    static func validate(path: String) -> ConfigValidationResult {
        let expandedPath = NSString(string: path).expandingTildeInPath
        var result = ConfigValidationResult()

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            result.errors.append("Config file not found: \(expandedPath)")
            return result
        }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: expandedPath)) else {
            result.errors.append("Could not read config file: \(expandedPath)")
            return result
        }

        do {
            _ = try JSONSerialization.jsonObject(with: data)
        } catch {
            result.errors.append("Invalid JSON: \(error.localizedDescription)")
            return result
        }

        let config: SetupConfiguration
        do {
            config = try JSONDecoder().decode(SetupConfiguration.self, from: data)
        } catch {
            result.errors.append("Config does not match Mac Setup Buddy fields: \(error)")
            return result
        }

        validateBranding(config.branding, result: &result)
        validateUI(config.ui, result: &result)
        validateAuthentication(config.authentication, result: &result)
        validateSetupSteps(config.setupSteps, result: &result)

        return result
    }

    private static func validateBranding(_ branding: BrandingConfig?, result: inout ConfigValidationResult) {
        guard let branding else { return }

        validateHexColor(branding.primaryColor, field: "branding.primaryColor", result: &result)
        validateHexColor(branding.accentColor, field: "branding.accentColor", result: &result)

        validateOptionalFile(branding.logoPath, field: "branding.logoPath", result: &result)
        validateOptionalFile(branding.bannerImagePath, field: "branding.bannerImagePath", result: &result)
        validateOptionalFile(branding.backgroundImagePath, field: "branding.backgroundImagePath", result: &result)
    }

    private static func validateUI(_ ui: UIConfig?, result: inout ConfigValidationResult) {
        guard let ui else { return }

        let validScreens = [
            "welcome", "email", "authentication", "user-authentication",
            "networkcheck", "network-check", "network",
            "credentials", "creds", "sso",
            "login", "credential-login", "jamf-login", "fullscreen-login",
            "aad", "azure", "aad-progress",
            "progress", "install", "installation", "software-deployment",
            "completion", "complete", "done", "setup-complete",
            "notification", "notify", "alert",
            "error", "recovery", "error-recovery"
        ]

        if !validScreens.contains(ui.defaultScreen.lowercased()) {
            result.errors.append("Invalid ui.defaultScreen: \(ui.defaultScreen)")
        }

        if ui.windowWidth < 640 {
            result.warnings.append("ui.windowWidth is very small. Recommended minimum is 640.")
        }

        if ui.windowHeight < 480 {
            result.warnings.append("ui.windowHeight is very small. Recommended minimum is 480.")
        }

        if ui.previewMode {
            result.warnings.append("ui.previewMode is enabled. Disable it before production deployment.")
        }

        if ui.requireNetwork, (ui.networkCheckHosts ?? []).isEmpty {
            result.warnings.append("ui.requireNetwork is enabled without networkCheckHosts. The app will only check local network state.")
        }
    }

    private static func validateAuthentication(_ authentication: AuthenticationConfig?, result: inout ConfigValidationResult) {
        guard let authentication else { return }

        if authentication.oktaDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.errors.append("authentication.oktaDomain cannot be empty.")
        }

        if authentication.sessionTimeout < 1 {
            result.errors.append("authentication.sessionTimeout must be greater than 0.")
        }
    }

    private static func validateSetupSteps(_ steps: [SetupStepConfig]?, result: inout ConfigValidationResult) {
        guard let steps else { return }

        var ids = Set<String>()
        for step in steps {
            if step.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.errors.append("setupSteps contains an empty id.")
            }

            if ids.contains(step.id) {
                result.errors.append("Duplicate setupSteps id: \(step.id)")
            }
            ids.insert(step.id)

            validateHexColor(step.iconColor, field: "setupSteps[\(step.id)].iconColor", result: &result)

            if step.timeout < 1 {
                result.errors.append("setupSteps[\(step.id)].timeout must be greater than 0.")
            }

            if step.type == .app, let appPath = step.action?.appPath {
                validateOptionalFile(appPath, field: "setupSteps[\(step.id)].action.appPath", result: &result)
            }
        }
    }

    private static func validateHexColor(_ color: String, field: String, result: inout ConfigValidationResult) {
        let pattern = /^#[A-Fa-f0-9]{6}$/
        if color.firstMatch(of: pattern) == nil {
            result.errors.append("\(field) must be a 6-digit hex color like #4073d6.")
        }
    }

    private static func validateOptionalFile(_ path: String?, field: String, result: inout ConfigValidationResult) {
        guard let path, !path.isEmpty else { return }

        if path.lowercased().hasPrefix("http://") || path.lowercased().hasPrefix("https://") {
            result.warnings.append("\(field) is a remote URL and cannot be file-checked locally.")
            return
        }

        let expandedPath = NSString(string: path).expandingTildeInPath
        if !FileManager.default.fileExists(atPath: expandedPath) {
            result.warnings.append("\(field) file was not found: \(expandedPath)")
        }
    }
}
