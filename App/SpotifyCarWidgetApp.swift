import SwiftUI

@main
struct SpotifyCarWidgetApp: App {
    @StateObject private var model = PlaybackViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearance = "system"
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model)
                .tint(Color(red: 0.12, green: 0.72, blue: 0.35))
                .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
                .task { model.activate() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.activate() }
                    else if phase == .background { model.suspend() }
                }
        }
    }
}
