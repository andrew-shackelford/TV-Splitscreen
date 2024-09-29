//
//  TV_Splitscreen_iOSApp.swift
//  TV Splitscreen iOS
//
//  Created by Andrew Shackelford on 9/6/24.
//

import SwiftUI

@main
struct TV_Splitscreen_iOSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().onAppear {
                hideTitleBarOnCatalyst()
            }
        }
    }
    
    func hideTitleBarOnCatalyst() {
#if targetEnvironment(macCatalyst)
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.titlebar?.titleVisibility = .hidden
#endif
    }
}
