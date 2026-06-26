//
//  NetworkMonitor.swift
//  Mac Setup Buddy
//
//  Network connectivity monitoring for enterprise deployments
//

import Foundation
import Network
import SwiftUI
import Combine

// MARK: - Network Monitor Class
/// Monitors network connectivity and publishes status changes
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected: Bool = true
    @Published var connectionType: ConnectionType = .unknown
    @Published var isExpensive: Bool = false  // Cellular/hotspot
    @Published var lastChecked: Date = Date()
    
    // Connection history for diagnostics
    @Published var connectionHistory: [ConnectionEvent] = []
    
    enum ConnectionType: String {
        case wifi = "Wi-Fi"
        case ethernet = "Ethernet"
        case cellular = "Cellular"
        case unknown = "Unknown"
    }
    
    struct ConnectionEvent: Identifiable {
        let id = UUID()
        let timestamp: Date
        let wasConnected: Bool
        let connectionType: ConnectionType
        
        var formattedTime: String {
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            return formatter.string(from: timestamp)
        }
    }
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? true
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
                self?.lastChecked = Date()
                
                // Determine connection type
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .ethernet
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else {
                    self?.connectionType = .unknown
                }
                
                // Log connection changes
                if let self = self, wasConnected != self.isConnected {
                    let event = ConnectionEvent(
                        timestamp: Date(),
                        wasConnected: self.isConnected,
                        connectionType: self.connectionType
                    )
                    self.connectionHistory.append(event)
                    
                    // Keep only last 20 events
                    if self.connectionHistory.count > 20 {
                        self.connectionHistory.removeFirst()
                    }
                    
                    print("Network status changed: \(self.isConnected ? "Connected" : "Disconnected") via \(self.connectionType.rawValue)")
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    /// Check if we can reach a specific host
    func checkHost(_ host: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: host) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    completion(httpResponse.statusCode == 200)
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    /// Get diagnostic info for error reports
    func getDiagnosticInfo() -> String {
        var info = "=== Network Diagnostics ===\n"
        info += "Connected: \(isConnected ? "Yes" : "No")\n"
        info += "Connection Type: \(connectionType.rawValue)\n"
        info += "Expensive Connection: \(isExpensive ? "Yes" : "No")\n"
        info += "Last Checked: \(lastChecked)\n"
        info += "\n=== Connection History ===\n"
        
        for event in connectionHistory.suffix(10) {
            let status = event.wasConnected ? "Connected" : "Disconnected"
            info += "[\(event.formattedTime)] \(status) via \(event.connectionType.rawValue)\n"
        }
        
        return info
    }
}

// MARK: - Network Status Banner View
/// Displays a banner when network connectivity is lost
struct NetworkStatusBanner: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @State private var isAnimating = false
    @State private var showDetails = false
    
    var body: some View {
        if !networkMonitor.isConnected {
            VStack(spacing: 0) {
                HStack(spacing: Theme.Spacing.sm) {
                    // Animated warning icon
                    ZStack {
                        Circle()
                            .fill(Theme.Status.error.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .scaleEffect(isAnimating ? 1.2 : 1.0)
                            .opacity(isAnimating ? 0.5 : 1.0)
                        
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.Status.error)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Network Connection Lost")
                            .font(Theme.Typography.captionBold())
                            .foregroundColor(Theme.Text.primary)
                        
                        Text("Installation paused. Waiting for reconnection...")
                            .font(Theme.Typography.small())
                            .foregroundColor(Theme.Text.secondary)
                    }
                    
                    Spacer()
                    
                    // Retry indicator
                    HStack(spacing: 4) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.Status.warning))
                            .scaleEffect(0.7)
                        
                        Text("Retrying...")
                            .font(Theme.Typography.small())
                            .foregroundColor(Theme.Status.warning)
                    }
                    
                    // Details button
                    Button(action: { showDetails.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.Text.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(Theme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                        .fill(Theme.Status.error.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                .stroke(Theme.Status.error.opacity(0.3), lineWidth: 1)
                        )
                )
                
                // Expandable details
                if showDetails {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Troubleshooting Tips:")
                            .font(Theme.Typography.captionBold())
                            .foregroundColor(Theme.Text.primary)
                        
                        TroubleshootingRow(icon: "wifi", text: "Check your Wi-Fi connection")
                        TroubleshootingRow(icon: "cable.connector", text: "Verify ethernet cable is connected")
                        TroubleshootingRow(icon: "arrow.clockwise", text: "Try restarting your router")
                        TroubleshootingRow(icon: "person.fill.questionmark", text: "Contact IT if issue persists")
                    }
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Background.card)
                    .cornerRadius(Theme.CornerRadius.small)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(Theme.Animation.smooth, value: showDetails)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }
}

struct TroubleshootingRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Theme.Text.tertiary)
                .frame(width: 16)
            
            Text(text)
                .font(Theme.Typography.small())
                .foregroundColor(Theme.Text.secondary)
        }
    }
}

// MARK: - Network Check View
/// Pre-flight network check before starting installations
struct NetworkCheckView: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @State private var checkingHosts = true
    @State private var hostResults: [(host: String, reachable: Bool)] = []
    @State private var allPassed = false
    
    let hostsToCheck: [String]
    let onComplete: (Bool) -> Void
    
    init(hosts: [String] = ["https://www.apple.com", "https://jamf.com"], onComplete: @escaping (Bool) -> Void) {
        self.hostsToCheck = hosts
        self.onComplete = onComplete
    }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (allPassed ? Theme.Status.success : Theme.Brand.primary).opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Circle()
                    .fill(allPassed ? Theme.Gradients.success : Theme.Gradients.primaryButton)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: allPassed ? "checkmark.circle" : "network")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(Theme.Text.primary)
                    )
            }
            
            // Title
            VStack(spacing: Theme.Spacing.xs) {
                Text(checkingHosts ? "Checking Network..." : (allPassed ? "Network Ready" : "Connection Issues"))
                    .font(Theme.Typography.title2())
                    .foregroundColor(Theme.Text.primary)
                
                Text(checkingHosts ? "Verifying connectivity to required services" : (allPassed ? "All services reachable" : "Some services are unreachable"))
                    .font(Theme.Typography.body())
                    .foregroundColor(Theme.Text.secondary)
            }
            
            // Connection status
            VStack(spacing: Theme.Spacing.sm) {
                HStack {
                    Image(systemName: networkMonitor.isConnected ? "wifi" : "wifi.slash")
                        .foregroundColor(networkMonitor.isConnected ? Theme.Status.success : Theme.Status.error)
                    
                    Text(networkMonitor.connectionType.rawValue)
                        .font(Theme.Typography.bodyBold())
                        .foregroundColor(Theme.Text.primary)
                    
                    Spacer()
                    
                    Text(networkMonitor.isConnected ? "Connected" : "Disconnected")
                        .font(Theme.Typography.caption())
                        .foregroundColor(networkMonitor.isConnected ? Theme.Status.success : Theme.Status.error)
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.Background.card)
                .cornerRadius(Theme.CornerRadius.small)
                
                // Host check results
                if !checkingHosts {
                    ForEach(hostResults, id: \.host) { result in
                        HStack {
                            Image(systemName: result.reachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.reachable ? Theme.Status.success : Theme.Status.error)
                            
                            Text(result.host.replacingOccurrences(of: "https://", with: ""))
                                .font(Theme.Typography.caption())
                                .foregroundColor(Theme.Text.secondary)
                            
                            Spacer()
                            
                            Text(result.reachable ? "Reachable" : "Unreachable")
                                .font(Theme.Typography.small())
                                .foregroundColor(result.reachable ? Theme.Status.success : Theme.Status.error)
                        }
                        .padding(Theme.Spacing.xs)
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .glassCard()
            
            // Action buttons
            if !checkingHosts {
                HStack(spacing: Theme.Spacing.md) {
                    if !allPassed {
                        Button(action: { runChecks() }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry")
                            }
                            .font(Theme.Typography.bodyBold())
                            .foregroundColor(Theme.Text.secondary)
                            .padding(.horizontal, Theme.Spacing.xl)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.pill)
                                    .stroke(Theme.Border.primary, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Button(action: { onComplete(allPassed) }) {
                        HStack {
                            Text(allPassed ? "Continue" : "Continue Anyway")
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        .font(Theme.Typography.bodyBold())
                        .foregroundColor(Theme.Text.primary)
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Theme.Gradients.primaryButton)
                        .cornerRadius(Theme.CornerRadius.pill)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(Theme.Spacing.xxl)
        .onAppear {
            runChecks()
        }
    }
    
    private func runChecks() {
        checkingHosts = true
        hostResults = []
        
        let group = DispatchGroup()
        var results: [(String, Bool)] = []
        
        for host in hostsToCheck {
            group.enter()
            networkMonitor.checkHost(host) { reachable in
                results.append((host, reachable))
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            hostResults = results
            allPassed = results.allSatisfy { $0.1 }
            checkingHosts = false
        }
    }
}

// MARK: - Preview

