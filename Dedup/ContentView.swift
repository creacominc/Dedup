//
//  ContentView.swift
//  dedupswpkg
//
//  Created by Harold Tomlinson on 2023-09-04.
//

import SwiftUI


struct ContentView: View {

    @State var path : String = "/"
    @State var showFileChooser = false
    @State var files : [FileData] = [
//        FileData(path: "First", size: 1, checksum: "aaaa", sumSize: 1),
//        FileData(path: "Second", size: 2, checksum: "bbbb", sumSize: 2),
//        FileData(path: "Third", size: 3, checksum: "cccc", sumSize: 3),
//        FileData(path: "Fourth", size: 4, checksum: "dddd", sumSize: 4),
    ]

    var body: some View
    {
        VStack
        {
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
                        self.path = panel.url?.path() ??
                        "~/"
                    }
                }
                Text(  verbatim: self.path )
            }
            HStack
            {
                Button("Start")
                {
                    self.files.append(
                        FileData(path: self.path, size: 0, checksum: "", sumSize: 0)
                    )
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
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
