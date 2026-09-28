# Dedup

Dedup is a native macOS application for finding byte-for-byte duplicate media and safely organizing original footage. It is designed for large photo, audio, and video collections, including individual files larger than 1 TB and libraries stored on local disks or network-attached storage.

The application compares file content, not filenames or perceived media quality. Files such as `A.MOV` and `B.MOV` are exact duplicates only when their sizes and complete SHA-256 hashes match. Different encodings or formats remain separate files.

## Requirements

- macOS 15 or later
- Xcode 27 and Swift 6 to build from source
- Read/write access to the selected source and destination folders

## What it does

- Recursively scans supported audio, photo, and video files without following symbolic links, package descendants, or mounted volumes below the selected roots.
- Groups files by size, then compares progressively larger SHA-256 prefixes. Files that differ early are rejected without reading their remaining content.
- Computes a complete hash before declaring files exact duplicates.
- Caches hashes using file path, size, and modification date so unchanged files do not need to be read again.
- Creates `Audio`, `Photos`, and `Videos` destination folders and organizes unique originals as `Media Type/YYYY/MM/DD/filename` using the preserved creation date.
- Keeps duplicates safe by moving source-side duplicate files into `.Dedup Quarantine` beneath the destination. Quarantined files are not deleted automatically.
- Generates a deterministic operation plan that can be inspected, dry-run, and copied as a text report before any files change.

## Safe transfer behavior

Dedup chooses the least expensive safe transfer for each planned operation:

1. On the same filesystem, it uses an atomic move when possible. This does not rewrite a multi-terabyte file.
2. If the source and destination are on different filesystems, or a same-filesystem move fails without changing either endpoint, it streams the file to a hidden staging file.
3. The streamed copy and source are completely hashed and compared.
4. Only after verification does Dedup commit the staged file and remove the source.
5. Cancellation stops between I/O chunks, removes partial staging data, and leaves the source intact.

Existing destinations and conflicts are never overwritten. The operation table and status bar show the active filename, transfer/hash phase, completed count, busy indicator, and time since the latest update.

## Supported media

The scanner recognizes common formats including:

- Audio: WAV, FLAC, AAC, M4A, MP3, OGG, WMA
- Photos: JPEG, PNG, GIF, BMP, TIFF, PSD, CR2, CR3, RW2, RAW, DNG, ARW, NEF, ORF, RWZ, HEIC, HEIF, WebP
- Video: MOV, MP4, AVI, MKV, WMV, FLV, WebM, M4V, BRAW, R3D, CRM, MPEG, MPG

The format list controls discovery only. Dedup does not transcode media and does not treat related formats as duplicates unless their actual bytes are identical.

## Using the app

1. Choose the source folder containing media to consolidate.
2. Choose the Originals destination, normally `/Volumes/VideoProjects/Originals`.
3. Select **Analyze**.
4. Review **Overview**, **Exact Duplicates**, **Operation Plan**, and **Problems**.
5. Leave **Dry run** enabled and select **Run Dry Run** to preview every result.
6. Copy the report if desired, disable **Dry run**, and select **Execute Plan**.

The destination layout is:

```text
Originals/
├── Audio/YYYY/MM/DD/
├── Photos/YYYY/MM/DD/
├── Videos/YYYY/MM/DD/
└── .Dedup Quarantine/<original relative path>
```

Review `.Dedup Quarantine` after a successful run. Delete or archive its contents manually only after you are satisfied that the retained originals are correct.

## Building

Open `Dedup.xcodeproj` in Xcode, select the **Dedup** scheme and **My Mac**, then build or run normally.

Command-line builds are also supported:

```bash
xcodebuild -project Dedup.xcodeproj \
  -scheme Dedup \
  -destination 'platform=macOS' \
  build
```

## Tests and coverage

The test suite uses Swift Testing for unit and integration tests and XCTest/XCUIAutomation for UI launch tests. The shared `Dedup.xctestplan` enables code coverage and covers media classification, scanning boundaries, progressive hashing, cache invalidation, exact-content detection, planning, dry runs, atomic moves, verified-copy fallback, staging cleanup, conflicts, reporting, and application launch.

Run all tests from Xcode with **Product > Test**, or from Terminal:

```bash
xcodebuild -project Dedup.xcodeproj \
  -scheme Dedup \
  -testPlan Dedup \
  -destination 'platform=macOS' \
  test
```

An opt-in integration test uses these external fixtures:

- Source: `/Volumes/VideoProjects/Test/TestFiles`
- Destination: `/Volumes/VideoProjects/Test/Results`

Enable it only when those folders are mounted and prepared:

```bash
DEDUP_RUN_VOLUME_TESTS=1 xcodebuild -project Dedup.xcodeproj \
  -scheme Dedup \
  -testPlan Dedup \
  -destination 'platform=macOS' \
  test
```

The integration test prepares the media roots but does not execute the operation plan.

## Architecture

- `DedupEngine.swift`: scanning, media classification, progressive hashing, hash cache, and exact-duplicate analysis
- `OperationPlan.swift`: dated destination planning, quarantine planning, dry runs, atomic moves, verified copies, and cancellation
- `DedupAppModel.swift`: main-actor application state and asynchronous workflow coordination
- `ContentView.swift`: SwiftUI navigation, reports, operation table, and live progress
- `DedupTests/`: Swift Testing coverage for the engine, planner, executor, models, and external fixture
- `DedupUITests/`: XCUIAutomation launch coverage

## License

Dedup is open-source software released under the [MIT License](LICENSE).
