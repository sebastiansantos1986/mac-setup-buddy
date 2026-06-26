//
//  AsyncIcon.swift
//  Mac Setup Buddy
//
//  Created by Claude - December 2025
//
//  Loads icons from multiple sources:
//  - JAMF cloud URLs (https://use2.ics.services.jamfcloud.com/icon/hash_xxx)
//  - Local file paths (/Library/Management/Icons/app.png)
//  - SF Symbols (shield.fill)
//

import SwiftUI
import AppKit

// MARK: - Async Icon View

struct AsyncIcon: View {
    let source: String  // URL, file path, or SF Symbol name
    let size: CGFloat
    let fallbackSymbol: String
    var fallbackColor: Color = .blue
    
    @State private var loadedImage: NSImage? = nil
    @State private var isLoading = true
    @State private var loadFailed = false
    
    var body: some View {
        Group {
            if let image = loadedImage {
                // Successfully loaded image
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else if isLoading && isURL(source) {
                // Loading state for URLs
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: size, height: size)
            } else {
                // Fallback to SF Symbol
                Image(systemName: loadFailed ? fallbackSymbol : (isSFSymbol(source) ? source : fallbackSymbol))
                    .font(.system(size: size * 0.6, weight: .medium))
                    .foregroundColor(fallbackColor)
                    .frame(width: size, height: size)
            }
        }
        .onAppear {
            loadIcon()
        }
        .onChange(of: source) { _ in
            loadIcon()
        }
    }
    
    private func loadIcon() {
        // Reset state
        loadedImage = nil
        isLoading = true
        loadFailed = false
        
        // Check if it's an SF Symbol
        if isSFSymbol(source) {
            isLoading = false
            return
        }
        
        // Check if it's a URL
        if isURL(source), let url = URL(string: source) {
            loadFromURL(url)
            return
        }
        
        // Check if it's a file path
        if isFilePath(source) {
            loadFromFile(source)
            return
        }
        
        // Unknown source type, use fallback
        isLoading = false
        loadFailed = true
    }
    
    private func loadFromURL(_ url: URL) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let data = data, let image = NSImage(data: data) {
                    loadedImage = image
                } else {
                    loadFailed = true
                    print("Failed to load icon from URL: \(url)")
                }
            }
        }.resume()
    }
    
    private func loadFromFile(_ path: String) {
        isLoading = false
        
        let expandedPath = NSString(string: path).expandingTildeInPath
        
        if let image = NSImage(contentsOfFile: expandedPath) {
            loadedImage = image
        } else {
            loadFailed = true
            print("Failed to load icon from file: \(path)")
        }
    }
    
    private func isURL(_ string: String) -> Bool {
        return string.hasPrefix("http://") || string.hasPrefix("https://")
    }
    
    private func isFilePath(_ string: String) -> Bool {
        return string.hasPrefix("/") || string.hasPrefix("~")
    }
    
    private func isSFSymbol(_ string: String) -> Bool {
        // If it's not a URL or file path, assume it's an SF Symbol
        return !isURL(string) && !isFilePath(string)
    }
}

// MARK: - Icon Cache (Optional optimization)

class IconCache {
    static let shared = IconCache()
    
    private var cache: [String: NSImage] = [:]
    private let queue = DispatchQueue(label: "com.sebastiansantos.iconcache")
    
    private init() {}
    
    func getImage(for key: String) -> NSImage? {
        queue.sync {
            return cache[key]
        }
    }
    
    func setImage(_ image: NSImage, for key: String) {
        queue.async {
            self.cache[key] = image
        }
    }
    
    func clearCache() {
        queue.async {
            self.cache.removeAll()
        }
    }
}

// MARK: - Cached Async Icon (with caching)

struct CachedAsyncIcon: View {
    let source: String
    let size: CGFloat
    let fallbackSymbol: String
    var fallbackColor: Color = .blue
    
    @State private var loadedImage: NSImage? = nil
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = loadedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else if isLoading && isURL(source) {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: size, height: size)
            } else {
                Image(systemName: isSFSymbol(source) ? source : fallbackSymbol)
                    .font(.system(size: size * 0.6, weight: .medium))
                    .foregroundColor(fallbackColor)
                    .frame(width: size, height: size)
            }
        }
        .onAppear {
            loadIcon()
        }
    }
    
    private func loadIcon() {
        // Check cache first
        if let cached = IconCache.shared.getImage(for: source) {
            loadedImage = cached
            isLoading = false
            return
        }
        
        if isSFSymbol(source) {
            isLoading = false
            return
        }
        
        if isURL(source), let url = URL(string: source) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                DispatchQueue.main.async {
                    isLoading = false
                    if let data = data, let image = NSImage(data: data) {
                        IconCache.shared.setImage(image, for: source)
                        loadedImage = image
                    }
                }
            }.resume()
        } else if isFilePath(source) {
            isLoading = false
            let path = NSString(string: source).expandingTildeInPath
            if let image = NSImage(contentsOfFile: path) {
                IconCache.shared.setImage(image, for: source)
                loadedImage = image
            }
        } else {
            isLoading = false
        }
    }
    
    private func isURL(_ s: String) -> Bool { s.hasPrefix("http") }
    private func isFilePath(_ s: String) -> Bool { s.hasPrefix("/") || s.hasPrefix("~") }
    private func isSFSymbol(_ s: String) -> Bool { !isURL(s) && !isFilePath(s) }
}

// MARK: - Preview

