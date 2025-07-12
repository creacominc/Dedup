# Network Drive Access Setup

## Problem
Your macOS app was getting permission errors when trying to access network drives (NAS):
```
Error Domain=NSCocoaErrorDomain Code=513 "You don't have permission to save the file"
```

## Solution
Added specific entitlements to allow network drive access in `Dedup/Dedup.entitlements`:

### Key Entitlements Added:

1. **`com.apple.security.files.user-selected.read-write`**
   - Allows read/write access to user-selected files and folders

2. **`com.apple.security.files.downloads.read-write`**
   - Allows access to Downloads folder

3. **`com.apple.security.files.bookmarks.app-scope`** and **`com.apple.security.files.bookmarks.document-scope`**
   - Enables file bookmarks for persistent access to network drives

4. **`com.apple.security.network.client`** and **`com.apple.security.network.server`**
   - Enables network access for client/server operations

5. **`com.apple.security.temporary-exception.files.absolute-path.read-write`**
   - Specifically allows access to `/Volumes/` (where network drives are mounted)

6. **`com.apple.security.temporary-exception.files.home-relative-path.read-write`**
   - Allows access to home directory paths

## How to Use Network Drives

1. **Mount the network drive** in Finder first
2. **Select the mounted drive** when choosing source/target directories in the app
3. The app will now have permission to read and write to the network drive

## Testing
- Build the app with: `xcodebuild -project Dedup.xcodeproj -scheme Dedup -configuration Debug build`
- The entitlements should be visible in the build output
- Test by selecting a network drive as source or target directory

## Troubleshooting
If you still get permission errors:
1. Make sure the network drive is properly mounted in Finder
2. Check that the user has proper permissions on the NAS
3. Try unmounting and remounting the network drive
4. Restart the app after mounting the network drive

## Security Note
These entitlements grant broad file system access. The app is designed for file management operations and needs these permissions to function properly. 