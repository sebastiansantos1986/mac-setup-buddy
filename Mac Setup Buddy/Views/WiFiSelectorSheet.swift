//
//  WiFiSelectorSheet.swift
//  Mac Setup Buddy
//
//  iOS-style WiFi network selector with:
//  - WiFi toggle
//  - Available networks list
//  - Signal strength indicators
//  - Secure network lock icons
//  - Connected checkmark
//  - Join button for password entry
//
//  Created: December 2025
//

import SwiftUI
import CoreWLAN
import AppKit
import CoreLocation
import Combine

// MARK: - WiFi Network Model
struct WiFiNetworkItem: Identifiable, Hashable {
    let id = UUID()
    let ssid: String
    let signalStrength: Int      // 0-100 (converted from RSSI)
    let isSecure: Bool
    let isConnected: Bool
    let rssi: Int                // Raw RSSI value
    let securityType: String     // WPA2, WPA3, etc.
    
    var signalBars: Int {
        switch signalStrength {
        case 75...100: return 3
        case 50..<75: return 2
        case 25..<50: return 1
        default: return 0
        }
    }
}

// MARK: - Location Manager for WiFi Scanning
class WiFiLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isAuthorized: Bool = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        authorizationStatus = locationManager.authorizationStatus
        updateAuthorizationStatus()
    }
    
    func requestPermission() {
        // On macOS, we need to request "when in use" authorization
        if #available(macOS 11.0, *) {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        updateAuthorizationStatus()
    }
    
    // Legacy delegate method for older macOS versions
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        updateAuthorizationStatus()
    }
    
    private func updateAuthorizationStatus() {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            isAuthorized = true
        case .authorized:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }
}

// MARK: - WiFi Selector Sheet
struct WiFiSelectorSheet: View {
    @Binding var isPresented: Bool
    var onNetworkSelected: ((String) -> Void)?
    
    @StateObject private var locationManager = WiFiLocationManager()
    
    @State private var isWiFiEnabled: Bool = true
    @State private var availableNetworks: [WiFiNetworkItem] = []
    @State private var isScanning: Bool = false
    @State private var selectedNetwork: WiFiNetworkItem? = nil
    @State private var showPasswordPrompt: Bool = false
    @State private var networkPassword: String = ""
    @State private var isConnecting: Bool = false
    @State private var connectionError: String? = nil
    @State private var currentSSID: String? = nil
    @State private var scanError: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with WiFi toggle
            header
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Network list
            if isWiFiEnabled {
                if !locationManager.isAuthorized && availableNetworks.isEmpty {
                    locationPermissionView
                } else {
                    networkList
                }
            } else {
                wifiDisabledView
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Footer buttons
            footer
        }
        .frame(width: 340, height: 450)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.15, green: 0.15, blue: 0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
        .onAppear {
            checkWiFiStatus()
            scanForNetworks()
        }
        .onChange(of: locationManager.isAuthorized) { authorized in
            if authorized {
                scanForNetworks()
            }
        }
        .sheet(isPresented: $showPasswordPrompt) {
            passwordPromptSheet
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Wi-Fi Connection")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(statusText)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // WiFi Toggle
            Toggle("", isOn: $isWiFiEnabled)
                .toggleStyle(SwitchToggleStyle(tint: Color.blue))
                .labelsHidden()
                .onChange(of: isWiFiEnabled) { newValue in
                    toggleWiFi(enabled: newValue)
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var statusText: String {
        if isScanning {
            return "Scanning..."
        } else if let ssid = currentSSID {
            return "Connected to \(ssid)"
        } else {
            return "Select network"
        }
    }
    
    // MARK: - Location Permission View
    
    private var locationPermissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.circle")
                .font(.system(size: 40))
                .foregroundColor(.blue.opacity(0.8))
            
            Text("Location Permission Required")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            
            Text("macOS requires Location Services to scan for WiFi networks.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Button(action: {
                locationManager.requestPermission()
            }) {
                Text("Enable Location Services")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { openSystemWiFiSettings() }) {
                Text("Or use System WiFi Settings")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Network List
    
    private var networkList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isScanning && availableNetworks.isEmpty {
                    scanningView
                } else if availableNetworks.isEmpty {
                    emptyView
                } else {
                    ForEach(availableNetworks) { network in
                        networkRow(network)
                        
                        if network.id != availableNetworks.last?.id {
                            Divider()
                                .background(Color.white.opacity(0.05))
                                .padding(.leading, 20)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 280)
    }
    
    private func networkRow(_ network: WiFiNetworkItem) -> some View {
        Button(action: {
            selectNetwork(network)
        }) {
            HStack(spacing: 12) {
                // Signal strength icon
                wifiSignalIcon(for: network)
                
                // Network name
                Text(network.ssid)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                // Secure icon
                if network.isSecure {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                // Connected checkmark
                if network.isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                selectedNetwork?.id == network.id
                    ? Color.blue.opacity(0.3)
                    : Color.clear
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func wifiSignalIcon(for network: WiFiNetworkItem) -> some View {
        Image(systemName: wifiIconName(for: network.signalBars))
            .font(.system(size: 15))
            .foregroundColor(network.isConnected ? .blue : .white.opacity(0.7))
    }
    
    private func wifiIconName(for bars: Int) -> String {
        switch bars {
        case 3: return "wifi"
        case 2: return "wifi"
        case 1: return "wifi.exclamationmark"
        default: return "wifi.slash"
        }
    }
    
    private var scanningView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)
            Text("Scanning for networks...")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No networks found")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            if let error = scanError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.orange.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            VStack(spacing: 10) {
                Button(action: { scanForNetworks() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                        Text("Scan Again")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { openSystemWiFiSettings() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gear")
                            .font(.system(size: 12))
                        Text("Open Wi-Fi Settings")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
    
    private func openSystemWiFiSettings() {
        // Try macOS 13+ System Settings first
        if let url = URL(string: "x-apple.systempreferences:com.apple.wifi-settings-extension") {
            if NSWorkspace.shared.open(url) { return }
        }
        // Try Network settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
            if NSWorkspace.shared.open(url) { return }
        }
        // Fallback to older System Preferences
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private var wifiDisabledView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))
            Text("Wi-Fi is turned off")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            Text("Turn on Wi-Fi to see available networks")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack(spacing: 16) {
            // Close button
            Button(action: { isPresented = false }) {
                Text("Close")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Join button
            Button(action: joinSelectedNetwork) {
                HStack(spacing: 6) {
                    if isConnecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    }
                    Text(isConnecting ? "Joining..." : "Join")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    selectedNetwork != nil && !isConnecting
                        ? Color.blue
                        : Color.blue.opacity(0.4)
                )
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(selectedNetwork == nil || isConnecting)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Password Prompt Sheet
    
    private var passwordPromptSheet: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "wifi.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text(selectedNetwork?.ssid ?? "Network")
                    .font(.system(size: 18, weight: .semibold))
                
                Text("Enter the password for this network")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            // Password field
            SecureField("Password", text: $networkPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 250)
            
            // Error message
            if let error = connectionError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
            
            // Buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    networkPassword = ""
                    connectionError = nil
                    showPasswordPrompt = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Join") {
                    connectToNetwork()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(networkPassword.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 320)
    }
    
    // MARK: - WiFi Functions
    
    private func checkWiFiStatus() {
        if let interface = CWWiFiClient.shared().interface() {
            isWiFiEnabled = interface.powerOn()
            currentSSID = interface.ssid()
        }
    }
    
    private func toggleWiFi(enabled: Bool) {
        guard let interface = CWWiFiClient.shared().interface() else { return }
        
        do {
            try interface.setPower(enabled)
            if enabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    scanForNetworks()
                }
            } else {
                availableNetworks = []
            }
        } catch {
            print("Failed to toggle WiFi: \(error)")
        }
    }
    
    private func scanForNetworks() {
        guard isWiFiEnabled else { return }
        
        isScanning = true
        scanError = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            var networks: [WiFiNetworkItem] = []
            
            if let interface = CWWiFiClient.shared().interface() {
                // First, get the currently connected network (this always works)
                if let currentSSID = interface.ssid() {
                    let rssi = interface.rssiValue()
                    let signalStrength = min(100, max(0, Int(rssi) + 100))
                    
                    // Check security of current network
                    let security = interface.security()
                    let isSecure = security != .none && security != .unknown
                    
                    let connectedNetwork = WiFiNetworkItem(
                        ssid: currentSSID,
                        signalStrength: signalStrength,
                        isSecure: isSecure,
                        isConnected: true,
                        rssi: Int(rssi),
                        securityType: self.securityTypeString(security)
                    )
                    networks.append(connectedNetwork)
                    
                    DispatchQueue.main.async {
                        self.currentSSID = currentSSID
                    }
                }
                
                // Try to scan for other networks
                do {
                    let scanResults = try interface.scanForNetworks(withSSID: nil)
                    let currentSSID = interface.ssid()
                    
                    for network in scanResults {
                        guard let ssid = network.ssid, !ssid.isEmpty else { continue }
                        
                        // Skip if we already have this network (connected one)
                        if ssid == currentSSID { continue }
                        
                        // Determine security type
                        var securityType = "Open"
                        if network.supportsSecurity(.wpa3Personal) || network.supportsSecurity(.wpa3Enterprise) {
                            securityType = "WPA3"
                        } else if network.supportsSecurity(.wpa2Personal) || network.supportsSecurity(.wpa2Enterprise) {
                            securityType = "WPA2"
                        } else if network.supportsSecurity(.wpaPersonal) || network.supportsSecurity(.wpaEnterprise) {
                            securityType = "WPA"
                        } else if network.supportsSecurity(.dynamicWEP) {
                            securityType = "WEP"
                        }
                        
                        let isSecure = securityType != "Open"
                        let rssi = Int(network.rssiValue)
                        let signalStrength = min(100, max(0, rssi + 100))
                        
                        let networkItem = WiFiNetworkItem(
                            ssid: ssid,
                            signalStrength: signalStrength,
                            isSecure: isSecure,
                            isConnected: false,
                            rssi: rssi,
                            securityType: securityType
                        )
                        networks.append(networkItem)
                    }
                } catch let error as NSError {
                    print("WiFi scan error: \(error)")
                    DispatchQueue.main.async {
                        if error.domain == "com.apple.coreWLAN.error" {
                            self.scanError = "Location Services required for scanning"
                        } else {
                            self.scanError = error.localizedDescription
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                // Remove duplicates, sort by: connected first, then signal strength
                var seen = Set<String>()
                self.availableNetworks = networks
                    .filter { seen.insert($0.ssid).inserted }
                    .sorted {
                        if $0.isConnected != $1.isConnected {
                            return $0.isConnected
                        }
                        return $0.signalStrength > $1.signalStrength
                    }
                self.isScanning = false
                
                // Auto-select connected network
                if let connected = self.availableNetworks.first(where: { $0.isConnected }) {
                    self.selectedNetwork = connected
                }
            }
        }
    }
    
    private func securityTypeString(_ security: CWSecurity) -> String {
        switch security {
        case .none: return "Open"
        case .WEP: return "WEP"
        case .wpaPersonal: return "WPA"
        case .wpaPersonalMixed: return "WPA"
        case .wpa2Personal: return "WPA2"
        case .personal: return "WPA2"
        case .dynamicWEP: return "WEP"
        case .wpaEnterprise: return "WPA Enterprise"
        case .wpaEnterpriseMixed: return "WPA Enterprise"
        case .wpa2Enterprise: return "WPA2 Enterprise"
        case .enterprise: return "WPA2 Enterprise"
        case .wpa3Personal: return "WPA3"
        case .wpa3Enterprise: return "WPA3 Enterprise"
        case .wpa3Transition: return "WPA3"
        default: return "Secured"
        }
    }
    
    private func selectNetwork(_ network: WiFiNetworkItem) {
        selectedNetwork = network
        connectionError = nil
    }
    
    private func joinSelectedNetwork() {
        guard let network = selectedNetwork else { return }
        
        if network.isConnected {
            // Already connected
            isPresented = false
            onNetworkSelected?(network.ssid)
            return
        }
        
        if network.isSecure {
            // Show password prompt
            networkPassword = ""
            connectionError = nil
            showPasswordPrompt = true
        } else {
            // Connect to open network
            connectToNetwork()
        }
    }
    
    private func connectToNetwork() {
        guard let network = selectedNetwork else { return }
        
        isConnecting = true
        connectionError = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let interface = CWWiFiClient.shared().interface() else {
                DispatchQueue.main.async {
                    self.connectionError = "WiFi interface not available"
                    self.isConnecting = false
                }
                return
            }
            
            do {
                // Find the network in scan results
                let scanResults = try interface.scanForNetworks(withSSID: network.ssid.data(using: .utf8))
                
                guard let targetNetwork = scanResults.first else {
                    DispatchQueue.main.async {
                        self.connectionError = "Network not found"
                        self.isConnecting = false
                    }
                    return
                }
                
                // Connect with password if secure, nil if open
                let password = network.isSecure ? self.networkPassword : nil
                try interface.associate(to: targetNetwork, password: password)
                
                DispatchQueue.main.async {
                    self.isConnecting = false
                    self.showPasswordPrompt = false
                    self.networkPassword = ""
                    self.currentSSID = network.ssid
                    self.isPresented = false
                    self.onNetworkSelected?(network.ssid)
                }
            } catch {
                DispatchQueue.main.async {
                    self.connectionError = "Failed to connect: \(error.localizedDescription)"
                    self.isConnecting = false
                }
            }
        }
    }
}

// MARK: - Preview

