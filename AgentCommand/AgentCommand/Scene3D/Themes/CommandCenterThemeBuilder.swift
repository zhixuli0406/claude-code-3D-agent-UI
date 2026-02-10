import SceneKit

struct CommandCenterThemeBuilder: SceneThemeBuilder {
    let theme: SceneTheme = .commandCenter
    let palette: ThemeColorPalette = .commandCenter

    func buildEnvironment(dimensions: RoomDimensions) -> SCNNode {
        RoomBuilder.build(dimensions: dimensions, palette: palette)
    }

    func buildWorkstation(size: DeskSize) -> SCNNode {
        DeskBuilder.build(size: size, palette: palette)
    }

    func buildSeating() -> SCNNode {
        DeskBuilder.buildChair(palette: palette)
    }

    func buildDisplay(width: CGFloat, height: CGFloat) -> SCNNode {
        MonitorBuilder.build(width: width, height: height, palette: palette)
    }

    func applyLighting(to scene: SCNScene, intensity: Float) {
        LightingSetup.apply(to: scene, intensity: intensity, palette: palette)
    }
}
