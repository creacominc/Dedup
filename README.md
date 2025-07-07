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
- RAW: CR2 (Canon), RW2 (Panasonic), DNG
- Processed: TIFF, JPEG, PNG, PSD, BMP

### Videos
- RAW: BRAW, DNG
- Compressed: MOV, MP4, AVI, MKV, WMV, FLV, WebM

### Audio
- Lossless: WAV, FLAC
- Compressed: AAC, M4A, MP3, OGG

## Installation

### Prerequisites
- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

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

2025-07-05 

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
