import SceneKit

/// SCNView subclass that tracks mouse movement for hover detection and right-click
class HoverTrackingSCNView: SCNView {
    var onMouseMoved: ((CGPoint) -> Void)?
    var onMouseExited: (() -> Void)?
    /// Right-click callback: (localPoint, screenPoint)
    var onRightMouseDown: ((CGPoint, CGPoint) -> Void)?

    // Drag & Drop callbacks
    /// Called during drag with the agentId under the cursor (nil if none)
    var onDragHoveredAgent: ((UUID?) -> Void)?
    /// Called when a task is dropped on an agent: (agentId, payloadString) -> success
    var onTaskDropped: ((UUID, String) -> Bool)?

    private var trackingArea: NSTrackingArea?
    private var dragRegistered = false

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if !dragRegistered {
            registerForDraggedTypes([.string])
            dragRegistered = true
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        onMouseMoved?(location)
        super.mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
        super.mouseExited(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        // Convert to window coordinates for menu positioning
        let screenPoint = event.locationInWindow
        onRightMouseDown?(localPoint, screenPoint)
        super.rightMouseDown(with: event)
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.canReadObject(forClasses: [NSString.self], options: nil) else {
            return []
        }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let location = convert(sender.draggingLocation, from: nil)

        let hitResults = hitTest(location, options: [
            .searchMode: NSNumber(value: SCNHitTestSearchMode.closest.rawValue),
            .boundingBoxOnly: NSNumber(value: true)
        ])

        var foundAgentId: UUID?
        for hit in hitResults {
            if let characterNode = hit.node.findParentVoxelCharacter(),
               let agentId = characterNode.agentId {
                foundAgentId = agentId
                break
            }
        }

        onDragHoveredAgent?(foundAgentId)
        return foundAgentId != nil ? .copy : .generic
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragHoveredAgent?(nil)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let location = convert(sender.draggingLocation, from: nil)

        guard let items = sender.draggingPasteboard.readObjects(forClasses: [NSString.self], options: nil),
              let payload = items.first as? String,
              payload.hasPrefix("task:") else {
            onDragHoveredAgent?(nil)
            return false
        }

        let hitResults = hitTest(location, options: [
            .searchMode: NSNumber(value: SCNHitTestSearchMode.closest.rawValue),
            .boundingBoxOnly: NSNumber(value: true)
        ])

        for hit in hitResults {
            if let characterNode = hit.node.findParentVoxelCharacter(),
               let agentId = characterNode.agentId {
                let result = onTaskDropped?(agentId, payload) ?? false
                onDragHoveredAgent?(nil)
                return result
            }
        }

        onDragHoveredAgent?(nil)
        return false
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        onDragHoveredAgent?(nil)
    }
}
