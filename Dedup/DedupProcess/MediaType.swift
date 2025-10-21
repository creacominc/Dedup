
enum MediaType: String, CaseIterable, Codable {
    case photo
    case video
    case audio
    case unsupported
    
    static func from(fileExtension: String) -> MediaType {
        let photoExtensions = ["jpeg", "jpg", "png", "gif", "bmp", "tiff", "tif", "psd", "cr2", "rw2", "raw", "dng", "arw", "nef", "orf", "rwz"]
        let videoExtensions = ["mov", "mp4", "avi", "mkv", "wmv", "flv", "webm", "m4v", "braw"]
        let audioExtensions = ["wav", "flac", "aac", "m4a", "mp3", "ogg", "wma"]
        
        let ext = fileExtension.lowercased()
        
        if photoExtensions.contains(ext) {
            return .photo
        } else if videoExtensions.contains(ext) {
            return .video
        } else if audioExtensions.contains(ext) {
            return .audio
        } else {
            return .unsupported // Default to unsupported for unknown extensions
        }
    }
    
    var qualityPreferences: [String] {
        switch self {
        case .photo:
            return ["cr2", "rw2", "raw", "dng", "arw", "nef", "orf", "rwz", "tiff", "tif", "psd", "jpeg", "jpg", "png", "bmp"]
        case .video:
            return ["braw", "mov", "mp4", "avi", "mkv", "wmv", "flv", "webm"]
        case .audio:
            return ["wav", "flac", "aac", "m4a", "mp3", "ogg"]
        case .unsupported:
            return []
        }
    }
    
    var qualityScore: Int {
        switch self {
        case .photo:
            return 3
        case .video:
            return 2
        case .audio:
            return 1
        case .unsupported:
            return 0
        }
    }
    
    var displayName: String {
        switch self {
        case .photo:
            return "Photos"
        case .video:
            return "Videos"
        case .audio:
            return "Audio"
        case .unsupported:
            return "Unsupported"
        }
    }
    
    var isViewable: Bool {
        switch self {
        case .photo:
            return true
        case .video:
            return true
        case .audio:
            return true
        case .unsupported:
            return false
        }
    }
}
