import SwiftUI
import AVKit
import AppKit

struct ContentView: View {
    @State private var selectedTab = 0
    @State var statusMsg: String = "testing  ..."
    @State var mergedFileSetBySize = FileSetBySize()

    var body: some View
    {
        VStack
        {
            TabView(selection: $selectedTab)
            {
                // file selection, stats, and processing
                FileFinderView( statusMsg: $statusMsg,
                                mergedFileSetBySize: $mergedFileSetBySize )
                    .tabItem
                    {
                        Label("Finder", systemImage: "list.bullet")
                    }
                    .tag(0)

                // files to move
                FilesToMoveListView( statusMsg: $statusMsg,
                                    mergedFileSetBySize: $mergedFileSetBySize )
                    .tabItem
                    {
                        Label( "Unique", systemImage: "doc.fill" )
                    }
                    .tag(1)

                // duplicate files
                DuplicatesListView( statusMsg: $statusMsg,
                                    mergedFileSetBySize: $mergedFileSetBySize )
                    .tabItem
                    {
                        Label( "Duplicates", systemImage: "doc.on.doc.fill" )
                    }
                    .tag(2)

            } // tab view

            Text( statusMsg )
                .padding()
                .frame(maxWidth: .infinity)
                .background( Color.gray.opacity(0.1) )
                .cornerRadius(8)
            Spacer()
        }
    }
}


#Preview {
    ContentView()
}
