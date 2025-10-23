//
//  OverlayController.swift
//  Nebula
//
//  Central controller that manages the overlay system
//  Coordinates between main window, overlay window, and flare effect
//  Created by Gonzalo Cruz Cortes on 10/21/25.
//

import Cocoa
import SwiftUI
import Combine

// MARK: - Overlay Manager
class OverlayManager: ObservableObject {
    // Singleton instance
    static let shared = OverlayManager()

    // Components
    private var overlayWindowController: OverlayWindowController?
    private var trackingCoordinator: WindowTrackingCoordinator?
    private var mainWindow: NSWindow?

    // Published state
    @Published var isOverlayEnabled: Bool = false {
        didSet {
            updateOverlayState()
        }
    }

    @Published var flareIntensity: Float = 1.0
    @Published var windowCenter: CGPoint = .zero

    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupBindings()
    }

    // MARK: - Public Methods
    func initialize(with window: NSWindow) {
        mainWindow = window

        overlayWindowController = OverlayWindowController(window: nil)

        trackingCoordinator = WindowTrackingCoordinator(overlayController: overlayWindowController)

        trackingCoordinator?.startTracking(window: window)

        WindowTracker.shared.$windowCenter
            .sink { [weak self] center in
                self?.windowCenter = WindowTracker.shared.convertToFlareCoordinates(center)
                self?.overlayWindowController?.updateWindowCenter(self?.windowCenter ?? .zero)
            }
            .store(in: &cancellables)

        overlayWindowController?.hideOverlay()
    }

    func enableOverlay() {
        isOverlayEnabled = true
    }

    func disableOverlay() {
        isOverlayEnabled = false
    }

    func toggleOverlay() {
        isOverlayEnabled.toggle()
    }

    // MARK: - Private Methods
    private func setupBindings() {
        // Additional bindings can be set up here
    }

    private func updateOverlayState() {
        if isOverlayEnabled {
            showOverlay()
        } else {
            hideOverlay()
        }
    }

    private func showOverlay() {
        print("DEBUG: Attempting to show overlay")

        // Check for required permissions first
        if !checkPermissions() {
            // print("DEBUG: No permissions, requesting...")
            requestPermissions()
            return
        }

        // print("DEBUG: Showing overlay window")
        overlayWindowController?.showOverlay()

        // Debug: Check window info
        /*
        if let window = overlayWindowController?.window {
            print("DEBUG: Overlay window frame: \(window.frame)")
            print("DEBUG: Overlay window level: \(window.level)")
            print("DEBUG: Overlay window visible: \(window.isVisible)")
        }
         */
    }

    private func hideOverlay() {
        overlayWindowController?.hideOverlay()
    }

    // TEMP:
    private func checkPermissions() -> Bool {
        return true
    }

    private func requestPermissions() {
        // print("Screen recording permissions required for overlay effect")
    }

    // MARK: - Configuration Methods
    func updateFlareConfig(_ config: AnamorphicFlareConfig) {
        // empty
    }

    func setFlareIntensity(_ intensity: Float) {
        flareIntensity = clamp(intensity, min: 0.0, max: 2.0)
    }

    private func clamp<T: Comparable>(_ value: T, min minValue: T, max maxValue: T) -> T {
        return min(max(value, minValue), maxValue)
    }
}

// MARK: - Overlay Content Hosting View
class OverlayHostingView: NSHostingView<OverlayContentViewWrapper> {
    required init(rootView: OverlayContentViewWrapper) {
        super.init(rootView: rootView)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.layer?.isOpaque = false
    }
}

// MARK: - Overlay Content View Wrapper
struct OverlayContentViewWrapper: View {
    @StateObject private var manager = OverlayManager.shared
    @State private var localWindowCenter: CGPoint = .zero

    var body: some View {
        OverlayContentView()
            .environmentObject(manager)
            .onReceive(manager.$windowCenter) { center in
                localWindowCenter = center
            }
    }
}

// MARK: - Hotkey Manager (Optional)
class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventMonitor: Any?

    private init() {}

    func setupHotkeys() {
        // Monitor for global hotkeys to toggle overlay
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // monitor local events
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // EMERGENCY CLOSE: ESC key immediately disables overlay
        if event.keyCode == 53 { // ESC key
            OverlayManager.shared.disableOverlay()
            print("Emergency: Overlay disabled with ESC")
            return
        }

        // Check for specific key combination (e.g., Cmd+Shift+F)
        if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 3 { // 'F' key
            OverlayManager.shared.toggleOverlay()
        }
    }

    func cleanup() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - Debug Overlay View (for testing)
struct DebugOverlayView: View {
    @EnvironmentObject var manager: OverlayManager

    var body: some View {
        VStack {
            Text("Overlay Active")
                .font(.largeTitle)
                .foregroundColor(.white)
                .shadow(radius: 10)

            Text("Window Center: \(Int(manager.windowCenter.x)), \(Int(manager.windowCenter.y))")
                .font(.caption)
                .foregroundColor(.white)

            Slider(value: $manager.flareIntensity, in: 0...2) {
                Text("Intensity")
            }
            .frame(width: 200)
            .padding()
            .background(Color.black.opacity(0.5))
            .cornerRadius(10)
        }
        .padding()
    }
}

// MARK: - Overlay Preferences (for persistence)
struct OverlayPreferences: Codable {
    var isEnabled: Bool = false
    var intensity: Float = 1.0
    var streakLength: Float = 2.0
    var chromaticAberration: Float = 1.0
    var useCustomColors: Bool = true

    static let userDefaultsKey = "NebulaOverlayPreferences"

    static func load() -> OverlayPreferences {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let prefs = try? JSONDecoder().decode(OverlayPreferences.self, from: data) {
            return prefs
        }
        return OverlayPreferences()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: OverlayPreferences.userDefaultsKey)
        }
    }
}
