import SwiftUI
import AppKit

struct RAWImageView: View {
    let file: MediaFile
    //    let file: FileInfo
    @State private var image: NSImage?
    @State private var error: String?
    @State private var isLoading = true
    @State private var rawMetadata: RAWMetadata?
    @State private var showExternalViewerOption = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Image viewer or preview
            if let image = image {
                GeometryReader { geometry in
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: geometry.size.width > 0 && image.size.height > 0 ? min(geometry.size.width, geometry.size.height * image.size.width / image.size.height) : 100,
                            height: geometry.size.height > 0 && image.size.width > 0 ? min(geometry.size.height, geometry.size.width * image.size.height / image.size.width) : 100
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.blue.opacity(0.1))
                }
            } else if let error = error {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color(.controlBackgroundColor))
                        .aspectRatio(contentMode: .fit)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 48))
                                    .foregroundColor(.orange)
                                Text("RAW Image Error")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                if showExternalViewerOption {
                                    Button("Open with External Viewer") {
                                        openWithExternalViewer()
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                Button(action: {
                                    NSWorkspace.shared.selectFile(file.fileUrl.path, inFileViewerRootedAtPath: file.fileUrl.deletingLastPathComponent().path)
                                }) {
                                    Label("Show in Finder", systemImage: "folder")
                                }
                                .buttonStyle(.bordered)
                            }
                        )
                }
                .onAppear {
                    print("DEBUG: RAWImageView showing error - \(file.displayName), error: \(error)")
                }
            } else if isLoading {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color(.controlBackgroundColor))
                        .aspectRatio(contentMode: .fit)
                        .overlay(
                            VStack(spacing: 12) {
                                ProgressView("Loading RAW image...")
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("RAW files may take longer to load")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let metadata = rawMetadata {
                                    VStack(spacing: 4) {
                                        Text("Resolution: \(metadata.resolution)")
                                            .font(.caption)
                                        Text("Color Depth: \(metadata.colorDepth)")
                                            .font(.caption)
                                        Text("Format: \(metadata.format)")
                                            .font(.caption)
                                    }
                                    .padding(.top, 8)
                                }
                            }
                        )
                        .cornerRadius(8)
                }
                .onAppear {
                    print("DEBUG: RAWImageView showing loading - \(file.displayName)")
                }
            } else {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color(.controlBackgroundColor))
                        .aspectRatio(contentMode: .fit)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "photo")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("RAW Image Preview")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                if let metadata = rawMetadata {
                                    VStack(spacing: 4) {
                                        Text("Resolution: \(metadata.resolution)")
                                            .font(.caption)
                                        Text("Color Depth: \(metadata.colorDepth)")
                                            .font(.caption)
                                        Text("Format: \(metadata.format)")
                                            .font(.caption)
                                    }
                                    .padding(.vertical, 8)
                                }
                                
                                Button("Open with External Viewer") {
                                    openWithExternalViewer()
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: {
                                    NSWorkspace.shared.selectFile(file.fileUrl.path, inFileViewerRootedAtPath: file.fileUrl.deletingLastPathComponent().path)
                                }) {
                                    Label("Show in Finder", systemImage: "folder")
                                }
                                .buttonStyle(.bordered)
                            }
                        )
                }
                .onAppear {
                    print("DEBUG: RAWImageView showing preview - \(file.displayName)")
                }
            }
        }
        .padding(.all, 10)
        .background(Color.blue.opacity(0.1))
        .onAppear {
            print("DEBUG: RAWImageView appeared for file: \(file.displayName)")
            resetState()
            setupRAWImage()
        }
        .onDisappear {
            print("DEBUG: RAWImageView disappeared for file: \(file.displayName)")
            // MEMORY FIX: Explicitly release image to free memory immediately
            cleanupImage()
        }
    }
    
    private func resetState() {
        print("DEBUG: RAWImageView - Resetting state for: \(file.displayName)")
        isLoading = true
        error = nil
        image = nil
        rawMetadata = nil
        showExternalViewerOption = false
    }
    
    private func cleanupImage() {
        // MEMORY FIX: Explicitly nil out the image to release memory immediately
        image = nil
        print("DEBUG: RAWImageView - Image released for: \(file.displayName)")
    }
    
    private func setupRAWImage() {
        print("DEBUG: RAWImageView - Setting up RAW image for: \(file.displayName)")
        isLoading = true
        
        // Validate file
        guard file.fileUrl.isFileURL else {
            print("DEBUG: RAWImageView - Invalid file URL: \(file.fileUrl)")
            error = "Invalid file URL"
            isLoading = false
            return
        }
        
        guard FileManager.default.fileExists(atPath: file.fileUrl.path) else {
            print("DEBUG: RAWImageView - File does not exist: \(file.fileUrl.path)")
            error = "File does not exist"
            isLoading = false
            return
        }
        
        // Extract RAW metadata first
        Task {
            await extractRAWMetadata()
            
            // Try multiple approaches for RAW image viewing
            await MainActor.run {
                setupRAWImageLoading()
            }
        }
    }
    
    private func extractRAWMetadata() async {
        print("DEBUG: RAWImageView - Extracting RAW metadata for: \(file.displayName)")
        
        // Use RAWSupport utility
        if let metadata = await RAWSupport.shared.extractRAWMetadata(from: file.fileUrl) {
            await MainActor.run {
                self.rawMetadata = metadata
            }
        }
    }
    
    private func setupRAWImageLoading() {
        print("DEBUG: RAWImageView - Setting up RAW image loading for: \(file.displayName)")
        
        // Try multiple approaches for RAW image viewing
        
        // MEMORY FIX: Load with size constraint to reduce memory usage
        // Approach 1: Try with NSImage (might work with some RAW files)
        DispatchQueue.main.async {
            if let loadedImage = self.loadImageWithSizeLimit(url: file.fileUrl, maxDimension: 2048) {
                print("DEBUG: RAWImageView - NSImage loaded successfully: \(file.displayName)")
                self.image = loadedImage
                self.isLoading = false
                return
            }
            
            // Approach 2: Try FFmpeg conversion
            if RAWSupport.shared.hasFFmpeg {
                Task {
                    await tryFFmpegConversion()
                }
                return
            }
            
            // Approach 3: Check for available RAW viewers
            if RAWSupport.shared.hasRAWViewingSupport {
                self.showExternalViewerOption = true
                self.isLoading = false
                self.error = "RAW files require specialized software for viewing. Use the 'Open with External Viewer' button."
                return
            }
            
            // Final fallback
            self.showExternalViewerOption = true
            self.isLoading = false
            self.error = "RAW files require specialized software. Install Capture One, Lightroom, or use Preview.app for viewing."
        }
    }
    
    private func tryFFmpegConversion() async {
        print("DEBUG: RAWImageView - Attempting FFmpeg conversion")
        
        if let convertedURL = await RAWSupport.shared.convertRAWToJPEG(file.fileUrl) {
            await MainActor.run {
                if let convertedImage = NSImage(contentsOf: convertedURL) {
                    self.image = convertedImage
                    self.isLoading = false
                    print("DEBUG: RAWImageView - FFmpeg conversion successful")
                } else {
                    self.error = "FFmpeg conversion failed to create viewable image"
                    self.isLoading = false
                }
            }
        } else {
            await MainActor.run {
                self.error = "FFmpeg conversion failed"
                self.isLoading = false
            }
        }
    }
    
    private func openWithExternalViewer() {
        RAWSupport.shared.openRAWFile(file.fileUrl)
    }
    
    /// MEMORY FIX: Load image with size constraint to reduce memory usage
    private func loadImageWithSizeLimit(url: URL, maxDimension: CGFloat) -> NSImage? {
        // First try to get image metadata without loading full image
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        // Get image properties without decoding
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let pixelWidth = imageProperties[kCGImagePropertyPixelWidth] as? CGFloat,
              let pixelHeight = imageProperties[kCGImagePropertyPixelHeight] as? CGFloat else {
            // Fallback to regular loading if we can't get properties
            return NSImage(contentsOf: url)
        }
        
        // Calculate if we need to downsample
        let maxOriginalDimension = max(pixelWidth, pixelHeight)
        if maxOriginalDimension <= maxDimension {
            // Image is small enough, load normally
            return NSImage(contentsOf: url)
        }
        
        // Downsample the image to reduce memory usage (critical for RAW files)
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return NSImage(contentsOf: url)
        }
        
        let size = NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        let image = NSImage(cgImage: cgImage, size: size)
        
        print("DEBUG: RAWImageView - Downsampled RAW image from \(Int(pixelWidth))x\(Int(pixelHeight)) to \(Int(size.width))x\(Int(size.height))")
        return image
    }
}

