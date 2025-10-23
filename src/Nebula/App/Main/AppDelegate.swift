//
//  AppDelegate.swift
//  Nebula
//
//  Created by Gonzalo Cruz Cortes on 10/21/25.
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let window = NSApp.windows.first else { return }

            window.styleMask = [.borderless, .miniaturizable, .fullSizeContentView]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.isMovableByWindowBackground = true
            window.setContentSize(CGSize(width: 700, height: 480))
            window.center()

            let customContentView = NebulaContentView(frame: window.contentView?.bounds ?? .zero)
            customContentView.autoresizingMask = [.width, .height]
            window.contentView = customContentView

            self.window = window

            self.setupDesktopFlareEffect(for: window)
        }
    }

    private func setupDesktopFlareEffect(for window: NSWindow) {
        OverlayManager.shared.initialize(with: window)
        OverlayManager.shared.enableOverlay()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
