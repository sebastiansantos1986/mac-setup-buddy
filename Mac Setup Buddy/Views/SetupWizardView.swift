//
//  SetupWizardView.swift
//  Mac Setup Buddy
//
//  Post-authentication setup wizard that guides users through:
//  - Opening required apps (Jamf Connect, Company Portal, etc.)
//  - Running JAMF policies
//  - Executing scripts
//  - Storing credentials in Keychain
//
//  Created: December 2025
//

import SwiftUI
import AppKit
import Combine

// MARK: - Setup Step Status
enum SetupStepStatus {
    case pending
    case current
    case inProgress
    case completed
    case skipped
    case failed
}

// MARK: - Setup Step Model
struct SetupStepModel: Identifiable {
    let id: String
    let config: SetupStepConfig
    var status: SetupStepStatus = .pending
    var errorMessage: String?
}

// MARK: - Setup Wizard View Model
@MainActor
class SetupWizardViewModel: ObservableObject {
    @Published var steps: [SetupStepModel] = []
    @Published var currentStepIndex: Int = 0
    @Published var isComplete: Bool = false
    @Published var isProcessing: Bool = false
    @Published var statusMessage: String = ""
    
    let configuration: SetupConfiguration
    let userCredentials: (username: String, password: String, fullName: String)
    
    init(configuration: SetupConfiguration, username: String, password: String, fullName: String) {
        self.configuration = configuration
        self.userCredentials = (username, password, fullName)
        loadSteps()
    }
    
    private func loadSteps() {
        guard let stepConfigs = configuration.setupSteps else {
            isComplete = true
            return
        }
        
        // Convert configs to models and check app availability
        steps = stepConfigs.compactMap { config in
            // Check if app exists (for app type steps)
            if config.type == .app, config.skipIfMissing {
                if let appPath = config.action?.appPath,
                   !FileManager.default.fileExists(atPath: appPath) {
                    // Skip this step - app not installed
                    return nil
                }
            }
            
            return SetupStepModel(id: config.id, config: config)
        }
        
        // Set first step as current
        if !steps.isEmpty {
            steps[0].status = .current
        } else {
            isComplete = true
        }
    }
    
    // Execute current step
    func executeCurrentStep() async {
        guard currentStepIndex < steps.count else { return }
        
        isProcessing = true
        steps[currentStepIndex].status = .inProgress
        
        let step = steps[currentStepIndex]
        
        switch step.config.type {
        case .app:
            await executeAppStep(step)
        case .policy:
            await executePolicyStep(step)
        case .script:
            await executeScriptStep(step)
        case .url:
            await executeUrlStep(step)
        case .keychain:
            await executeKeychainStep(step)
        case .wait:
            await executeWaitStep(step)
        }
    }
    
    // Mark current step as done and advance
    func completeCurrentStep() {
        guard currentStepIndex < steps.count else { return }
        
        steps[currentStepIndex].status = .completed
        isProcessing = false
        
        advanceToNextStep()
    }
    
    func skipCurrentStep() {
        guard currentStepIndex < steps.count else { return }
        
        steps[currentStepIndex].status = .skipped
        isProcessing = false
        
        advanceToNextStep()
    }
    
    private func advanceToNextStep() {
        currentStepIndex += 1
        
        if currentStepIndex >= steps.count {
            isComplete = true
            runFinalPolicy()
        } else {
            steps[currentStepIndex].status = .current
            
            // Auto-advance if configured
            if steps[currentStepIndex].config.autoAdvance {
                Task {
                    await executeCurrentStep()
                }
            }
        }
    }
    
    // MARK: - Step Executors
    
    private func executeAppStep(_ step: SetupStepModel) async {
        guard let appPath = step.config.action?.appPath else {
            completeCurrentStep()
            return
        }
        
        statusMessage = "Opening \(step.config.title)..."
        
        let url = URL(fileURLWithPath: appPath)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        
        do {
            try await NSWorkspace.shared.openApplication(at: url, configuration: config)
            statusMessage = "Please complete setup in \(step.config.title)"
            // Don't auto-complete - user must click "Done"
        } catch {
            print("Failed to open app: \(error)")
            // Try alternative method
            NSWorkspace.shared.open(url)
        }
        
        isProcessing = false
    }
    
    private func executePolicyStep(_ step: SetupStepModel) async {
        guard let trigger = step.config.action?.policyTrigger ?? step.config.action?.policyId else {
            completeCurrentStep()
            return
        }
        
        statusMessage = "Running policy: \(step.config.title)..."
        
        let jamfPath = configuration.policies?.jamfBinaryPath ?? "/usr/local/bin/jamf"
        
        // Run JAMF policy
        let process = Process()
        process.executableURL = URL(fileURLWithPath: jamfPath)
        process.arguments = ["policy", "-event", trigger]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                statusMessage = "\(step.config.title) completed"
                if step.config.autoAdvance {
                    completeCurrentStep()
                }
            } else {
                steps[currentStepIndex].status = .failed
                steps[currentStepIndex].errorMessage = "Policy failed with exit code: \(process.terminationStatus)"
                isProcessing = false
            }
        } catch {
            steps[currentStepIndex].status = .failed
            steps[currentStepIndex].errorMessage = error.localizedDescription
            isProcessing = false
        }
    }
    
    private func executeScriptStep(_ step: SetupStepModel) async {
        guard let scriptContent = step.config.action?.scriptContent ?? loadScript(from: step.config.action?.scriptPath) else {
            completeCurrentStep()
            return
        }
        
        statusMessage = "Running: \(step.config.title)..."
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", scriptContent]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                statusMessage = "\(step.config.title) completed"
                if step.config.autoAdvance {
                    completeCurrentStep()
                }
            } else {
                steps[currentStepIndex].status = .failed
                steps[currentStepIndex].errorMessage = "Script failed"
                isProcessing = false
            }
        } catch {
            steps[currentStepIndex].status = .failed
            steps[currentStepIndex].errorMessage = error.localizedDescription
            isProcessing = false
        }
    }
    
    private func loadScript(from path: String?) -> String? {
        guard let path = path else { return nil }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }
    
    private func executeUrlStep(_ step: SetupStepModel) async {
        guard let urlString = step.config.action?.url,
              let url = URL(string: urlString) else {
            completeCurrentStep()
            return
        }
        
        statusMessage = "Opening URL..."
        NSWorkspace.shared.open(url)
        
        isProcessing = false
    }
    
    private func executeKeychainStep(_ step: SetupStepModel) async {
        statusMessage = "Saving credentials to Keychain..."
        
        let service = step.config.action?.keychainService ?? "com.sebastiansantos.mac-setup-buddy"
        
        // Store credentials in Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: userCredentials.username,
            kSecValueData as String: userCredentials.password.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Delete existing if present
        SecItemDelete(query as CFDictionary)
        
        // Add new
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            statusMessage = "Credentials saved"
            completeCurrentStep()
        } else {
            steps[currentStepIndex].status = .failed
            steps[currentStepIndex].errorMessage = "Failed to save credentials (error: \(status))"
            isProcessing = false
        }
    }
    
    private func executeWaitStep(_ step: SetupStepModel) async {
        let seconds = step.config.action?.waitSeconds ?? 5
        
        for i in (0...seconds).reversed() {
            statusMessage = "Waiting... \(i) seconds"
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        
        completeCurrentStep()
    }
    
    private func runFinalPolicy() {
        guard let trigger = configuration.policies?.finalPolicy else { return }
        
        let jamfPath = configuration.policies?.jamfBinaryPath ?? "/usr/local/bin/jamf"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: jamfPath)
        process.arguments = ["policy", "-event", trigger]
        
        try? process.run()
    }
}

// MARK: - Setup Wizard View
struct SetupWizardView: View {
    @StateObject var viewModel: SetupWizardViewModel
    let onComplete: () -> Void
    
    private let brandPrimaryColor = Color(red: 0.08, green: 0.15, blue: 0.35)
    private let brandAccentColor = Color(red: 0.25, green: 0.45, blue: 0.85)
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.18),
                    Color(red: 0.08, green: 0.12, blue: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if viewModel.isComplete {
                completionView
            } else {
                wizardContent
            }
        }
    }
    
    private var wizardContent: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Spacer()
            
            // Main content
            HStack(spacing: 40) {
                // Step list (sidebar)
                stepsList
                
                // Current step detail
                currentStepDetail
            }
            .padding(.horizontal, 60)
            
            Spacer()
            
            // Footer with progress
            footer
        }
    }
    
    private var header: some View {
        HStack {
            Image(systemName: "shield.checkered")
                .font(.system(size: 28))
                .foregroundColor(brandAccentColor)
            
            Text("Device Setup")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            Text("Step \(viewModel.currentStepIndex + 1) of \(viewModel.steps.count)")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 24)
        .background(Color.white.opacity(0.05))
    }
    
    private var stepsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(viewModel.steps.enumerated()), id: \.element.id) { index, step in
                stepRow(step: step, index: index)
            }
        }
        .frame(width: 280)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func stepRow(step: SetupStepModel, index: Int) -> some View {
        HStack(spacing: 16) {
            // Status icon
            ZStack {
                Circle()
                    .fill(stepBackgroundColor(for: step.status))
                    .frame(width: 36, height: 36)
                
                stepIcon(for: step.status, config: step.config)
            }
            
            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(step.config.title)
                    .font(.system(size: 14, weight: step.status == .current ? .semibold : .regular))
                    .foregroundColor(step.status == .current ? .white : .white.opacity(0.7))
                
                if step.status == .failed, let error = step.errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .opacity(step.status == .pending ? 0.5 : 1.0)
    }
    
    private func stepBackgroundColor(for status: SetupStepStatus) -> Color {
        switch status {
        case .pending: return Color.white.opacity(0.1)
        case .current: return brandAccentColor.opacity(0.3)
        case .inProgress: return brandAccentColor
        case .completed: return Color.green.opacity(0.8)
        case .skipped: return Color.gray.opacity(0.5)
        case .failed: return Color.red.opacity(0.8)
        }
    }
    
    @ViewBuilder
    private func stepIcon(for status: SetupStepStatus, config: SetupStepConfig) -> some View {
        switch status {
        case .pending:
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                .frame(width: 20, height: 20)
        case .current:
            Image(systemName: config.icon)
                .font(.system(size: 16))
                .foregroundColor(.white)
        case .inProgress:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.7)
        case .completed:
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        case .skipped:
            Image(systemName: "arrow.right")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
        case .failed:
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private var currentStepDetail: some View {
        VStack(spacing: 24) {
            if viewModel.currentStepIndex < viewModel.steps.count {
                let step = viewModel.steps[viewModel.currentStepIndex]
                
                // Icon
                ZStack {
                    Circle()
                        .fill(step.config.iconSwiftUIColor.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: step.config.icon)
                        .font(.system(size: 44))
                        .foregroundColor(step.config.iconSwiftUIColor)
                }
                
                // Title
                Text(step.config.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                // Description
                if let description = step.config.description {
                    Text(description)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: 400)
                }
                
                // Status message
                if !viewModel.statusMessage.isEmpty {
                    Text(viewModel.statusMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 8)
                }
                
                // Buttons
                HStack(spacing: 16) {
                    if !step.config.required {
                        Button(action: { viewModel.skipCurrentStep() }) {
                            Text("Skip")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(viewModel.isProcessing)
                    }
                    
                    if viewModel.isProcessing && step.status == .inProgress {
                        // Show "Done" button for app steps
                        if step.config.type == .app {
                            Button(action: { viewModel.completeCurrentStep() }) {
                                Text("Done")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 14)
                                    .background(Color.green)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    } else {
                        Button(action: {
                            Task {
                                await viewModel.executeCurrentStep()
                            }
                        }) {
                            HStack(spacing: 8) {
                                if viewModel.isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.7)
                                }
                                Text(step.config.buttonText)
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 14)
                            .background(brandAccentColor)
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(viewModel.isProcessing)
                    }
                }
                .padding(.top, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var footer: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(brandAccentColor)
                        .frame(
                            width: geometry.size.width * progressValue,
                            height: 8
                        )
                        .animation(.easeInOut, value: progressValue)
                }
            }
            .frame(height: 8)
            
            Text("\(Int(progressValue * 100))% complete")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.02))
    }
    
    private var progressValue: Double {
        guard !viewModel.steps.isEmpty else { return 1.0 }
        let completed = viewModel.steps.filter { $0.status == .completed || $0.status == .skipped }.count
        return Double(completed) / Double(viewModel.steps.count)
    }
    
    private var completionView: some View {
        VStack(spacing: 32) {
            // Success icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
            }
            
            // Title
            Text(viewModel.configuration.completion?.title ?? "Setup Complete!")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            // Message
            Text(viewModel.configuration.completion?.message ?? "Your Mac is now configured and ready to use.")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 500)
            
            // Complete button
            Button(action: onComplete) {
                Text("Get Started")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 16)
                    .background(brandAccentColor)
                    .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 16)
        }
        .padding(60)
    }
}

// MARK: - Preview
