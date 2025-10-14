import SwiftUI
import AVKit
import AppKit

struct ContentView: View {
    @State private var selectedTab = 0
    @State var statusMsg: String = "testing  ..."

    var body: some View
    {
        VStack
        {
            TabView(selection: $selectedTab)
            {
                FileFinderView( statusMsg: $statusMsg )
                    .tabItem
                {
                    Label("Finder", systemImage: "list.bullet")
                }
                .tag(0)
                
                DedupProcessView( statusMsg: $statusMsg )
                    .tabItem
                {
                    Label("Dedup", systemImage: "key.fill")
                }
                .tag(1)
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
