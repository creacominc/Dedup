//
//  ContentView.swift
//  dedupswpkg
//
//  Created by Harold Tomlinson on 2023-09-04.
//

import SwiftUI
import Foundation
import CryptoKit
import CommonCrypto

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
                    //self.compareFiles()
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
                                                   , size: fileSize
                                                   , checksum: Data(count: Int(CC_SHA256_DIGEST_LENGTH))
                                                   , sumSize: 0)
                self.files.append( fileData )
                if( self.duplicates[ fileSize ] == nil )
                {
                    self.duplicates[ fileSize ] = [ fileData ]
                    //print( "Created new list for size: \(fileSize) -> \(path)" )
                }
                else
                {
                    // if this is the second element, checksum the first.
                    if( self.duplicates[ fileSize ]!.count == 1 )
                    {
                        // the first was not yet checksummed.  do it now.
                        let firstRes : Data = md5File( url: self.duplicates[fileSize]![0].path )!
                        var dsVal : String = ""
                        firstRes.forEach({ (val) in
                            //print(val)
                            dsVal.append( String(format: "%02hhx", val) )
                        })

                        self.duplicates[ fileSize ]![0].checksum = firstRes
                    }
                    self.duplicates[fileSize]?.append( fileData )
                    let currentRes : Data = md5File(url: pathURL! )!
                    var nsVal : String = ""

                    currentRes.forEach({ (val) in
                        nsVal.append( String(format: "%02hhx", val) )
                    })

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

//
//    func compareFiles()
//    {
//        // for each entry in self.files, add to a map of size->FileData[]
//    }


    func md5File(url: URL) -> Data? {
        let bufferSize = 1024 * 1024
        do {
            // Open file for reading:
            let file = try FileHandle(forReadingFrom: url)
            defer {
                file.closeFile()
            }
            // Create and initialize MD5 context:
            var context = CC_MD5_CTX()
            CC_MD5_Init(&context)
            // Read up to `bufferSize` bytes, until EOF is reached, and update MD5 context:
            while autoreleasepool(invoking: {
                let data = file.readData(ofLength: bufferSize)
                if data.count > 0 {
                    data.withUnsafeBytes {
                        _ = CC_MD5_Update(&context, $0.baseAddress, numericCast(data.count))
                    }
                    return true // Continue
                } else {
                    return false // End of file
                }
            }) { }
            // Compute the MD5 digest:
            var digest: [UInt8] = Array(repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            _ = CC_MD5_Final(&digest, &context)
            return Data(digest)
        } catch {
            print("Cannot open file:", error.localizedDescription)
            return nil
        }
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
