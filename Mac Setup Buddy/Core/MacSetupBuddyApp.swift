//  Created by Sebastian Santos on October 4, 2025

import SwiftUI

@main
struct MacSetupBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // DISABLED: Let AppDelegate handle all window creation
        // This prevents duplicate windows
        Settings {
            EmptyView()
        }
    }
}
