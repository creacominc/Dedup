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
    @State var duplicates : [ Int: [ String: [FileData] ] ] = [:]
    @State var results : [ResultData] = []
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
                    self.compare()
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
            ScrollView
            {
                VStack(alignment: .leading)
                {
                    ForEach( self.results )
                    {
                        element in
                        if( element.count > 0 )
                        {
                            HStack
                            {
                                Text( "Size: \(element.size)" )
                                Text( "Sum: " + element.checksum )
                                Text( "Count: \(element.count)" )
                                Text( "Files: " + element.files )
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }

    func compare()
    {
        // iterate over duplicates to populate results
        self.duplicates.forEach { (fsize: Int, csums: [String : [FileData]]) in
            csums.forEach { (csum: String, files: [FileData]) in
                if( files.count >= 0 )
                {
                    let result : ResultData = ResultData( size: fsize, checksum: csum )
                    var separator : String = ""
                    files.forEach { fileData in
                        result.files += separator + fileData.path.path(percentEncoded: false)
                        separator = ", "
                    }
                    self.results.append( result )
                }
            }
        }
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
                    self.duplicates[ fileSize ] = [ fileData.checksum: [fileData] ]
                    print( "Created new list for size: \(fileSize) -> \(path)" )
                }
                else
                {
                    if( self.duplicates[ fileSize ]![ fileData.checksum ] == nil )
                    {
                        self.duplicates[ fileSize ]![ fileData.checksum ] = [fileData]
                    }
                    else
                    {
                        self.duplicates[ fileSize ]![ fileData.checksum ]!.append( fileData )
                    }
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

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
