import SwiftUI

@main
struct CookieStudioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Theme.amber)
                .preferredColorScheme(.dark)
        }
    }
}
