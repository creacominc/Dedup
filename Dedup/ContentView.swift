//
//  ContentView.swift
//  dedupswpkg
//
//  Created by Harold Tomlinson on 2023-09-04.
//

import SwiftUI


struct ContentView: View {
    
    @State var trgPath : URL?
    @State var showFileChooser = false
    @State var files : [FileData] = [ ]
    let exclusions : [String] = [
        ".ssh",
        ".DS_Store",
        "#recycle"
    ]
    let fileKeys : [URLResourceKey] = [
        URLResourceKey.nameKey,
        URLResourceKey.isDirectoryKey,
        URLResourceKey.contentModificationDateKey,
        URLResourceKey.creationDateKey,
        URLResourceKey.fileAllocatedSizeKey,
        URLResourceKey.fileSizeKey,
        URLResourceKey.isAliasFileKey,
        URLResourceKey.isDirectoryKey,
        URLResourceKey.isReadableKey,
        URLResourceKey.isRegularFileKey,
        URLResourceKey.isSymbolicLinkKey,
    ]

    var body: some View
    {
        VStack
        {
            // Top row: Source button and path.
            HStack
            {
                Button("Select Source Path")
                {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    if panel.runModal() == .OK
                    {
                        self.trgPath = panel.url
                    }
                    print( "path: \(String(describing: self.trgPath))" )
                }
                Text(  verbatim: self.trgPath?.absoluteString ?? "nil" )
            }
            // Second Row:  Start button and scroll view.
            HStack
            {
                Button("Start")
                {
                    print( "Start button pressed.  Path=\(String(describing: self.trgPath))" )
                    self.files.removeAll()
                    let fm = FileManager.default
                    addFiles(pathURL: self.trgPath, fm: fm)
                    print( "done adding files.  comparing." )
                }
                ScrollView
                {
                    VStack(alignment: .leading)
                    {
                        ForEach( self.files )
                        { element in
                            Text( element.path )
                        }
                    }
                }
            }
            // Third row:  Error window
//            HStack
//            {
//                
//            }
        }
        .padding()
    }

    func addFiles( pathURL : URL?, fm : FileManager )
    {
        do {
            // is it nil
            if( pathURL == nil )
            {
                print( "addFiles: path is nil, returning." )
                return
            }
            let path : String = pathURL!.path(percentEncoded: false)
            // does it exist
            var isDirectory = ObjCBool(false)
            let exists = fm.fileExists(atPath: path, isDirectory: &isDirectory)
            if( exists == false )
            {
                print( "File does not exist.  path = \(path)" )
                return
            }
            // file exists, if it is in the exclusion list, ignore it.
            if( exclusions.contains( pathURL!.lastPathComponent ) )
            {
                return
            }
            // file exists, if it is a folder, add it to the list
            if( isDirectory.boolValue == false )
            {
                // get the file size
                let fileAttributes = try pathURL?.resourceValues(forKeys: Set(self.fileKeys) )
                self.files.append(
                    FileData(path: path
                             , size: Int64(fileAttributes!.fileSize!)
                             , checksum: ""
                             , sumSize: 0)
                )
            }
            else
            {
                // recursive search of directories
                let items = try fm.contentsOfDirectory(
                    at: pathURL!,
                    includingPropertiesForKeys: self.fileKeys
                )
                for item in items
                {
                    addFiles( pathURL: item, fm: fm )
                }
            }
        } catch {
            // failed to read directory – bad permissions, perhaps?
            print( "ERROR:  Failed to handle the search - \(error)" )
        }
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
