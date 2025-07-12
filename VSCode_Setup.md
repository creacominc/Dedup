# VSCode/Cursor Setup for Dedup Project

This project is configured to work with VSCode/Cursor for development, building, testing, and debugging.

## Prerequisites

1. **Xcode** - Required for building macOS apps
2. **Swift** - Should be installed with Xcode
3. **VSCode/Cursor Extensions**:
   - Swift Language Server (if available)
   - LLDB Debugger extension

## Available Tasks

### Build Tasks
- **Build Dedup** (`Cmd+Shift+P` → "Tasks: Run Task" → "Build Dedup")
  - Builds the project using xcodebuild
- **Clean Build** (`Cmd+Shift+P` → "Tasks: Run Task" → "Clean Build")
  - Cleans the project before building
- **Build and Prepare Debug** (`Cmd+Shift+P` → "Tasks: Run Task" → "Build and Prepare Debug")
  - Builds the project and copies the app to a predictable location for debugging

### Test Tasks
- **Test Dedup** (`Cmd+Shift+P` → "Tasks: Run Task" → "Test Dedup")
  - Runs all unit tests and UI tests

### Debug Tasks
- **Debug Dedup** (F5 or `Cmd+Shift+P` → "Debug: Start Debugging")
  - Builds, prepares the app, and launches the debugger
- **Debug Dedup (Direct)** (`Cmd+Shift+P` → "Debug: Start Debugging" → "Debug Dedup (Direct)")
  - Launches the debugger directly from DerivedData (faster, but requires manual build)
- **Attach to Dedup** (`Cmd+Shift+P` → "Debug: Start Debugging" → "Attach to Dedup")
  - Attaches to an already running Dedup process

## Debugging Configuration

The project includes multiple debugging configurations:

1. **Debug Dedup** (Recommended)
   - Automatically builds and copies the app to `./build/Debug/Dedup.app`
   - Most reliable for development
   - Uses the "Build and Prepare Debug" task

2. **Debug Dedup (Direct)**
   - Launches directly from Xcode's DerivedData folder
   - Faster startup, but requires manual build first
   - Good for quick debugging sessions

3. **Attach to Dedup**
   - Attaches to an already running Dedup process
   - Useful for debugging issues that occur after launch

## File Structure

```
.vscode/
├── settings.json          # VSCode/Cursor settings
├── tasks.json            # Build and test tasks
├── launch.json           # Debug configurations
└── find-app.sh          # Helper script (legacy)

build/
└── Debug/
    └── Dedup.app/       # Copied app for debugging
```

## Troubleshooting

### Debug Launch Fails
If the debug launch fails with "executable not found":

1. **Try "Debug Dedup"** - This automatically copies the app to the correct location
2. **Check DerivedData** - Ensure the app was built successfully
3. **Run "Build and Prepare Debug"** - This manually copies the app

### Build Errors
- Clean the project: `Cmd+Shift+P` → "Tasks: Run Task" → "Clean Build"
- Check Xcode for any build issues
- Ensure all dependencies are installed

### Test Failures
- Some tests may fail if specific file formats aren't supported
- RAW file tests are expected to fail until RAW support is implemented
- UI tests require the app to be built successfully

## Development Workflow

1. **Start Development**:
   - Open the project in VSCode/Cursor
   - Use `F5` to build and debug

2. **Quick Testing**:
   - Use `Cmd+Shift+P` → "Tasks: Run Task" → "Test Dedup"

3. **Build Only**:
   - Use `Cmd+Shift+P` → "Tasks: Run Task" → "Build Dedup"

4. **Clean Rebuild**:
   - Use `Cmd+Shift+P` → "Tasks: Run Task" → "Clean Build"

## Notes

- The `.build` folder is excluded from the project to prevent conflicts
- Build artifacts are automatically copied to `./build/Debug/` for debugging
- The project uses Xcode's DerivedData for builds, but copies to a predictable location for VSCode/Cursor
- All tasks use xcodebuild for consistency with Xcode development 