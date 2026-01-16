import SwiftUI

@main
struct AIDebateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 700)
        }
    }
}

struct ContentView: View {
    var body: some View {
        WebHomepageView()
    }
}
