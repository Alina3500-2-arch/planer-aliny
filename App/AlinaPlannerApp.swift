import SwiftUI

@main struct AlinaPlannerApp: App {
    @StateObject private var repository = PlannerRepository()
    var body: some Scene { WindowGroup { RootView().environmentObject(repository) } }
}

