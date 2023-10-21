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
    @State var results : [ResultData] = []
    let exclusions : [String] = [
        ".ssh",
        ".DS_Store",
        "#recycle"
    ]
    let fileKeys : [URLResourceKey] = [
        URLResourceKey.fileSizeKey,
        URLResourceKey.isDirectoryKey,
        URLResourceKey.nameKey,
        URLResourceKey.contentModificationDateKey,
        URLResourceKey.creationDateKey,
        URLResourceKey.fileAllocatedSizeKey,
        URLResourceKey.isAliasFileKey,
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
        .padding()
    }

    func compare()
    {
        self.results.removeAll(keepingCapacity: true)
        // iterate over duplicates to populate results
        self.duplicates.forEach { (fsize: Int, files: [FileData]) in
            if( files.count > 1 )
            {
                print("Processing \(files.count) files of size \(fsize)")
                var checksumMap : [String : [FileData] ] = [:]
                // collect the checksums in a set whose size will equal the files.count when there are no duplicates
                while(( checksumMap.count != files.count ) && (files[0].bytesRead < files[0].size))
                {
                    print( "files[0].bytesRead = \(files[0].bytesRead), files[0].size = \(files[0].size)" )
                    // perform initial md5 on all files of this size and save to set.
                    checksumMap.removeAll(keepingCapacity: true)
                    files.forEach { file in
                        file.md5()
                        if( checksumMap[file.checksum] == nil )
                        {
                            checksumMap[file.checksum] = [file]
                            print( "created checksumMap for checksum: \(file.checksum) for file: \(file.path)")
                        }
                        else
                        {
                            checksumMap[file.checksum]!.append( file )
                            print( "adding to checksum: \(file.checksum)   file: \(file.path)")
                        }
                    }
                }
                // if there are duplicates we will have read the entire of these files. compare the size
                if(files[0].bytesRead == files[0].size)
                {
                    print( "complete read of \(files[0].bytesRead)" )
                    // iterate over the checksumMap to find the duplicates
                    checksumMap.forEach { (csum: String, files: [FileData]) in
                        print("files.count = \(files.count) for checksum \(csum)" )
                        if( files.count > 1 )
                        {
                            let result : ResultData = ResultData( size: fsize, checksum: csum )
                            var separator : String = ""
                            files.forEach { fileData in
                                result.files += separator + fileData.path.path(percentEncoded: false)
                                separator = ", "
                            }
                            print( "result \(result.size), \(result.checksum), \(result.files)" )
                            self.results.append( result )
                        }
                    }
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
            // does it exist and is it a folder
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
                let fileData : FileData = FileData( path: pathURL! )
                self.files.append( fileData )
                if( self.duplicates[ fileData.size ] == nil )
                {
                    self.duplicates[ fileData.size ] = [fileData]
                    print( "Created new list for size: \(fileData.size) -> \(path)" )
                }
                else
                {
                    self.duplicates[ fileData.size ]!.append( fileData )
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
