//
//  FullscreenLockView.swift
//  Mac Setup Buddy
//
//  Created by Sebastian Santos on 10/3/25.
//

import SwiftUI
import AppKit

struct FullscreenLockView: View {
    let config: CommandLineConfig
    @State private var isScanning = true
    
    var body: some View {
        ZStack {
            backgroundView
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                
                Text(config.title ?? "Mac Setup Buddy")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                
                Text(config.message ?? "Please wait while we verify compliance...")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                
                if isScanning {
                    ProgressView("Scanning...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Button("Continue") {
                        NSApplication.shared.terminate(nil)
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                isScanning = false
            }
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch config.backgroundStyle {
        case .blur:
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)

        case .solid:
            Color.black
                .edgesIgnoringSafeArea(.all)

        case .transparent:
            Color.clear
                .edgesIgnoringSafeArea(.all)

        case .none:
            Color.black
                .edgesIgnoringSafeArea(.all)
        }
    }
}

