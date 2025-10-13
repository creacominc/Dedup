import SwiftUI
import AVKit
import AppKit

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            FileFinderView()
                .tabItem {
                    Label("Finder", systemImage: "list.bullet")
                }
                .tag(0)
            
            Text("Tab 2 - Dedup")
                .tabItem {
                    Label("Dedup", systemImage: "key.fill")
                }
                .tag(1)
        }
    }
}


#Preview {
    ContentView()
}
