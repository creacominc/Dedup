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
- RAW: CR2 (Canon), RW2 (Panasonic)
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

2. Build the project:
```bash
swift build -c release
```

3. Run the application:
```bash
swift run -c release
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

Run the test suite:

```bash
swift test
```

Tests cover:
- Media type detection
- File information extraction
- Checksum computation
- Duplicate detection
- File moving operations
- Quality preference logic
- Performance benchmarks

## Development

### Project Structure

```
Sources/Dedup/
├── Models/
│   └── FileInfo.swift          # Core data models
├── FileProcessor.swift         # Main processing logic
├── ContentView.swift          # Main UI
├── DuplicateManagementView.swift # Duplicate management UI
└── DedupApp.swift            # App entry point

Tests/DedupTests/
└── DedupTests.swift          # Comprehensive test suite
```

### Adding New File Formats

To add support for new file formats:

1. Update `MediaType.from(fileExtension:)` in `FileInfo.swift`
2. Update quality preferences in `MediaType.qualityPreferences`
3. Add corresponding tests in `DedupTests.swift`

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



2024-02-25

Adding unit test functionality from container.
see: https://tech.pelmorex.com/2020/05/unit-testing-swift-code-on-linux/


2023-10-29

Next step:  There is now a mapping of folders which contain duplicates and the 
number of duplicates they contain.  We need a modal dialog to manage the duplicates.  
The workflow will be as follows:  Having chosen folders; found files of the same sizes; 
and found the duplicates by md5 checksums; starting with the folders with the largest 
space used in duplicate files, show the location of the two files.

NOTE:  Need to add a test for symbolic or hard links and verify that we do not follow 
them.  It may be useful to replace the duplicates with symlinks or hard links rather 
than removing them.



2023-10-01

Done:  Increase efficiency by minimizing the amount we checksum.  
Right now it wil read and sum the entire of files that are of the same size.
Given that the many images from the BMPCC4k will be the same size, it would be 
very slow to read all of it.

Instead, create a recursive function that takes a set of files and creates new 
sets of files with matching checksums.  

Iterate through a set of files (initialy matched on size) and break that group
into smaller groups with the same checksum (via dictionary).  Call again with 
each group of two or more files.

