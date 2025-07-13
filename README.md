# Dedup - Media File Deduplication Tool

A powerful macOS application for organizing and deduplicating media files from NAS storage. Built with SwiftUI and optimized for handling large datasets efficiently.

## Features

- **Smart Media Detection**: Automatically identifies audio, photo, and video files
- **Quality-Based Deduplication**: Prefers higher quality formats (RAW over JPEG, BRAW over MP4, etc.)
- **Efficient Processing**: Uses multi-level checksum comparison for fast duplicate detection
- **Organized Output**: Files are automatically organized by media type and creation date
- **Memory Optimized**: Designed for systems with large amounts of RAM
- **Progress Tracking**: Real-time progress updates during processing
- **Batch Operations**: Move multiple files or manage duplicates in batches

## Supported File Formats

### Photos
- RAW: CR2 (Canon), RW2 (Panasonic), DNG, ARW (Sony), NEF (Nikon), ORF (Olympus), RWZ (Panasonic), RAW (Generic)
- Processed: TIFF, JPEG, PNG, PSD, BMP

**RAW Support**: The app includes comprehensive RAW image support with multiple viewing options:
- Native NSImage loading (for compatible RAW files)
- Capture One integration (professional RAW editor)
- Adobe Lightroom integration
- Photos.app integration
- Preview.app fallback
- FFmpeg conversion for preview
- External viewer fallback

### Videos
- RAW: BRAW (Blackmagic Design), DNG
- Compressed: MOV, MP4, AVI, MKV, WMV, FLV, WebM

**BRAW Support**: The app includes comprehensive BRAW video support with multiple playback options:
- Native AVPlayer (for compatible BRAW files)
- Blackmagic RAW Player integration
- DaVinci Resolve integration  
- FFmpeg conversion for preview
- External player fallback

### Audio
- Lossless: WAV, FLAC
- Compressed: AAC, M4A, MP3, OGG

## FFmpeg Support

Dedup includes enhanced FFmpeg integration for improved metadata extraction from various media formats:

### Supported Formats with FFmpeg

**Video Formats:**
- MKV files (primary use case)
- AVI, WMV, FLV, WebM
- Any format that AVFoundation cannot process

**Audio Formats:**
- OGG, FLAC, WMA
- Other formats that may have AVFoundation compatibility issues

### FFmpeg Installation

FFmpeg is automatically detected in the following locations:
- `/usr/local/bin/ffmpeg` (Homebrew installation)
- `/opt/homebrew/bin/ffmpeg` (Apple Silicon Homebrew installation)

To install FFmpeg:
```bash
# Using Homebrew
brew install ffmpeg
```

### How It Works

1. **Automatic Detection**: The app automatically detects if FFmpeg is available
2. **Priority Processing**: MKV files and problematic formats use FFmpeg first
3. **Fallback System**: If FFmpeg fails, the app falls back to AVFoundation
4. **Metadata Extraction**: Extracts resolution, frame rate, codec, duration, and audio information

### Benefits

- **MKV Support**: Full metadata extraction from MKV files
- **Better Compatibility**: Handles formats that AVFoundation struggles with
- **Enhanced Information**: More detailed metadata extraction
- **Reliable Fallback**: Graceful degradation when FFmpeg is unavailable

## Installation

### Prerequisites
- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

### BRAW Video Support
For optimal BRAW video playback, install one or more of the following:
- **Blackmagic RAW Player** (recommended for BRAW files)
- **DaVinci Resolve** (professional video editing software)
- **FFmpeg** (for conversion and metadata extraction)
  ```bash
  # Install FFmpeg via Homebrew
  brew install ffmpeg
  ```

### RAW Image Support
For optimal RAW image viewing, install one or more of the following:
- **Capture One** (professional RAW editor - recommended)
- **Adobe Lightroom** (professional photo editing software)
- **Photos.app** (built-in macOS photo management)
- **Preview.app** (built-in macOS image viewer)
- **FFmpeg** (for conversion and metadata extraction)
  ```bash
  # Install FFmpeg via Homebrew
  brew install ffmpeg
  ```

### Building from Source

1. Clone the repository:
```bash
git clone <repository-url>
cd Dedup
```

2. Open the project in Xcode:
```bash
open Dedup.xcodeproj
```

3. Build and run:
   - Press `Cmd+R` to build and run in Xcode
   - Or use `Cmd+B` to build only

### Command Line Building

```bash
# Build the project
xcodebuild -project Dedup.xcodeproj -scheme Dedup -configuration Release build

# Run tests
xcodebuild -project Dedup.xcodeproj -scheme Dedup -destination 'platform=macOS' test

# Build for distribution
xcodebuild -project Dedup.xcodeproj -scheme Dedup -configuration Release archive
```

## Usage

### Basic Workflow

1. **Select Source Directory**: Choose the folder containing your media files
2. **Select Target Directory**: Choose where you want organized files to be stored
3. **Start Processing**: Click "Start Processing" to begin analysis
4. **Review Results**: View files to be moved and duplicate groups
5. **Take Action**: Move files or manage duplicates as needed

### File Organization

Files are automatically organized in the target directory as follows:
```
Target/
├── Photos/
│   └── YYYY/
│       └── MM/
│           └── DD/
│               └── filename.ext
├── Videos/
│   └── YYYY/
│       └── MM/
│           └── DD/
│               └── filename.ext
└── Audio/
    └── YYYY/
        └── MM/
            └── DD/
                └── filename.ext
```

### Duplicate Detection

The application uses a multi-level approach to detect duplicates:

1. **Size Comparison**: Files with different sizes are immediately identified as unique
2. **Name Similarity**: Files with similar names (case-insensitive) are grouped
3. **Checksum Comparison**: Progressive checksum computation (1KB → 4GB → 12GB → 64GB → 128GB → Full)
4. **Quality Preference**: When duplicates are found, higher quality formats are preferred

### Performance Optimization

- **Memory Usage**: Designed to use available RAM efficiently for caching
- **Threading**: Multi-threaded processing for faster analysis
- **Progressive Checksums**: Stops comparison as soon as differences are found
- **Caching**: Checksums are cached to avoid recomputation

## Technical Details

### Architecture

- **SwiftUI**: Modern declarative UI framework
- **Crypto**: Secure checksum computation using SHA256
- **Concurrency**: Async/await for responsive UI during processing
- **File System**: Efficient directory traversal with symbolic link handling

### Memory Management

- In-memory caching of checksums and file metadata
- Configurable cache sizes based on available system memory
- Automatic cache cleanup to prevent memory pressure

### Error Handling

- Graceful handling of file system errors
- Detailed error reporting to users
- Automatic retry mechanisms for transient failures

## Testing

### Running Tests

```bash
# Run all tests
xcodebuild -project Dedup.xcodeproj -scheme Dedup -destination 'platform=macOS' test

# Run specific test target
xcodebuild -project Dedup.xcodeproj -scheme DedupTests -destination 'platform=macOS' test

# Run UI tests
xcodebuild -project Dedup.xcodeproj -scheme DedupUITests -destination 'platform=macOS' test
```

### Test Coverage

Tests cover:
- Media type detection
- File information extraction
- Checksum computation
- Duplicate detection
- File moving operations
- Quality preference logic
- Performance benchmarks
- UI interactions
- App launch and navigation

## Development

### Project Structure

```
Dedup/
├── Models/
│   └── FileInfo.swift          # Core data models
├── FileProcessor.swift         # Main processing logic
├── ContentView.swift          # Main UI
├── DedupApp.swift            # App entry point
└── Info.plist                # App configuration

DedupTests/
└── DedupTests.swift          # Comprehensive test suite

DedupUITests/
├── DedupUITests.swift        # UI tests
└── DedupUITestsLaunchTests.swift # Launch tests
```

### Adding New File Formats

To add support for new file formats:

1. Update `MediaType.from(fileExtension:)` in `FileInfo.swift`
2. Update quality preferences in `MediaType.qualityPreferences`
3. Add corresponding tests in `DedupTests.swift`

### Building for Distribution

```bash
# Create archive
xcodebuild -project Dedup.xcodeproj -scheme Dedup -configuration Release archive -archivePath build/Dedup.xcarchive

# Export for distribution
xcodebuild -exportArchive -archivePath build/Dedup.xcarchive -exportPath build/Dedup -exportOptionsPlist exportOptions.plist
```

## Changelog

### [Unreleased] - 2025-07-12

#### Added
- **VSCode/Cursor IDE Integration**: Full development environment setup with build, test, and debug capabilities
  - Added `.vscode/settings.json` for Swift development configuration
  - Added `.vscode/tasks.json` with build, test, and clean tasks
  - Added `.vscode/launch.json` for debugging configuration
  - Added `Package.swift` for Swift Package Manager support
  - Added comprehensive documentation in `VSCode_Setup.md`

- **Network Drive Access**: Added entitlements to allow NAS and network drive access
  - Added `com.apple.security.files.user-selected.read-write` for user-selected folders
  - Added `com.apple.security.files.downloads.read-write` for Downloads folder access
  - Added `com.apple.security.files.bookmarks.app-scope` and `document-scope` for persistent access
  - Added `com.apple.security.network.client` and `network.server` for network operations
  - Added `com.apple.security.temporary-exception.files.absolute-path.read-write` for `/Volumes/` access
  - Added `com.apple.security.temporary-exception.files.home-relative-path.read-write` for home directory access
  - Added comprehensive documentation in `Network_Drive_Access_Setup.md`

#### Fixed
- **Build System Issues**: Resolved duplicate file conflicts caused by `.build` folder inclusion
  - Updated `.gitignore` to exclude build artifacts more comprehensively
  - Updated Xcode project to exclude `.build` folder from File System Synchronized Groups
  - Fixed deployment target mismatches between main app and test targets (updated to macOS 15.0)

#### Improved
- **Development Workflow**: Streamlined development process with VSCode/Cursor integration
  - One-command build and test execution
  - Integrated debugging with LLDB
  - Automated app deployment for testing
  - Comprehensive task automation

- **Documentation**: Enhanced project documentation
  - Added detailed setup guides for VSCode/Cursor
  - Added network drive access troubleshooting
  - Updated build instructions and development workflow

### [Initial Release] - 2025-07-12

#### Features
- **Smart Media Detection**: Automatic identification of audio, photo, and video files
- **Quality-Based Deduplication**: Prefers higher quality formats (RAW over JPEG, BRAW over MP4)
- **Efficient Processing**: Multi-level checksum comparison for fast duplicate detection
- **Organized Output**: Files automatically organized by media type and creation date
- **Memory Optimized**: Designed for systems with large amounts of RAM
- **Progress Tracking**: Real-time progress updates during processing
- **Batch Operations**: Move multiple files or manage duplicates in batches

#### Supported Formats
- **Photos**: RAW (CR2, RW2, DNG, ARW, NEF, ORF, RWZ), TIFF, JPEG, PNG, PSD, BMP
- **Videos**: BRAW, DNG, MOV, MP4, AVI, MKV, WMV, FLV, WebM
- **Audio**: WAV, FLAC, AAC, M4A, MP3, OGG

#### Technical Features
- **RAW Support**: Comprehensive RAW image support with multiple viewing options
- **BRAW Support**: Comprehensive BRAW video support with multiple playback options
- **SwiftUI Interface**: Modern declarative UI framework
- **Concurrent Processing**: Async/await for responsive UI during processing
- **Comprehensive Testing**: Unit tests, UI tests, and performance benchmarks

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## Support

For issues and questions:
- Check the existing issues
- Create a new issue with detailed information
- Include system specifications and error logs

## Performance Notes

This application is designed for high-performance systems with:
- Large amounts of RAM (32GB+ recommended)
- Fast network connections to NAS storage
- Fast local storage for caching
- Multiple CPU cores for parallel processing

The application will automatically adapt to available system resources and provide progress feedback during long-running operations.


# Change Log

## 2025-07-12 Improving the checksum caching workflow

i think the logic for the checksum calculation is not efficient.  for efficiency we should only checksum as much of a file as is needed to verify that it is different than another file.  

as such, we should build a cache of the fileInfo with as little information as needed initially.  that is, only with information that can be quickly gathered.  in the end there will be a very large number of files and we will be reading terabytes of information so we need to minimize the data reads and the memory usage.

I think that the target and source folders should be initially used to generate caches of the file information with only the name, path, file size, creation and modification dates, media type, file extension, and whatever else can be collected quickly.  Only start adding checksums to the cache when the files are being compared. 

For each file that is found in the source folder list (which can be the cache), compare it using the logic that is already in place.  the last comparison should be the checksums.  that is, if the files appear to be duplicates, start comparing the checksums.  if they are not, there is no need for further checksums.  when doing the checksum comparison process, start by computing the first checksum size if it has not already been computed.  if it has, simply compare the checksums.  in other words, only ever checksum a file once for each size and only when it is being compared with another file that has already matched all the other criteria and smaller checksums.

Please provide logging for the process so that we can diagnose and verify the efficiency.  i want to be certain that files are not checksumed beyond the number of bytes needed to verify the difference and that no file/size is checksummed more than once.


## 2025-07-05 

  Asking Cursor to re-create this project...

  I started the project but did not get very far.  I would like you to recreate it in this existing workspace using the existing github repository.  

You can remove any and all project files and add others as needed.

Please update the build target(s) to the latest macos.  this is the only platform on which this will run.  it will run on a mac pro with a lot of memory and a fast network connection to the nas on which the data is stored.  it also has a fast local drive which can be used as cache but it may be better to use the large amount of memory available first.  This host also has multiple GPUs if that can be helpful for computing and comparing the images and video.

The goal of the application is to remove dupicate files from a NAS storage which I would like to specify from a folder selection dialog.    I would like the application to compare the files in a source location to ones in a target location.  The target should be organized under Audio, Photos, and Videos at the top level, followed by the year (YYYY), month (MM), and date (DD) so that the files will be organized by creation date.  Please preserve the creation date when moving files.  If the file in the source tree is not found in the destination, it should be moved there under the appropriate media type and date folders.  eg Movies/2021/03/01/something.mov

Please only look at audio, video, or photo files in the folders selected and any folder under the selected folders.  Do not follow symbolic links or mounted partitions below the selected folders.

Audio, Video, and Photo files will be named with the standard extensions including:  wav, DNG, BRAW, RW2, JPG, mov, CR2, psd, tif, mkv, mp4, etc.  The cameras used are mostly Canon, Blackmagic Design, Panasonic, and DJI.  

When selecting files to compare, please look at the raw versions first since duplicates of lesser quality can be deleted in favour of the higher quality raw files.  eg CR2 (canon raw) or RW2 (Panasonic raw) are preferred over tiff,  tiff over jpeg, jpeg over bmp.  of the video formats it is likely BRAW over DNG over MOV over MP4 over AVI.  

If there is a jpeg, tiff, or png with the same name (before the extention) as a raw file (RW2, CR2, or BRAW), it should be considered a possible duplicate with the raw file being the preferred one.

If there are files with the same name but they have different creation dates/times, they should be considered probable duplicates with the older file being preferred.

While it is comparing (which could take a long time given that there are about 70 TB of files), I would like the application to show a list of files that it expects can be moved and a list of files that it sees as duplicates because of similar names or content.  I would like to be able to select individual files from the list or click a Move-All checkbox to select all that is currently listed and click on a button to have them moved.  When they are moved, the creation date needs to be preserved.   I would also like a list of those that are duplicates.  

A file might be a duplicate if one or more of the following are true.  Please consider checking these characteristics in order of the time needed to perform so that we can identify files that are definately different quickly.

- A file might be a duplicate if a file of the same name is found in the folder to which this file would be moved with the same name (case insensitve) and a related extension (eg mov == mp4 == avi or cr2 == rw2 == jpeg == jpg == tiff etc).  To handle this efficiently, it may be helpful to keep a cache of the directory structure in memory and update it as files are moved.  For example, if you find the file P102497.JPG with a creation date of 2023/01/02 and there exists in Photos/2023/01/02 a file named P102497.RW2, the JPG is likely a duplicate.  It will need to be compared to verify.
- A file might be a duplicate if a file exists anywhere under the target folder for this type of file (audio, video, photo) with the same name (case insensitive) and a related extension.   This can also benefit from the in-memory cache.  For example, if you find the file P102497.JPG with a creation date of 2023/05/11 and there exists in Photos/2023/01/02 a file named P102497.RW2, the JPG is likely a duplicate even though it had a different creation date.  It will need to be compared to verify.
- The final and definitive check for a duplicate would be to checksum the files and compare it to a cache of the checksums of files under the target folder.  To do this efficiently, we could build an in-memory cache of the files with a checksum for the first 1024 bytes and 4G which can be done quickly.  Once that is done, the comparison can begin in one thread while another continues to build the cache of checksums for the fist 12G, 64G, 128G, and the complete file size.  If the file size is less than the lower limit of the threshold, it does not need to be checksummed again.  That is, for a 3.8G file, it will store a checksum under the 4G limit but does not need to check again for the 12G round.  If you create a thread pool (or group) for the populating of the cache, it may be helpful to use the same pool for the comparison so that the threads which are populating can later be used for comparing.  By comparing the smaller number of bytes first, a file can be said to definately not be a duplicate if there is a difference in the checksum for the first N bytes and save having to read the entire file.  

The thresholds I provided are guidelines.  You may know of better thresholds which fit in memory bounderies better to avoid paging and context switching.

Once a difference in the checksums is found for a given file against every file in the cache, it is unique and should be included in the list of files to move.  If the file has been completely checksummed another file has the same checksum and size, the file should be considered a duplicate.  The file with the earlier creation date is preferred and they should be listed in the duplicates list for selection and processing.

Please include unit tests and a way to verify the file moves.


Summary of Crash Fix
The crash was happening in the SwiftUI view rendering system, specifically with the _AVKit_SwiftUI framework when trying to create a VideoPlayer view. The crash was occurring during metadata initialization in the Swift runtime.
Root Cause
The crash was likely caused by:
Premature player cleanup - The player was being set to nil during setup, causing the VideoPlayer to be created with an invalid player
Threading issues - AVPlayer creation was happening on background threads instead of the main queue
Missing safety checks - No validation of player state before creating VideoPlayer
Memory management issues - Notification observers weren't being properly cleaned up
Fixes Applied
Added comprehensive safety checks:
URL validation (file.url.isFileURL)
File existence checks (FileManager.default.fileExists)
Player creation validation
Player item status checks (player.currentItem != nil and player.currentItem?.status != .failed)
Improved threading:
Moved AVPlayer creation to the main queue using DispatchQueue.main.async
Added proper error handling for async operations
Enhanced player management:
Created AVPlayer with AVPlayerItem for better control
Added notification observers for player item failures
Improved cleanup methods to remove notification observers
Better error handling:
Added multiple fallback states for different error conditions
Enhanced debug logging to track player states
Added delays to ensure player initialization is complete
Memory management:
Added proper cleanup of notification observers
Improved timer management
Better state management to prevent memory leaks
Key Changes Made
VideoView and BRAWVideoView setupPlayer() methods:
Added URL and file existence validation
Moved player creation to main queue
Added player item status monitoring
Enhanced error handling and logging
VideoPlayer creation safety:
Added checks for player.currentItem != nil and player.currentItem?.status != .failed
Only create VideoPlayer when player is fully initialized
Cleanup improvements:
Added notification observer cleanup
Better timer management
Proper player state reset
Debug enhancements:
Added comprehensive logging throughout the video setup process
Better error messages for different failure scenarios
The app should now be much more stable when handling video files, with proper error handling and no more crashes related to VideoPlayer initialization. The changes ensure that:
VideoPlayer is only created with valid, fully initialized players
All AVPlayer operations happen on the main queue
Proper cleanup prevents memory leaks
Comprehensive error handling provides fallback states
Debug logging helps track any remaining issues
You can now test the app and it should handle video files without crashing. The debug logging will help identify any remaining issues if they occur.
