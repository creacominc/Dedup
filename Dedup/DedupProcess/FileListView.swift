import SwiftUI

struct FileListView: View
{
    @ObservedObject var fileProcessor: FileProcessor
    @Binding var selectedFile: FileInfo?
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Dedup")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityIdentifier("app-title")
                
                Text("Media File Deduplication Tool")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("app-subtitle")
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            // Tab buttons
            HStack(spacing: 0) {
                tabButton(title: "Files to Move", index: 0, systemImage: "folder.badge.plus", identifier: "tabButton-filesToMove", isEnabled: fileProcessor.processingState == .done)
                tabButton(title: "Duplicates", index: 1, systemImage: "doc.on.doc", identifier: "tabButton-duplicates", isEnabled: fileProcessor.processingState == .done)
                tabButton(title: "Settings", index: 2, systemImage: "gear", identifier: "tabButton-settings", isEnabled: true)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .background(Color(NSColor.windowBackgroundColor))
            
            // File list content
            Group {
                if selectedTab == 0 {
                    FilesToMoveListView(fileProcessor: fileProcessor, selectedFile: $selectedFile)
                } else if selectedTab == 1 {
                    DuplicatesListView(fileProcessor: fileProcessor, selectedFile: $selectedFile)
                } else {
                    SettingsView(fileProcessor: fileProcessor, selectedTab: $selectedTab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: fileProcessor.isProcessing) { oldValue, newValue in
            // Automatically switch to Files to Move tab when processing starts
            if newValue && selectedTab != 0 {
                selectedTab = 0
            }
        }
        .onChange(of: fileProcessor.processingState) { oldValue, newValue in
            // Automatically switch to Files to Move tab when processing is done
            if newValue == .done && selectedTab != 0 {
                selectedTab = 0
            }
        }
    }
    
    // Custom tab button styled as a segmented control
    @ViewBuilder
    private func tabButton(title: String, index: Int, systemImage: String, identifier: String, isEnabled: Bool) -> some View {
        Button(action: { 
            if isEnabled {
                selectedTab = index
                selectedFile = nil // Clear selection when switching tabs
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(selectedTab == index ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundColor(selectedTab == index ? Color.accentColor : (isEnabled ? Color.primary : Color.secondary))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(selectedTab == index ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: selectedTab == index ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .accessibilityIdentifier(identifier)
    }
}

