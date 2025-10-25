# Adaptive Parallel Optimization

## Overview
This document describes the adaptive parallelism and dynamic memory management optimizations implemented to maximize performance on high-core-count systems with network-attached storage.

## Changes Made

### 1. Dynamic Chunk Sizing
**File**: `MediaFile.swift`

Changed chunk size from a fixed constant to a dynamic value that adapts based on memory budget and parallelism:

- **Before**: Fixed 4GB chunk size
- **After**: Chunk size = `memoryBudget / numThreads`
  - Larger chunks when processing fewer files (less parallelism) → reduces I/O overhead
  - Smaller chunks when processing many files (more parallelism) → keeps memory usage under control
  - Minimum chunk size: 128MB (prevents excessive overhead for highly parallel workloads)

**Formula**: 
```swift
chunkSize = max(memoryBudgetGB * 1GB / maxConcurrentTasks, 128MB)
```

### 2. Adaptive Parallelism
**File**: `FileSetBySize.swift`

Parallelism now adapts per file size based on the number of files to process:

- **Before**: Fixed 6 concurrent tasks for all file sizes
- **After**: Adaptive concurrency per file size
  - For file sizes with few files: Uses fewer threads (e.g., 2 files → 2 threads)
  - For file sizes with many files: Uses up to threshold (e.g., 100 files → 16 threads)
  - Threshold increased from 8 to 16 to better utilize 32-core systems

**Formula**:
```swift
maxConcurrentTasks = min(fileCount, parallelismThreshold)
```

### 3. Memory Budget Configuration
**File**: `FileSetBySize.swift`

New parameters for `getBytesNeededForUniqueness()`:

- `memoryBudgetGB`: Maximum memory to use (default: 32GB)
- `parallelismThreshold`: Maximum concurrent threads per file size (default: 16)

These parameters work together to optimize performance:

| Files to Process | Threads Used | Chunk Size (32GB budget) |
|-----------------|--------------|-------------------------|
| 1-2 files       | 1-2          | 16-32 GB               |
| 4 files         | 4            | 8 GB                   |
| 8 files         | 8            | 4 GB                   |
| 16 files        | 16           | 2 GB                   |
| 100+ files      | 16 (max)     | 2 GB                   |

### 4. Enhanced Status Reporting
**File**: `FileSetBySize.swift`

Added logging to show adaptive parameters in use:
```
Processing size 1.2 GB with 24 files (24 unique paths)
  Using 16 threads, chunk size: 2 GB
```

This helps monitor performance and verify optimal settings are being used.

## Performance Benefits

### Before (Fixed Configuration)
- 6 threads × 4GB chunks = 24GB memory usage
- Under-utilizes CPU on 32-core systems
- High I/O overhead for small file sizes (reading 4GB chunks when files are smaller)

### After (Adaptive Configuration)
- **Better CPU Utilization**: Up to 16 concurrent threads for file sizes with many files
- **Better Memory Efficiency**: Chunk size scales with available threads
- **Reduced I/O Overhead**: Larger chunks (up to 32GB) when processing few files
- **Controlled Memory Usage**: Never exceeds 32GB total (16 threads × 2GB = 32GB max)

## Expected Performance Improvements

1. **Network-Attached Storage (NAS)**
   - Larger chunks → fewer read operations → better throughput
   - More parallelism → better utilization of network bandwidth
   - Expected: 2-3x faster for large file sets

2. **CPU Utilization**
   - 16 threads vs 6 threads → 2.6x more parallel work
   - Better utilization of 32-core system
   - Expected: 40-60% CPU usage (up from 15-20%)

3. **Memory Usage**
   - Adaptive chunks prevent memory waste
   - Maximum 32GB usage (configurable)
   - Better suited for systems with high memory availability

## Configuration

To adjust performance parameters, modify the call to `getBytesNeededForUniqueness()`:

```swift
// Example: Use 48GB memory budget with up to 24 threads
await fileSetBySize.getBytesNeededForUniqueness(
    memoryBudgetGB: 48,
    parallelismThreshold: 24
)

// Example: Conservative settings for lower-memory systems
await fileSetBySize.getBytesNeededForUniqueness(
    memoryBudgetGB: 16,
    parallelismThreshold: 8
)
```

## Thread Safety

The dynamic `chunkSize` is marked as `nonisolated(unsafe)` because:
1. Chunk size is set **once** per file size **before** parallel processing begins
2. All tasks processing the same file size read the same value
3. No concurrent writes occur during parallel processing

This is safe and avoids the overhead of synchronization primitives.

## Monitoring Performance

When processing, watch for these indicators in the status messages:

```
Processing size 2.5 GB with 8 files (8 unique paths)
  Using 8 threads, chunk size: 4 GB
  Chunk 1/1: Processing 8 files of size 2.5 GB
```

This shows:
- How many threads are being used for this file size
- The chunk size calculated for optimal performance
- Progress through the chunks

If you see idle cores or low network utilization, consider:
- Increasing `parallelismThreshold` (e.g., to 24 or 32)
- Increasing `memoryBudgetGB` if memory is available

If you see memory pressure or swapping:
- Decrease `memoryBudgetGB` (e.g., to 16 or 24)
- Decrease `parallelismThreshold` if necessary

## Technical Details

### Chunk Size Calculation
```swift
let memoryBudgetBytes = memoryBudgetGB * 1024 * 1024 * 1024
let optimalChunkSize = max(memoryBudgetBytes / maxConcurrentTasks, 128 * 1024 * 1024)
MediaFile.chunkSize = optimalChunkSize
```

### Thread Count Calculation
```swift
let maxConcurrentTasks = min(fileCount, parallelismThreshold)
```

### Memory Usage Pattern
For each file size, memory usage follows this pattern:
1. Read chunk from `maxConcurrentTasks` files simultaneously
2. Compute checksums (CPU-bound work)
3. Release memory immediately via `autoreleasepool`
4. Repeat for next chunk

Peak memory = `maxConcurrentTasks × chunkSize`

## Compatibility

These changes are backward compatible:
- Default parameters maintain reasonable behavior
- Existing code continues to work without modification
- Users can opt-in to aggressive settings if desired

## Future Enhancements

Potential further optimizations:
1. Auto-detect system memory and CPU count
2. Benchmark network speed and adjust chunk size dynamically
3. Per-file-size memory budgets (larger budgets for larger files)
4. Real-time adjustment based on observed I/O throughput

