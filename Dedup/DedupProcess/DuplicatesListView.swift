import SwiftUI

struct DuplicatesListView: View {
    @ObservedObject var fileProcessor: FileProcessor
    @Binding var selectedFile: FileInfo?
    @State private var selectedDuplicates: Set<FileInfo> = []
    @State private var selectAll = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Duplicate Groups")
                    .font(.headline)
                
                Spacer()
                
                Button(selectAll ? "Deselect All" : "Select All") {
                    if selectAll {
                        selectedDuplicates.removeAll()
                        selectAll = false
                    } else {
                        selectedDuplicates = Set(fileProcessor.duplicateGroups.map { $0.source })
                        selectAll = true
                    }
                }
                .disabled(fileProcessor.duplicateGroups.isEmpty)
                .accessibilityIdentifier("button-selectAllDuplicates")
                
                Button("Delete Selected") {
                    Task {
                        await fileProcessor.deleteSelectedDuplicates(Array(selectedDuplicates))
                        selectedDuplicates.removeAll()
                        selectAll = false
                    }
                }
                .disabled(selectedDuplicates.isEmpty)
                .accessibilityIdentifier("button-deleteSelected")
            }
            .padding(.horizontal)
            
            if fileProcessor.duplicateGroups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No duplicates found")
                        .font(.headline)
                        .accessibilityIdentifier("label-noDuplicates")
                    
                    Text("Select source and target directories, then start processing to see duplicate files.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(fileProcessor.duplicateGroups) { group in
                        HStack {
                            Button(action: {
                                if selectedDuplicates.contains(group.source) {
                                    selectedDuplicates.remove(group.source)
                                } else {
                                    selectedDuplicates.insert(group.source)
                                }
                            }) {
                                Image(systemName: selectedDuplicates.contains(group.source) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(selectedDuplicates.contains(group.source) ? .accentColor : .secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityIdentifier("checkbox-duplicate-\(group.source.id)")
                            
                            DuplicateFileRowView(group: group, fileProcessor: fileProcessor)
                                .onTapGesture {
                                    selectedFile = group.source
                                }
                        }
                        .background(selectedDuplicates.contains(group.source) ? Color.accentColor.opacity(0.2) : Color.clear)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}

