//
//  ContentView.swift
//  dedupswpkg
//
//  Created by Harold Tomlinson on 2023-09-04.
//

import SwiftUI
import Foundation

struct ContentView: View {
    
    @State var trgPath : URL?
    @State var files : [FileData] = []
    @State var duplicates : [ Int: [FileData] ] = [:]
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
                    //print( "path: \(self.trgPath!.path(percentEncoded: false))" )
                    self.files.removeAll(keepingCapacity: true)
                    self.duplicates.removeAll(keepingCapacity: true)
                }
                Text(  verbatim: self.trgPath?.path(percentEncoded: false) ?? "nil" )
            }
            // Second Row:  Start button and scroll view.
            HStack
            {
                Button("Start")
                {
                    print( "Start button pressed.  Path=\(String(describing: self.trgPath))" )
                    self.files.removeAll(keepingCapacity: true)
                    self.duplicates.removeAll(keepingCapacity: true)
                    let fm = FileManager.default
                    self.addFiles(pathURL: self.trgPath, fm: fm)
                    print( "done adding files.  comparing." )
                    self.compareFiles()
                }
                ScrollView
                {
                    VStack(alignment: .leading)
                    {
                        ForEach( self.files )
                        { element in
                            Text( element.path.path(percentEncoded: false) )
                        }
                    }
                }
            }
            // Third row:  Results window
            
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
            if( self.exclusions.contains( pathURL!.lastPathComponent ) )
            {
                return
            }
            // file exists, if it is a folder, add it to the list
            if( isDirectory.boolValue == false )
            {
                // get the file size
                let fileAttributes = try pathURL?.resourceValues(forKeys: Set(self.fileKeys) )
                let fileSize : Int = fileAttributes!.fileSize!
                let fileData : FileData = FileData(path: pathURL!
                                                   , size: fileSize)
                self.files.append( fileData )
                if( self.duplicates[ fileSize ] == nil )
                {
                    self.duplicates[ fileSize ] = [ fileData ]
                    print( "Created new list for size: \(fileSize) -> \(path)" )
                }
                else
                {
                    // if this is the second element, checksum the first.
                    if( self.duplicates[ fileSize ]!.count == 1 )
                    {
                        // the first was not yet checksummed.  do it now.
                        let firstRes : Data = self.duplicates[fileSize]![0].md5File()!
                        var dsVal : String = ""
                        firstRes.forEach({ (val) in
                            dsVal.append( String(format: "%02hhx", val) )
                        })

                        self.duplicates[ fileSize ]![0].checksum = firstRes
                        print( "first sum: \(dsVal)")
                    }
                    self.duplicates[fileSize]?.append( fileData )
                    let currentRes : Data = fileData.md5File()!
                    var nsVal : String = ""

                    currentRes.forEach({ (val) in
                        nsVal.append( String(format: "%02hhx", val) )
                    })
                    print( "current sum: \(nsVal)")
                }
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
                    self.addFiles( pathURL: item, fm: fm )
                }
            }
        } catch {
            // failed to read directory – bad permissions, perhaps?
            print( "ERROR:  Failed to handle the search - \(error)" )
        }
    }


    func compareFiles()
    {
        // for each entry in self.files, add to a map of size->FileData[]
    }



}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
