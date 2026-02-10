import SceneKit

protocol SceneThemeBuilder {
    var theme: SceneTheme { get }
    var palette: ThemeColorPalette { get }

    func buildEnvironment(dimensions: RoomDimensions) -> SCNNode
    func buildWorkstation(size: DeskSize) -> SCNNode
    func buildSeating() -> SCNNode
    func buildDisplay(width: CGFloat, height: CGFloat) -> SCNNode
    func applyLighting(to scene: SCNScene, intensity: Float)
    func buildDecorations(dimensions: RoomDimensions) -> SCNNode?

    var sceneBackgroundColor: NSColor { get }
    var connectionLineColor: NSColor { get }
    func cameraConfigOverride() -> CameraConfig?
}

extension SceneThemeBuilder {
    func buildDecorations(dimensions: RoomDimensions) -> SCNNode? { nil }
    func cameraConfigOverride() -> CameraConfig? { nil }
    var sceneBackgroundColor: NSColor { palette.backgroundNSColor }
    var connectionLineColor: NSColor { NSColor(hex: palette.connectionLineColor) }
}
