//
//  NebulaWindow.swift
//  Nebula
//
//  Created by Gonzalo Cruz Cortes on 10/21/25.
//

import AppKit
import SwiftUI

class NebulaWindow: NSWindow {
    private var isResizing = false
    private var resizeEdge: ResizeEdge = .none
    private var initialMouseLocation: NSPoint = .zero
    private var initialFrame: NSRect = .zero

    enum ResizeEdge {
        case none, top, bottom, left, right, topLeft, topRight, bottomLeft, bottomRight
    }

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .resizable, .miniaturizable, .fullSizeContentView],
            backing: backingStoreType,
            defer: flag
        )
        setupWindow()
    }

    private func setupWindow() {
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
    }

    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }

    override func mouseMoved(with event: NSEvent) {
        if !isResizing {
            updateCursor(for: event)
        }
        super.mouseMoved(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        let location = event.locationInWindow
        resizeEdge = detectResizeEdge(at: location)

        if resizeEdge != .none {
            isResizing = true
            initialMouseLocation = NSEvent.mouseLocation
            initialFrame = frame
        } else {
            super.mouseDown(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if isResizing {
            performResize(with: event)
        } else {
            super.mouseDragged(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        isResizing = false
        resizeEdge = .none
        super.mouseUp(with: event)
    }

    private func detectResizeEdge(at point: NSPoint) -> ResizeEdge {
        let threshold: CGFloat = 8.0
        let frame = contentView?.bounds ?? .zero
        let cornerRadius: CGFloat = 40.0

        if !isPointInRoundedRect(point, rect: frame, radius: cornerRadius) {
            return .none
        }

        let nearLeft = point.x < threshold
        let nearRight = point.x > frame.width - threshold
        let nearTop = point.y > frame.height - threshold
        let nearBottom = point.y < threshold

        if nearTop && nearLeft {
            let cornerCenter = NSPoint(x: cornerRadius, y: frame.height - cornerRadius)
            let distToCorner = sqrt(pow(point.x - cornerCenter.x, 2) + pow(point.y - cornerCenter.y, 2))
            if distToCorner <= cornerRadius + threshold && distToCorner >= cornerRadius - threshold {
                return .topLeft
            }
        }
        if nearTop && nearRight {
            let cornerCenter = NSPoint(x: frame.width - cornerRadius, y: frame.height - cornerRadius)
            let distToCorner = sqrt(pow(point.x - cornerCenter.x, 2) + pow(point.y - cornerCenter.y, 2))
            if distToCorner <= cornerRadius + threshold && distToCorner >= cornerRadius - threshold {
                return .topRight
            }
        }
        if nearBottom && nearLeft {
            let cornerCenter = NSPoint(x: cornerRadius, y: cornerRadius)
            let distToCorner = sqrt(pow(point.x - cornerCenter.x, 2) + pow(point.y - cornerCenter.y, 2))
            if distToCorner <= cornerRadius + threshold && distToCorner >= cornerRadius - threshold {
                return .bottomLeft
            }
        }
        if nearBottom && nearRight {
            let cornerCenter = NSPoint(x: frame.width - cornerRadius, y: cornerRadius)
            let distToCorner = sqrt(pow(point.x - cornerCenter.x, 2) + pow(point.y - cornerCenter.y, 2))
            if distToCorner <= cornerRadius + threshold && distToCorner >= cornerRadius - threshold {
                return .bottomRight
            }
        }

        if nearTop && point.x > cornerRadius && point.x < frame.width - cornerRadius { return .top }
        if nearBottom && point.x > cornerRadius && point.x < frame.width - cornerRadius { return .bottom }
        if nearLeft && point.y > cornerRadius && point.y < frame.height - cornerRadius { return .left }
        if nearRight && point.y > cornerRadius && point.y < frame.height - cornerRadius { return .right }

        return .none
    }

    private func isPointInRoundedRect(_ point: NSPoint, rect: NSRect, radius: CGFloat) -> Bool {
        if !rect.contains(point) {
            return false
        }

        let cornerRadius = radius

        if point.x < cornerRadius && point.y > rect.height - cornerRadius {
            let cornerCenter = NSPoint(x: cornerRadius, y: rect.height - cornerRadius)
            let distance = sqrt(pow(point.x - cornerCenter.x, 2) + pow(point.y - cornerCenter.y, 2))
            if distance > cornerRadius {
                return false
            }
        }

        if point.x > rect.width - cornerRadius && point.y > rect.height - cornerRadius {
            let cornerCenter = NSPoint(x: rect.width - cornerRadius, y: rect.height - cornerRadius)
            let distance = sqrt(pow(point.x - cornerCenter.x, 2) + pow(point.y - cornerCenter.y, 2))
            if distance > cornerRadius {
                return false
            }
        }

        if point.x < cornerRadius && point.y < cornerRadius {
            let cornerCenter = NSPoint(x: cornerRadius, y: cornerRadius)
            let distance = sqrt(pow(point.x - cornerCenter.x, 2) + pow(point.y - cornerCenter.y, 2))
            if distance > cornerRadius {
                return false
            }
        }

        if point.x > rect.width - cornerRadius && point.y < cornerRadius {
            let cornerCenter = NSPoint(x: rect.width - cornerRadius, y: cornerRadius)
            let distance = sqrt(pow(point.x - cornerCenter.x, 2) + pow(point.y - cornerCenter.y, 2))
            if distance > cornerRadius {
                return false
            }
        }

        return true
    }

    private func updateCursor(for event: NSEvent) {
        let location = event.locationInWindow
        let edge = detectResizeEdge(at: location)

        switch edge {
        case .top, .bottom:
            NSCursor.resizeUpDown.set()
        case .left, .right:
            NSCursor.resizeLeftRight.set()
        case .topLeft, .bottomRight:
            NSCursor(image: NSImage(systemSymbolName: "arrow.up.left.and.down.right", accessibilityDescription: nil)!, hotSpot: NSPoint(x: 8, y: 8)).set()
        case .topRight, .bottomLeft:
            NSCursor(image: NSImage(systemSymbolName: "arrow.up.right.and.down.left", accessibilityDescription: nil)!, hotSpot: NSPoint(x: 8, y: 8)).set()
        case .none:
            NSCursor.arrow.set()
        }
    }

    private func performResize(with event: NSEvent) {
        let currentMouseLocation = NSEvent.mouseLocation
        let deltaX = currentMouseLocation.x - initialMouseLocation.x
        let deltaY = currentMouseLocation.y - initialMouseLocation.y

        var newFrame = initialFrame

        switch resizeEdge {
        case .right:
            newFrame.size.width += deltaX
        case .left:
            newFrame.origin.x += deltaX
            newFrame.size.width -= deltaX
        case .top:
            newFrame.size.height += deltaY
        case .bottom:
            newFrame.origin.y += deltaY
            newFrame.size.height -= deltaY
        case .topRight:
            newFrame.size.width += deltaX
            newFrame.size.height += deltaY
        case .topLeft:
            newFrame.origin.x += deltaX
            newFrame.size.width -= deltaX
            newFrame.size.height += deltaY
        case .bottomRight:
            newFrame.size.width += deltaX
            newFrame.origin.y += deltaY
            newFrame.size.height -= deltaY
        case .bottomLeft:
            newFrame.origin.x += deltaX
            newFrame.size.width -= deltaX
            newFrame.origin.y += deltaY
            newFrame.size.height -= deltaY
        default:
            break
        }

        newFrame.size.width = max(minSize.width, newFrame.size.width)
        newFrame.size.height = max(minSize.height, newFrame.size.height)

        setFrame(newFrame, display: true)
    }
}

class NebulaContentView: NSView {
    var cornerRadius: CGFloat = 40.0
    private var hostingView: NSHostingView<NebulaWindowContent>?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.black.cgColor

        let windowContent = NebulaWindowContent()
        let hosting = NSHostingView(rootView: windowContent)
        hosting.frame = bounds
        hosting.autoresizingMask = [.width, .height]

        addSubview(hosting)
        hostingView = hosting
    }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)

        let edgeThreshold: CGFloat = 10.0
        let innerRect = NSRect(
            x: bounds.minX + edgeThreshold,
            y: bounds.minY + edgeThreshold,
            width: bounds.width - (edgeThreshold * 2),
            height: bounds.height - (edgeThreshold * 2)
        )

        if !innerRect.contains(point) {
            return self
        }

        return hit
    }
}

struct NebulaWindowContent: View {
    @State private var isHoveringTrafficLights = false

    var body: some View {
        ZStack {
            Color.black

            SplashScreen()

            VStack {
                HStack {
                    HStack(spacing: 8) {
                        TrafficLightButton(type: .close, isHovering: isHoveringTrafficLights)
                        TrafficLightButton(type: .minimize, isHovering: isHoveringTrafficLights)
                        TrafficLightButton(type: .maximize, isHovering: isHoveringTrafficLights)
                    }
                    .padding(.leading, 20)
                    .padding(.top, 20)
                    .onHover { hovering in
                        isHoveringTrafficLights = hovering
                    }

                    Spacer()
                }
                Spacer()
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 40)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .allowsHitTesting(false)
        )
    }
}

struct TrafficLightButton: View {
    enum ButtonType {
        case close, minimize, maximize

        var color: Color {
            switch self {
            case .close: return Color(NSColor.systemRed)
            case .minimize: return Color(NSColor.systemYellow)
            case .maximize: return Color(NSColor.systemGreen)
            }
        }

        // NOTE: maximize is not functional
        var symbol: String {
            switch self {
            case .close: return "×"
            case .minimize: return "−"
            case .maximize: return "↗"
            }
        }
    }

    let type: ButtonType
    let isHovering: Bool
    @State private var isPressed = false

    var body: some View {
        Button(action: performAction) {
            ZStack {
                Circle()
                    .fill(type.color)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                    )
                    .scaleEffect(isPressed ? 0.9 : 1.0)

                if isHovering {
                    Text(type.symbol)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(Color.black.opacity(0.6))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: {}
        )
    }

    private func performAction() {
        guard let window = NSApp.mainWindow else { return }

        switch type {
        case .close:
            window.close()
        case .minimize:
            window.miniaturize(nil)
        case .maximize:
            window.zoom(nil)
        }
    }
}
