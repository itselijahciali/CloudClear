//
//  CloudClearApp.swift
//  CloudClear
//
//  Created by Elijah Ciali on 6/23/23.
//

import SwiftUI
import Photos

@main
struct CloudClearApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .windowStyle(HiddenTitleBarWindowStyle())
        #endif
    }
    
}
