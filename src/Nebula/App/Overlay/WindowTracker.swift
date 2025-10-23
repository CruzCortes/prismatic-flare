//
//  WindowTracker.swift
//  Nebula
//
//  Tracks the position and size of the main Nebula window
//  Provides real-time updates for the anamorphic flare effect positioning
//  Created by Gonzalo Cruz Cortes on 10/21/25.
//

import Cocoa
import Combine

// MARK: - Window Tracker
class WindowTracker: ObservableObject {
    // Published properties for reactive updates
    @Published var windowCenter: CGPoint = .zero
    @Published var windowFrame: CGRect = .zero
    @Published var isWindowVisible: Bool = true

    // Reference to the main window
    private weak var trackedWindow: NSWindow?

    // Observers
    private var frameObserver: NSObjectProtocol?
    private var visibilityObserver: NSObjectProtocol?
    private var moveObserver: NSObjectProtocol?
    private var resizeObserver: NSObjectProtocol?

    // Timer for periodic updates (fallback)
    private var updateTimer: Timer?

    // Singleton instance for global access
    static let shared = WindowTracker()

    private init() {
        setupObservers()
    }

    // MARK: - Public Methods
    func trackWindow(_ window: NSWindow) {
        stopTracking()
        trackedWindow = window
        updateWindowInfo()
        startWindowObservers()
        startUpdateTimer()
    }

    func stopTracking() {
        removeObservers()
        stopUpdateTimer()
        trackedWindow = nil
    }

    // MARK: - Private Methods
    private func setupObservers() {
        // Initial setup if needed
    }

    private func startWindowObservers() {
        guard let window = trackedWindow else { return }

        frameObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.updateWindowInfo()
        }

        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.updateWindowInfo()
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didMiniaturizeNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.isWindowVisible = false
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didDeminiaturizeNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.isWindowVisible = true
            self?.updateWindowInfo()
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.updateWindowInfo()
        }
    }

    private func removeObservers() {
        if let observer = frameObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = visibilityObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = moveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = resizeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.updateWindowInfo()
        }
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateWindowInfo() {
        guard let window = trackedWindow else { return }

        let frame = window.frame
        windowFrame = frame

        let centerX = frame.origin.x + frame.width / 2
        let centerY = frame.origin.y + frame.height / 2
        windowCenter = CGPoint(x: centerX, y: centerY)

        isWindowVisible = window.isVisible && !window.isMiniaturized

        if let currentScreen = window.screen {
            print("DEBUG: Window is on screen: \(currentScreen.localizedName)")
            print("DEBUG: Screen frame: \(currentScreen.frame)")
            print("DEBUG: Window center (global): \(windowCenter)")
        }
    }

    // MARK: - Utility Methods
    func getWindowCenterInScreenSpace() -> CGPoint {
        guard let window = trackedWindow else { return .zero }

        let frame = window.frame

        let centerX = frame.origin.x + frame.width / 2
        let centerY = frame.origin.y + frame.height / 2

        return CGPoint(x: centerX, y: centerY)
    }

    func convertToFlareCoordinates(_ point: CGPoint) -> CGPoint {
        var minX: CGFloat = CGFloat.greatestFiniteMagnitude
        var minY: CGFloat = CGFloat.greatestFiniteMagnitude
        var maxX: CGFloat = -CGFloat.greatestFiniteMagnitude
        var maxY: CGFloat = -CGFloat.greatestFiniteMagnitude

        for screen in NSScreen.screens {
            let frame = screen.frame
            minX = min(minX, frame.minX)
            minY = min(minY, frame.minY)
            maxX = max(maxX, frame.maxX)
            maxY = max(maxY, frame.maxY)
        }

        let relativeX = point.x - minX
        let relativeY = point.y - minY

        // print("DEBUG: Window at \(point) -> Overlay coords: \(relativeX), \(relativeY)")
        // print("DEBUG: Total bounds: X[\(minX)...\(maxX)] Y[\(minY)...\(maxY)]")

        return CGPoint(x: relativeX, y: relativeY)
    }

    func isPointNearWindow(_ point: CGPoint, threshold: CGFloat = 100) -> Bool {
        let distance = sqrt(pow(point.x - windowCenter.x, 2) + pow(point.y - windowCenter.y, 2))
        return distance <= threshold
    }
}

// MARK: - Window Tracking Coordinator
class WindowTrackingCoordinator {
    private let tracker = WindowTracker.shared
    private var cancellables = Set<AnyCancellable>()

    weak var overlayController: OverlayWindowController?

    init(overlayController: OverlayWindowController? = nil) {
        self.overlayController = overlayController
        setupBindings()
    }

    private func setupBindings() {
        tracker.$windowCenter
            .sink { [weak self] center in
                self?.handleWindowCenterChange(center)
            }
            .store(in: &cancellables)

        tracker.$isWindowVisible
            .sink { [weak self] isVisible in
                self?.handleVisibilityChange(isVisible)
            }
            .store(in: &cancellables)
    }

    private func handleWindowCenterChange(_ center: CGPoint) {
        let flareCenter = tracker.convertToFlareCoordinates(center)

        overlayController?.updateWindowCenter(flareCenter)
    }

    private func handleVisibilityChange(_ isVisible: Bool) {
        if isVisible {
            overlayController?.showOverlay()
        } else {
            overlayController?.hideOverlay()
        }
    }

    func startTracking(window: NSWindow) {
        tracker.trackWindow(window)
    }

    func stopTracking() {
        tracker.stopTracking()
    }
}
