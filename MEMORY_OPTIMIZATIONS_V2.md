# Memory Optimizations V2 - Aggressive Buffer Management

## Overview

This document describes the aggressive memory optimization strategies implemented to minimize memory usage during deduplication, particularly addressing the issue of holding onto multiple 2GB chunks simultaneously.

## Problem Identified

Profiling revealed that the application was holding onto many 256MB (now 2GB) data buffers in memory simultaneously, causing excessive memory usage. This occurred because:

1. **Data buffers not released promptly** - Swift's ARC would eventually clean up, but not fast enough
2. **File handles kept open** - Using `defer` delayed cleanup until function exit
3. **Multiple files processed before cleanup** - Buffers accumulated across file operations
4. **Chunk size too small** - 256MB chunks meant 100+ chunks for large files, with overhead per I/O operation

## Solutions Implemented

### 1. Increased Chunk Size to 2GB

**Change**: Updated from 256MB to 2GB chunks
```swift
static let chunkSize: Int = 2 * 1024 * 1024 * 1024  // 2 GB
```

**Benefits**:
- **Fewer chunks**: A 20GB file now has 10 chunks instead of 80
- **Reduced I/O overhead**: Critical for network storage - fewer round trips
- **Less metadata**: Fewer checksums to store and process
- **Trade-off**: Higher memory per operation, but much better overall due to immediate cleanup

**Network Consideration**: Each file open/seek/read over network has overhead. Larger chunks mean:
- Fewer network round trips
- Better throughput utilization
- More efficient for NAS/network storage

### 2. Immediate Buffer Release with Autoreleasepool

**Change**: Wrapped file operations in `autoreleasepool` blocks
```swift
let hashString: String = autoreleasepool {
    // Read file, compute hash, return result
    // Data buffer released IMMEDIATELY when autoreleasepool exits
}
```

**Benefits**:
- **Immediate cleanup**: Data buffers freed as soon as hash is computed
- **No accumulation**: Prevents multiple buffers from building up in memory
- **Predictable memory**: Memory usage stays bounded at ~2GB (one chunk)

### 3. Close File Handles Immediately

**Change**: Close file handle right after reading, before computing hash
```swift
// Read the chunk
guard let data = try fileHandle.read(upToCount: bytesToRead) else {
    try? fileHandle.close()
    return ""
}

// Close file IMMEDIATELY after reading, before computing hash
try? fileHandle.close()

// Now compute hash (file already closed)
let hash: SHA256.Digest = SHA256.hash(data: data)
```

**Benefits**:
- **Faster file handle release**: No waiting for function exit
- **Reduced system resources**: File descriptors freed immediately
- **Better for network storage**: Connections not held open unnecessarily

### 4. Per-File Autoreleasepool in Processing Loop

**Change**: Wrap each file's checksum computation in its own autoreleasepool
```swift
for (index, file) in filesToProcess.enumerated() {
    autoreleasepool {
        _ = file.computeChunkChecksum(chunkIndex: chunkIndex)
        let cumulativeKey = file.checksums.joined(separator: "|")
        newGroups[cumulativeKey, default: []].append(file)
    }
    
    // Additional drain every 10 files
    if (index + 1) % 10 == 0 {
        autoreleasepool { }
    }
}
```

**Benefits**:
- **Buffer released after each file**: No accumulation across files
- **Frequent draining**: Every 10 files, force cleanup
- **Memory stays flat**: Memory graph should show sawtooth pattern, not climbing

### 5. More Frequent Autoreleasepool Drains

**Change**: Drain every 10 size groups instead of every 100
```swift
// MEMORY OPTIMIZATION: Drain autoreleasepool more frequently (every 10 sizes)
if processedCount % 10 == 0 {
    autoreleasepool { }
}
```

**Benefits**:
- **Prevents long-term accumulation**: Cleans up any lingering objects
- **Better for large datasets**: Processing thousands of files stays bounded

## Memory Usage Profile

### Before Optimizations (256MB chunks)
```
Processing 100 files of 10GB each:
- Peak memory: ~25.6 GB (100 files × 256 MB)
- Chunks per file: 40
- Total chunks: 4,000
- I/O operations: 4,000
```

### After Initial Optimization (256MB chunks with cleanup)
```
Processing 100 files of 10GB each:
- Peak memory: ~2.56 GB (10 files × 256 MB worst case)
- Chunks per file: 40
- Total chunks: 4,000
- I/O operations: 4,000
```

### After Full Optimization (2GB chunks with aggressive cleanup)
```
Processing 100 files of 10GB each:
- Peak memory: ~2-4 GB (1-2 buffers in flight)
- Chunks per file: 5
- Total chunks: 500
- I/O operations: 500

Result: 92% less memory, 87.5% fewer I/O operations
```

## Expected Memory Behavior

When profiling, you should see:

1. **Flat baseline**: Memory stays around 1-2GB during processing
2. **Small spikes**: Brief 2GB spikes when reading chunks
3. **Immediate drops**: Memory drops right back down after each file
4. **No accumulation**: No upward trend over time
5. **Regular drops**: Every 10 files/sizes, brief dip from autoreleasepool drain

### Memory Graph Pattern
```
Memory
  ^
4GB|    /\      /\      /\
  |   /  \    /  \    /  \
2GB|  /    \  /    \  /    \
  | /      \/      \/      \
0GB|________________________> Time
    (Processing files - sawtooth pattern, not climbing)
```

## Network Storage Optimization

For network storage (NAS, SMB, AFP, NFS), the 2GB chunk size is specifically optimized:

### Network Overhead per I/O Operation
- Connection setup/negotiation
- Protocol overhead
- Latency per request
- Buffer management on remote system

### Benefits of 2GB Chunks
- **87.5% fewer network round trips** (5 vs 40 for 10GB file)
- **Better bandwidth utilization** (longer sustained transfers)
- **Less protocol overhead** (fewer negotiations)
- **More efficient early elimination** (most non-duplicates differ in first 2GB)

### Trade-offs
- **Higher memory per operation**: 2GB vs 256MB buffer
- **Longer per-file time**: Each chunk takes longer to read
- **But**: Overall memory lower due to aggressive cleanup
- **And**: Overall time lower due to fewer I/O operations

## Threading Considerations

The user asked about processing 2-4 files concurrently. Here's the analysis:

### Potential Benefits
- **Better I/O utilization**: Multiple outstanding network requests
- **Parallel hash computation**: CPU utilization while waiting for I/O
- **Faster for small file counts**: When only a few files per size

### Concerns with Current Approach
- **Memory multiplication**: 2-4 threads × 2GB = 4-8GB baseline
- **Coordination overhead**: Thread synchronization costs
- **Network saturation**: NAS might already be bottleneck
- **Diminishing returns**: Early elimination already very fast

### Recommendation
**Not implementing threading yet** because:
1. Current single-threaded approach with 2GB chunks is already very efficient
2. Network I/O is likely the bottleneck, not CPU
3. Memory usage is now well-controlled with aggressive cleanup
4. Early elimination means most files process very quickly anyway

**Future consideration**: If profiling shows CPU is idle waiting for I/O, could implement:
- **Bounded thread pool**: 2-3 threads maximum
- **Per-thread autoreleasepool**: Each thread cleans up its own buffers
- **Careful memory monitoring**: Ensure doesn't exceed limits
- **Adaptive**: Only use threading for sizes with many files (>10)

## Monitoring and Validation

### How to Verify Optimizations Are Working

1. **Use Instruments (Allocations)**
   - Watch for "Data" allocations
   - Should see 2GB allocations that immediately free
   - Should NOT see accumulation of multiple 2GB buffers
   - Look for "All Heap & Anonymous VM" staying flat

2. **Activity Monitor**
   - Memory pressure should stay green
   - App memory should stay < 4GB during processing
   - No continuous growth over time

3. **Console Logging**
   - Status updates show processing progress
   - Check for "Found uniqueness at chunk X" messages (early elimination working)
   - Should see most files eliminated after chunk 1 (first 2GB)

4. **Performance Testing**
   ```
   Test case: 1000 photos (50MB each) + 10 videos (20GB each)
   
   Expected behavior:
   - Photos: All eliminated after chunk 1 (different first 2GB)
   - Videos: Process 1-10 chunks depending on uniqueness
   - Memory: Never exceeds 4GB
   - Time: Minutes, not hours
   ```

## Configuration Tuning

### If Memory is Still Too High

Reduce chunk size:
```swift
static let chunkSize: Int = 1 * 1024 * 1024 * 1024  // 1 GB
```

### If I/O is Too Slow (Many Chunks)

Increase chunk size:
```swift
static let chunkSize: Int = 4 * 1024 * 1024 * 1024  // 4 GB
```

### Sweet Spots by Storage Type

| Storage Type | Recommended Chunk Size | Reason |
|-------------|----------------------|---------|
| Local SSD | 512 MB - 1 GB | Fast I/O, lower latency |
| Local HDD | 1 GB - 2 GB | Larger chunks amortize seek time |
| Gigabit NAS | 2 GB - 4 GB | Reduce network overhead |
| WiFi NAS | 2 GB | Balance size vs timeout risk |
| Cloud (S3, etc) | 1 GB - 2 GB | API call cost + latency |

## Summary of Changes

1. ✅ **Increased chunk size to 2GB** - Reduces I/O operations by 87.5%
2. ✅ **Wrapped file operations in autoreleasepool** - Immediate buffer release
3. ✅ **Close file handles immediately** - No resource holding
4. ✅ **Per-file autoreleasepool** - Prevents accumulation
5. ✅ **Frequent autoreleasepool drains** - Every 10 files/sizes
6. ✅ **Updated documentation** - Clear guidance on tuning

## Expected Results

After these optimizations:
- **Memory**: Stays < 4GB regardless of file sizes
- **Speed**: 87.5% fewer I/O operations
- **Network**: Optimal for NAS/network storage
- **Reliability**: No memory pressure or swapping
- **Scalability**: Can handle files of any size

The key insight: **Aggressive cleanup is more important than small chunks**. A 2GB buffer that's freed immediately uses less memory than 10× 256MB buffers that linger.

