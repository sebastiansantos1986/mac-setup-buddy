//
//  BannerView.swift
//  Mac Setup Buddy
//
//  Created by Sebastian Santos on October 4, 2025
//

//
//  BannerView.swift
//  Mac Setup Buddy
//
//  Created by Sebastian Santos on 10/4/25.
//

// BANNER IMAGE VIEW FILE
// This view handles banner images from local files or URLs
// Works with blur backgrounds to create layered visual effects

import SwiftUI
import AppKit

struct BannerView: View {
    let imagePath: String?  // Can be local file path or URL string
    let height: CGFloat
    let contentMode: ContentMode
    
    @State private var nsImage: NSImage? = nil
    @State private var isLoading: Bool = false
    @State private var loadError: Bool = false
    
    // Default initializer
    init(imagePath: String? = nil,
         height: CGFloat = 150,
         contentMode: ContentMode = .fit) {
        self.imagePath = imagePath
        self.height = height
        self.contentMode = contentMode
    }
    
    var body: some View {
        ZStack {
            // BLUR COMPATIBILITY: Banner sits above blur background
            // The banner image will be visible on top of any blur effect
            
            if let nsImage = nsImage {
                // Successfully loaded image
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(height: height)
                    .clipped()
            } else if isLoading {
                // Loading state with progress indicator
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.Brand.primary))
                        .scaleEffect(0.8)
                    Text("Loading banner...")
                        .font(.caption)
                        .foregroundColor(Theme.Text.secondary)
                }
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .background(Theme.Gradients.banner)
            } else if loadError {
                // Error state
                VStack(spacing: 10) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.Text.tertiary)
                    Text("Banner image not found")
                        .font(.caption)
                        .foregroundColor(Theme.Text.secondary)
                }
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .background(Theme.Gradients.banner)
            } else {
                // Default gradient banner if no image specified
                // BLUR DESIGN: Default gradient works well with blur
                defaultBanner
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: imagePath) { _ in
            loadImage()
        }
    }
    
    // Default gradient banner when no image is provided
    var defaultBanner: some View {
        Image("DefaultBanner")
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
    }
    
    // MARK: - Image Loading
    private func loadImage() {
        guard let imagePath = imagePath, !imagePath.isEmpty else {
            // No image path provided, use default banner
            self.nsImage = nil
            self.loadError = false
            self.isLoading = false
            return
        }
        
        // Reset states
        self.isLoading = true
        self.loadError = false
        self.nsImage = nil
        
        // Check if it's a URL or local file
        if imagePath.lowercased().starts(with: "http://") ||
           imagePath.lowercased().starts(with: "https://") {
            // Load from URL
            loadImageFromURL(imagePath)
        } else {
            // Load from local file
            loadImageFromFile(imagePath)
        }
    }
    
    // Load image from URL
    private func loadImageFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            self.loadError = true
            self.isLoading = false
            return
        }
        
        // ASYNC LOADING: Prevents blocking the UI/blur effects
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let data = data, let image = NSImage(data: data) {
                    self.nsImage = image
                    self.loadError = false
                } else {
                    self.loadError = true
                }
                self.isLoading = false
            }
        }.resume()
    }
    
    // Load image from local file
    private func loadImageFromFile(_ path: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var finalPath = path
            
            // Handle different path formats
            if !path.starts(with: "/") {
                // Relative path - try to find in bundle
                if let bundlePath = Bundle.main.path(forResource: path, ofType: nil) {
                    finalPath = bundlePath
                } else if let bundlePath = Bundle.main.path(forResource: path, ofType: "png") {
                    finalPath = bundlePath
                } else if let bundlePath = Bundle.main.path(forResource: path, ofType: "jpg") {
                    finalPath = bundlePath
                } else if let bundlePath = Bundle.main.path(forResource: path, ofType: "jpeg") {
                    finalPath = bundlePath
                }
            }
            
            // Expand tilde for home directory
            finalPath = NSString(string: finalPath).expandingTildeInPath
            
            // Try to load the image
            let image = NSImage(contentsOfFile: finalPath)
            
            DispatchQueue.main.async {
                if let image = image {
                    self.nsImage = image
                    self.loadError = false
                } else {
                    self.loadError = true
                }
                self.isLoading = false
            }
        }
    }
}

// MARK: - Preview
struct BannerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Default banner (no image)
            BannerView()
                .frame(width: 600)
            
            // With local file (would need actual file)
            BannerView(imagePath: "/Library/Management/Banner/Mac Setup Buddy_setup_banner.png", height: 200)
                .frame(width: 600)
        
            
            // With URL
            BannerView(
                imagePath: "https://example.com/banner.jpg",
                height: 180,
                contentMode: .fill
            )
            .frame(width: 600)
        }
        .background(Color.black)
        // PREVIEW NOTE: Test with blur by running app with -background blur
    }
}
