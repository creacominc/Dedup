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
    @State var files : [FileData] = [
        //        FileData(path: "First", size: 1, checksum: "aaaa", sumSize: 1),
        //        FileData(path: "Second", size: 2, checksum: "bbbb", sumSize: 2),
        //        FileData(path: "Third", size: 3, checksum: "cccc", sumSize: 3),
        //        FileData(path: "Fourth", size: 4, checksum: "dddd", sumSize: 4),
    ]
    let exclusions : [String] = [
        ".ssh",
        ".DS_Store",
        "#recycle"
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
                    print( "done loop" )
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
            // print( "addFiles: URL = \(String(describing: pathURL))" )
            if( pathURL == nil )
            {
                print( "addFiles: path is nil, returning." )
                return
            }
            let path : String = pathURL!.path(percentEncoded: false)
            print( "addFiles: Path = \(path)" )
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
                print( "Excluding path \(path) due to \(pathURL!.lastPathComponent)")
                return
            }
            // file exists, if it is a folder, add it to the list
            if( isDirectory.boolValue == false )
            {
                print("Found \(path)")
                self.files.append(
                    FileData(path: path, size: 0, checksum: "", sumSize: 0)
                )
            }
            else
            {
                // recursive search of directories
                let items = try fm.contentsOfDirectory(atPath: path)
                for item in items
                {
                    let content : URL = (pathURL!.appending(path: item))
                    addFiles( pathURL: content, fm: fm )
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
