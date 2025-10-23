//
//  NebulaApp.swift
//  Nebula
//
//  Created by Gonzalo Cruz Cortes on 10/21/25.
//

import SwiftUI

@main
struct NebulaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            SplashScreen()
        }
    }
}
