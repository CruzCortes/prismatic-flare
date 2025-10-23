//
//  OverlayWindow.swift
//  Nebula
//
//  Transparent overlay window that covers the entire screen
//  Displays the anamorphic lens flare effect above all other windows
//  Created by Gonzalo Cruz Cortes on 10/21/25.
//

import Cocoa
import SwiftUI
import Combine

// MARK: - Overlay Window
class OverlayWindow: NSWindow {

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        setupWindow()
    }

    private func setupWindow() {
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false

        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)

        self.ignoresMouseEvents = true

        self.alphaValue = 1.0

        // Configure window behavior for desktop-level background
        self.collectionBehavior = [
            .canJoinAllSpaces,      // Visible on all spaces
            .stationary,            // Doesn't move with spaces
            .ignoresCycle,          // Not included in window cycling
            .transient              // Doesn't show in mission control
        ]

        self.animationBehavior = .none

        self.styleMask = [.borderless]

    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Overlay Content View
struct OverlayContentView: View {
    @StateObject private var flareConfig = AnamorphicFlareConfig()
    @State private var windowCenter: CGPoint = .zero
    @State private var updateTimer: Timer?

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()

            AnamorphicFlareView(config: flareConfig, windowCenter: $windowCenter)
                .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            setupWindowTracking()
        }
        .onDisappear {
            updateTimer?.invalidate()
        }
    }

    private func setupWindowTracking() {
        // print("DEBUG: Setting up window tracking")

        if let mainWindow = NSApp.windows.first(where: { $0.contentView is NebulaContentView }) {
            WindowTracker.shared.trackWindow(mainWindow)
            // print("DEBUG: Tracking main window")
        }

        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { _ in
            guard let trackedWindow = NSApp.windows.first(where: { $0.contentView is NebulaContentView }) else { return }

            let windowFrame = trackedWindow.frame
            let windowCenterX = windowFrame.midX
            let windowCenterY = windowFrame.midY

            self.windowCenter = CGPoint(x: windowCenterX, y: windowCenterY)
        }

        // print("DEBUG: Flare config - intensity: \(flareConfig.intensity), enabled: \(flareConfig.isEnabled)")
    }
}

// MARK: - Anamorphic Flare Configuration
class AnamorphicFlareConfig: ObservableObject {
    @Published var intensity: Float = 2.0
    @Published var streakLength: Float = 3.0
    @Published var streakWidth: Float = 1.0
    @Published var falloffPower: Float = 1.0
    @Published var chromaticAberration: Float = 0.0
    @Published var rayCount: Int32 = 8
    @Published var threshold: Float = 0.05
    @Published var tintColor: Color = Color(red: 0.2, green: 0.7, blue: 1.0, opacity: 0.5)
    @Published var dispersion: Float = 0.4
    @Published var noiseAmount: Float = 0.0
    @Published var rotationAngle: Float = 0.0
    @Published var glowRadius: Float = 0.8
    @Published var edgeFade: Float = 1.0
    @Published var isEnabled: Bool = true

    @Published var flareColors: [Color] = [
        Color(red: 0.1, green: 0.3, blue: 1.0, opacity: 0.3),   // Blue
        Color(red: 0.0, green: 0.7, blue: 1.0, opacity: 0.3),   // Cyan
        Color(red: 0.0, green: 0.8, blue: 0.4, opacity: 0.3),   // Green
        Color(red: 0.0, green: 0.6, blue: 0.7, opacity: 0.3),   // Teal
        Color(red: 1.0, green: 0.5, blue: 0.0, opacity: 0.3),   // Orange
        Color(red: 0.2, green: 0.5, blue: 0.9, opacity: 0.3)    // Light blue
    ]
}

// MARK: - Overlay Window Controller
class OverlayWindowController: NSWindowController {
    private var overlayWindow: OverlayWindow?
    private var contentView: NSHostingView<OverlayContentView>?

    override init(window: NSWindow?) {
        super.init(window: window)
        setupOverlayWindow()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupOverlayWindow() {
        guard let mainScreen = NSScreen.main else { return }
        let screenFrame = mainScreen.frame

        // print("DEBUG: Creating overlay on main screen: \(screenFrame)")

        overlayWindow = OverlayWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        let overlayContent = OverlayContentView()
        contentView = NSHostingView(rootView: overlayContent)
        contentView?.frame = CGRect(origin: .zero, size: screenFrame.size)

        overlayWindow?.contentView = contentView
        overlayWindow?.orderFront(nil)

        self.window = overlayWindow
    }

    func showOverlay() {
        overlayWindow?.orderFront(nil)
    }

    func hideOverlay() {
        overlayWindow?.orderOut(nil)
    }

    func updateWindowCenter(_ center: CGPoint) {
        // keeping this for later
    }
}
