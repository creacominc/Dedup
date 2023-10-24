//
//  ContentView.swift
//  dedupswpkg
//
//  Created by Harold Tomlinson on 2023-09-04.
//

import SwiftUI
import Foundation


struct ContentView: View
{

    @State var trgPath : URL?
    @State var files : [FileData] = []
    @State var duplicates : [ Int: [FileData] ] = [:]
    @State var results : [ResultData] = []
    @State var okToRunAsync : Bool = false
    @State var controlButtonLabel : String = "Start"
    @State var controlButtonDisabled : Bool = true
    @State private var progressLimit = 0.0
    @State private var progressValue = 0.0
    @State private var progressLabel : String = ""

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
                        //print( "path: \(self.trgPath!.path(percentEncoded: false))" )
                        self.files.removeAll(keepingCapacity: true)
                        self.duplicates.removeAll(keepingCapacity: true)
                        // enable the control button
                        self.controlButtonDisabled = false
                    }
                }
                Text(  verbatim: self.trgPath?.path(percentEncoded: false) ?? "nil" )
            }
            // Second Row:  Start button and scroll view.
            HStack
            {
                Button( self.controlButtonLabel )
                {
                    print( "Start button pressed.  Path=\(String(describing: self.trgPath))" )
                    self.okToRunAsync = true
                    self.controlButtonLabel = "Stop"
                    Task
                    {
                        await self.findDuplicates()
                    }
//                    self.controlButtonLabel = "Start"
//                    self.okToRunAsync = false
                }
                .disabled( self.controlButtonDisabled )
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
                    { element in
                        HStack
                        {
                            Text( "Size: \(element.size)" )
                            Text( "Sum: \(element.checksum)" )
                            Text( "Count: \(element.fcount)" )
                            Text( element.getFiles() )
                        }
//                        element.files.forEach({ file in
//                            HStack
//                            {
//                                Text( "~" )
//                                Text( "~" )
//                                Text( "~" )
//                                Text( "Files: \(file)" )
//                            }
//                        })
                    }
                }
            }
            // Last row: progress bar
            ProgressView( self.progressLabel, value: self.progressValue, total: self.progressLimit )
        }
        .padding()
    }

    func findDuplicates() async
    {
        self.progressLabel = "Searching: "
        self.progressValue = 0.0
//        for number in 1...Int(self.progressLimit)
//        {
//            sleep( UInt32( 1 ) )
//            self.progressValue = Double(number)
//            self.progressLabel = String( number )
//        }

        self.files.removeAll(keepingCapacity: true)
        self.duplicates.removeAll(keepingCapacity: true)
        let fm = FileManager.default
        self.addFiles(pathURL: self.trgPath, fm: fm)
        self.progressLimit = Double(self.files.count)
        self.progressLabel = "Comparing: "
        print( "Done adding files.  comparing." )
        self.results.removeAll(keepingCapacity: true)
        duplicates.forEach { (fsize: Int, files: [FileData]) in
            self.compare( files: files )
            self.progressValue += Double(files.count)
        }

        self.controlButtonLabel = "Start"
        self.okToRunAsync = false
        self.progressLabel = "Done"
        print( "Done" )
    }

    func compare( files: [FileData] )
    {
        /**
         * iterate over duplicates to populate results
         * do only one pass, then call recursively.
         */
//        print("Processing \(files.count) files,"
//              + "    files[0].bytesRead = \(files[0].bytesRead), "
//              + "    files[0].size = \(files[0].size)")

        var checksumMap : [String : [FileData] ] = [:]
        /**
         * Collect the checksums in a set whose size will equal the files.count when there are no duplicates.
         */
        files.forEach
        { file in
            file.md5()
            if( checksumMap[file.checksum] == nil )
            {
                checksumMap[file.checksum] = [file]
                // print( "created checksumMap for checksum: \(file.checksum) for file: \(file.path)")
            }
            else
            {
                checksumMap[file.checksum]!.append( file )
                // print( "adding to checksum: \(file.checksum)   file: \(file.path)")
            }
        }
        /**
         * For each checksum group, if there are more than one file, and if we have not read the entire file, recursively call compare.
         */
        checksumMap.forEach
        { (csum: String, files: [FileData]) in
            if( files.count > 1 )
            {
                /**
                 * We can only determine that this is a duplicate if there are more than one with the same checksum that we have completely read.
                 * Iterate through the checksumMap and test the bytesRead for the first of each set with more than one.
                 */
                if(files[0].bytesRead == files[0].size)
                {
                    print( "Complete read of \(files[0].bytesRead) for \(files[0].path.path(percentEncoded: false))" )
                    print("files.count = \(files.count) for checksum \(csum)" )
                    let result : ResultData = ResultData( size: files[0].size, checksum: csum )
                    files.forEach
                    { fileData in
                        result.AddFile( file: fileData.path.path(percentEncoded: false) )
                    }
                    print( "Result \(result.size), \(result.checksum), \(result.files)" )
                    self.results.append( result )
                }
                else
                {
                    // recursive call to compare with each group in the checksumMap
                    print( "Recursive call with \(files.count) files.")
                    self.compare(files: files )
                }
            }  // files.count > 1
//            else
//            {
//                print( "file \(files[0].path.path(percentEncoded: false)) is unique.")
//            }
        } // for each checksumMap

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
                    // print( "Created new list for size: \(fileData.size) -> \(path)" )
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
