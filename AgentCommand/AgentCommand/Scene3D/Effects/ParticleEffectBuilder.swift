import SceneKit

/// Builds one-shot and ambient particle effects as SCNNode hierarchies
struct ParticleEffectBuilder {

    // MARK: - Completion Sparkles

    /// Gold/white sparkle burst that floats upward and fades out (~2s)
    static func buildCompletionSparkles() -> SCNNode {
        let container = SCNNode()
        container.name = "completionSparkles"

        let count = 12
        let colors: [NSColor] = [
            NSColor(hex: "#FFD700"), // gold
            NSColor(hex: "#FFFFFF"), // white
            NSColor(hex: "#4CAF50"), // green
            NSColor(hex: "#00BCD4")  // cyan
        ]

        for i in 0..<count {
            let size: CGFloat = CGFloat.random(in: 0.03...0.05)
            let geo = SCNBox(width: size, height: size, length: size, chamferRadius: size * 0.2)
            let color = colors[i % colors.count]
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.emission.contents = color
            mat.emission.intensity = 0.9
            geo.materials = [mat]

            let node = SCNNode(geometry: geo)
            let angle = Float(i) / Float(count) * Float.pi * 2
            let radius: Float = Float.random(in: 0.2...0.5)
            node.position = SCNVector3(cos(angle) * radius, 0, sin(angle) * radius)

            let duration = Double.random(in: 1.5...2.2)
            let floatUp = SCNAction.moveBy(
                x: CGFloat(Float.random(in: -0.4...0.4)),
                y: CGFloat(Float.random(in: 2.0...3.5)),
                z: CGFloat(Float.random(in: -0.4...0.4)),
                duration: duration
            )
            floatUp.timingMode = .easeOut
            let fadeOut = SCNAction.fadeOut(duration: duration)
            let spin = SCNAction.rotateBy(
                x: CGFloat.random(in: 1...5),
                y: CGFloat.random(in: 1...5),
                z: 0,
                duration: duration
            )
            let waitDelay = SCNAction.wait(duration: Double.random(in: 0...0.2))

            node.runAction(.sequence([
                waitDelay,
                .group([floatUp, fadeOut, spin]),
                .removeFromParentNode()
            ]))

            container.addChildNode(node)
        }

        // Auto-remove container after all particles are done
        container.runAction(.sequence([
            .wait(duration: 3.0),
            .removeFromParentNode()
        ]))

        return container
    }

    // MARK: - Error Smoke

    /// Red/gray smoke puff that expands outward and sinks (~1.5s)
    static func buildErrorSmoke() -> SCNNode {
        let container = SCNNode()
        container.name = "errorSmoke"

        let count = 8
        let colors: [NSColor] = [
            NSColor(hex: "#F44336"), // red
            NSColor(hex: "#616161"), // gray
            NSColor(hex: "#FF5722"), // deep orange
            NSColor(hex: "#424242")  // dark gray
        ]

        for i in 0..<count {
            let radius: CGFloat = CGFloat.random(in: 0.04...0.07)
            let geo = SCNSphere(radius: radius)
            let color = colors[i % colors.count]
            let mat = SCNMaterial()
            mat.diffuse.contents = color.withAlphaComponent(0.8)
            mat.emission.contents = color
            mat.emission.intensity = 0.4
            mat.transparency = 0.8
            geo.materials = [mat]

            let node = SCNNode(geometry: geo)
            let angle = Float(i) / Float(count) * Float.pi * 2
            let startRadius: Float = 0.1
            node.position = SCNVector3(cos(angle) * startRadius, 0, sin(angle) * startRadius)

            let duration = Double.random(in: 1.0...1.6)
            let drift = SCNAction.moveBy(
                x: CGFloat(cos(angle) * Float.random(in: 0.5...1.0)),
                y: CGFloat(Float.random(in: -0.3...0.5)),
                z: CGFloat(sin(angle) * Float.random(in: 0.5...1.0)),
                duration: duration
            )
            drift.timingMode = .easeOut
            let expand = SCNAction.scale(to: CGFloat.random(in: 2.0...3.5), duration: duration)
            expand.timingMode = .easeOut
            let fadeOut = SCNAction.fadeOut(duration: duration)

            let waitDelay = SCNAction.wait(duration: Double.random(in: 0...0.15))
            node.runAction(.sequence([
                waitDelay,
                .group([drift, expand, fadeOut]),
                .removeFromParentNode()
            ]))

            container.addChildNode(node)
        }

        container.runAction(.sequence([
            .wait(duration: 2.5),
            .removeFromParentNode()
        ]))

        return container
    }

    // MARK: - Ambient Particles

    /// Build theme-specific ambient particles
    static func buildAmbientParticles(theme: SceneTheme, dimensions: RoomDimensions) -> [SCNNode] {
        switch theme {
        case .commandCenter:
            return buildDataParticles(dimensions: dimensions)
        case .floatingIslands:
            return buildFireflies(dimensions: dimensions)
        case .dungeon:
            return buildDustMotes(dimensions: dimensions)
        case .spaceStation:
            return buildStarParticles(dimensions: dimensions)
        case .cyberpunkCity:
            return buildNeonRainDrops(dimensions: dimensions)
        case .medievalCastle:
            return buildDustMotes(dimensions: dimensions)
        case .underwaterLab:
            return buildBubbles(dimensions: dimensions)
        case .japaneseGarden:
            return buildCherryBlossomPetals(dimensions: dimensions)
        case .minecraftOverworld:
            return buildFireflies(dimensions: dimensions)
        }
    }

    // MARK: - Theme-specific ambient particles

    private static func buildDataParticles(dimensions: RoomDimensions) -> [SCNNode] {
        let colors: [NSColor] = [
            NSColor(hex: "#00BCD4").withAlphaComponent(0.6), // cyan
            NSColor(hex: "#E040FB").withAlphaComponent(0.4)  // magenta
        ]
        return buildFloatingCubes(
            count: 35,
            colors: colors,
            size: 0.02...0.04,
            dimensions: dimensions,
            speed: 0.8...2.0,
            emissionIntensity: 0.7
        )
    }

    private static func buildFireflies(dimensions: RoomDimensions) -> [SCNNode] {
        var nodes: [SCNNode] = []
        let colors: [NSColor] = [
            NSColor(hex: "#FFEB3B").withAlphaComponent(0.8), // yellow
            NSColor(hex: "#8BC34A").withAlphaComponent(0.7)  // light green
        ]

        for _ in 0..<30 {
            let geo = SCNSphere(radius: CGFloat.random(in: 0.02...0.04))
            let color = colors.randomElement()!
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.emission.contents = color
            mat.emission.intensity = 1.0
            geo.materials = [mat]

            let node = SCNNode(geometry: geo)
            node.position = randomPosition(in: dimensions, yRange: 0.5...4.0)

            // Pulse glow
            let pulseDuration = Double.random(in: 1.5...3.0)
            let fadeDown = SCNAction.fadeOpacity(to: 0.2, duration: pulseDuration)
            fadeDown.timingMode = .easeInEaseOut
            let fadeUp = SCNAction.fadeOpacity(to: 1.0, duration: pulseDuration)
            fadeUp.timingMode = .easeInEaseOut
            node.runAction(.repeatForever(.sequence([fadeDown, fadeUp])))

            // Wander
            let wander = buildWanderAction(dimensions: dimensions, speed: 2.0...5.0)
            node.runAction(.repeatForever(wander))

            nodes.append(node)
        }
        return nodes
    }

    private static func buildDustMotes(dimensions: RoomDimensions) -> [SCNNode] {
        let colors: [NSColor] = [
            NSColor(hex: "#8D6E63").withAlphaComponent(0.3), // brown
            NSColor(hex: "#BDBDBD").withAlphaComponent(0.2)  // light gray
        ]
        return buildFloatingCubes(
            count: 30,
            colors: colors,
            size: 0.01...0.03,
            dimensions: dimensions,
            speed: 3.0...8.0,
            emissionIntensity: 0.1
        )
    }

    private static func buildStarParticles(dimensions: RoomDimensions) -> [SCNNode] {
        var nodes: [SCNNode] = []
        for _ in 0..<40 {
            let geo = SCNSphere(radius: CGFloat.random(in: 0.01...0.025))
            let mat = SCNMaterial()
            let brightness = CGFloat.random(in: 0.7...1.0)
            mat.diffuse.contents = NSColor(white: brightness, alpha: 0.8)
            mat.emission.contents = NSColor(white: brightness, alpha: 1.0)
            mat.emission.intensity = 0.9
            geo.materials = [mat]

            let node = SCNNode(geometry: geo)
            node.position = randomPosition(in: dimensions, yRange: 1.0...4.5)

            // Twinkle
            let twinkleDuration = Double.random(in: 0.8...2.5)
            let dim = SCNAction.fadeOpacity(to: CGFloat.random(in: 0.1...0.3), duration: twinkleDuration)
            dim.timingMode = .easeInEaseOut
            let bright = SCNAction.fadeOpacity(to: 1.0, duration: twinkleDuration)
            bright.timingMode = .easeInEaseOut
            let pause = SCNAction.wait(duration: Double.random(in: 0.5...3.0))
            node.runAction(.repeatForever(.sequence([bright, pause, dim, pause])))

            nodes.append(node)
        }
        return nodes
    }

    // MARK: - Cyberpunk Neon Rain

    private static func buildNeonRainDrops(dimensions: RoomDimensions) -> [SCNNode] {
        var nodes: [SCNNode] = []
        let colors: [NSColor] = [
            NSColor(hex: "#FF2A6D").withAlphaComponent(0.5),
            NSColor(hex: "#05D9E8").withAlphaComponent(0.5),
            NSColor(hex: "#D300C5").withAlphaComponent(0.4)
        ]

        for _ in 0..<30 {
            let geo = SCNBox(width: 0.01, height: CGFloat.random(in: 0.05...0.15), length: 0.01, chamferRadius: 0)
            let color = colors.randomElement()!
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.emission.contents = color
            mat.emission.intensity = 0.8
            geo.materials = [mat]

            let node = SCNNode(geometry: geo)
            node.position = randomPosition(in: dimensions, yRange: 2.0...5.0)

            // Fall and reset
            let fallDuration = Double.random(in: 0.8...2.0)
            let fall = SCNAction.moveBy(x: 0, y: CGFloat(-Float.random(in: 3...6)), z: 0, duration: fallDuration)
            fall.timingMode = .linear
            let reset = SCNAction.run { n in
                n.position = Self.randomPosition(in: dimensions, yRange: 4.0...6.0)
                n.opacity = 1.0
            }
            let fadeOut = SCNAction.fadeOut(duration: fallDuration * 0.3)
            node.runAction(.repeatForever(.sequence([
                .group([fall, .sequence([.wait(duration: fallDuration * 0.7), fadeOut])]),
                reset
            ])))

            nodes.append(node)
        }
        return nodes
    }

    // MARK: - Underwater Bubbles

    private static func buildBubbles(dimensions: RoomDimensions) -> [SCNNode] {
        var nodes: [SCNNode] = []
        let color = NSColor(hex: "#00E5FF").withAlphaComponent(0.3)

        for _ in 0..<25 {
            let radius = CGFloat.random(in: 0.02...0.06)
            let geo = SCNSphere(radius: radius)
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.emission.contents = NSColor(hex: "#00E5FF")
            mat.emission.intensity = 0.3
            mat.transparency = 0.5
            mat.fresnelExponent = 2.0
            geo.materials = [mat]

            let node = SCNNode(geometry: geo)
            node.position = randomPosition(in: dimensions, yRange: 0.2...1.0)

            // Rise and reset
            let riseDuration = Double.random(in: 3.0...7.0)
            let rise = SCNAction.moveBy(
                x: CGFloat(Float.random(in: -0.5...0.5)),
                y: CGFloat(Float.random(in: 3...6)),
                z: CGFloat(Float.random(in: -0.5...0.5)),
                duration: riseDuration
            )
            rise.timingMode = .easeOut
            let fadeOut = SCNAction.fadeOut(duration: riseDuration * 0.2)
            let reset = SCNAction.run { n in
                n.position = Self.randomPosition(in: dimensions, yRange: 0.1...0.5)
                n.opacity = CGFloat.random(in: 0.3...0.7)
            }

            // Wobble
            let wobble = SCNAction.repeatForever(.sequence([
                .moveBy(x: CGFloat(Float.random(in: -0.1...0.1)), y: 0, z: 0, duration: 0.5),
                .moveBy(x: CGFloat(Float.random(in: -0.1...0.1)), y: 0, z: 0, duration: 0.5)
            ]))
            node.runAction(wobble)

            node.runAction(.repeatForever(.sequence([
                .group([rise, .sequence([.wait(duration: riseDuration * 0.8), fadeOut])]),
                reset
            ])))

            nodes.append(node)
        }
        return nodes
    }

    // MARK: - Cherry Blossom Petals

    private static func buildCherryBlossomPetals(dimensions: RoomDimensions) -> [SCNNode] {
        var nodes: [SCNNode] = []
        let colors: [NSColor] = [
            NSColor(hex: "#FFB7C5").withAlphaComponent(0.8),
            NSColor(hex: "#FFC1CC").withAlphaComponent(0.7),
            NSColor(hex: "#FFFFFF").withAlphaComponent(0.6)
        ]

        for _ in 0..<35 {
            let size = CGFloat.random(in: 0.03...0.06)
            let geo = SCNPlane(width: size, height: size)
            let color = colors.randomElement()!
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.emission.contents = color
            mat.emission.intensity = 0.15
            mat.isDoubleSided = true
            geo.materials = [mat]

            let node = SCNNode(geometry: geo)
            node.position = randomPosition(in: dimensions, yRange: 2.0...5.0)
            node.opacity = CGFloat.random(in: 0.5...1.0)

            // Gentle falling with swaying
            let fallDuration = Double.random(in: 5.0...10.0)
            let fall = SCNAction.moveBy(
                x: CGFloat(Float.random(in: -2...2)),
                y: CGFloat(-Float.random(in: 3...6)),
                z: CGFloat(Float.random(in: -1...1)),
                duration: fallDuration
            )
            fall.timingMode = .easeInEaseOut

            // Spin/flutter
            let spin = SCNAction.rotateBy(
                x: CGFloat.random(in: 1...4),
                y: CGFloat.random(in: 1...4),
                z: CGFloat.random(in: 1...4),
                duration: fallDuration
            )

            let reset = SCNAction.run { n in
                n.position = Self.randomPosition(in: dimensions, yRange: 4.0...6.0)
                n.opacity = CGFloat.random(in: 0.5...1.0)
            }
            let fadeOut = SCNAction.fadeOut(duration: fallDuration * 0.15)

            node.runAction(.repeatForever(.sequence([
                .group([fall, spin, .sequence([.wait(duration: fallDuration * 0.85), fadeOut])]),
                reset
            ])))

            nodes.append(node)
        }
        return nodes
    }

    // MARK: - Code Rain (Matrix-style)

    /// Green code-rain effect that streams downward around an agent during intensive coding
    static func buildCodeRain() -> SCNNode {
        let container = SCNNode()
        container.name = "codeRain"

        let chars = "01アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン"
        let charArray = Array(chars)
        let columnCount = 8
        let green = NSColor(hex: "#00FF41")

        for col in 0..<columnCount {
            let angle = Float(col) / Float(columnCount) * Float.pi * 2
            let radius: Float = 0.5
            let colX = cos(angle) * radius
            let colZ = sin(angle) * radius

            // Spawn falling characters in this column
            let spawnAction = SCNAction.run { node in
                let char = charArray.randomElement()!
                let text = SCNText(string: String(char), extrusionDepth: 0.005)
                text.font = NSFont(name: "Menlo", size: 0.12) ?? NSFont.monospacedSystemFont(ofSize: 0.12, weight: .regular)
                text.flatness = 0.3
                let mat = SCNMaterial()
                let brightness = CGFloat.random(in: 0.5...1.0)
                mat.diffuse.contents = green.withAlphaComponent(brightness)
                mat.emission.contents = green
                mat.emission.intensity = brightness
                text.materials = [mat]

                let charNode = SCNNode(geometry: text)
                charNode.position = SCNVector3(colX + Float.random(in: -0.05...0.05), Float.random(in: 1.5...2.5), colZ)
                charNode.scale = SCNVector3(0.6, 0.6, 0.6)

                // Billboard constraint so text faces camera
                let billboard = SCNBillboardConstraint()
                billboard.freeAxes = .Y
                charNode.constraints = [billboard]

                let fallDuration = Double.random(in: 1.0...2.0)
                let fall = SCNAction.moveBy(x: 0, y: CGFloat(-Float.random(in: 2.5...4.0)), z: 0, duration: fallDuration)
                fall.timingMode = .linear
                let fade = SCNAction.fadeOut(duration: fallDuration * 0.8)

                charNode.runAction(.sequence([
                    .wait(duration: Double.random(in: 0...0.3)),
                    .group([fall, .sequence([.wait(duration: fallDuration * 0.3), fade])]),
                    .removeFromParentNode()
                ]))

                node.addChildNode(charNode)
            }

            let columnNode = SCNNode()
            columnNode.runAction(.repeatForever(.sequence([
                spawnAction,
                .wait(duration: Double.random(in: 0.15...0.35))
            ])), forKey: "codeRainCol_\(col)")
            container.addChildNode(columnNode)
        }

        return container
    }

    // MARK: - Lightning / Energy Effect

    /// Crackling lightning/energy effect around a high-speed working agent
    static func buildLightningEffect() -> SCNNode {
        let container = SCNNode()
        container.name = "lightningEffect"

        let colors: [NSColor] = [
            NSColor(hex: "#00E5FF"), // electric blue
            NSColor(hex: "#FFFFFF"), // white
            NSColor(hex: "#B388FF")  // purple
        ]

        // Continuously spawn lightning bolts
        let spawnBolt = SCNAction.run { node in
            Self.spawnLightningBolt(on: node, colors: colors)
        }

        // Spawn energy orbs that orbit
        let orbCount = 4
        for i in 0..<orbCount {
            let orb = SCNSphere(radius: 0.025)
            let color = colors[i % colors.count]
            let mat = SCNMaterial()
            mat.diffuse.contents = color.withAlphaComponent(0.8)
            mat.emission.contents = color
            mat.emission.intensity = 1.2
            orb.materials = [mat]

            let orbNode = SCNNode(geometry: orb)
            let startAngle = Float(i) / Float(orbCount) * Float.pi * 2
            orbNode.position = SCNVector3(cos(startAngle) * 0.5, Float.random(in: -0.2...0.5), sin(startAngle) * 0.5)

            // Orbit around
            let orbit = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: Double.random(in: 1.0...2.0))
            // Pulse
            let pulseUp = SCNAction.fadeOpacity(to: 1.0, duration: 0.3)
            let pulseDown = SCNAction.fadeOpacity(to: 0.3, duration: 0.3)

            let orbitContainer = SCNNode()
            orbitContainer.addChildNode(orbNode)
            orbitContainer.runAction(.repeatForever(orbit))
            orbNode.runAction(.repeatForever(.sequence([pulseUp, pulseDown])))

            container.addChildNode(orbitContainer)
        }

        container.runAction(.repeatForever(.sequence([
            spawnBolt,
            .wait(duration: Double.random(in: 0.3...0.8))
        ])), forKey: "lightningSpawn")

        return container
    }

    // MARK: - Level Up Effect

    /// Golden spiral effect when an agent levels up
    static func buildLevelUpEffect() -> SCNNode {
        let container = SCNNode()
        container.name = "levelUpEffect"

        let count = 20
        let gold = NSColor(hex: "#FFD700")
        let white = NSColor(hex: "#FFFFFF")

        for i in 0..<count {
            let size: CGFloat = CGFloat.random(in: 0.03...0.06)
            let geo = SCNBox(width: size, height: size, length: size, chamferRadius: size * 0.3)
            let color = i % 3 == 0 ? white : gold
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.emission.contents = color
            mat.emission.intensity = 1.0
            geo.materials = [mat]

            let node = SCNNode(geometry: geo)

            // Start in a spiral pattern
            let t = Float(i) / Float(count)
            let angle = t * Float.pi * 4
            let radius = t * 0.8
            node.position = SCNVector3(cos(angle) * radius, -0.5, sin(angle) * radius)

            let duration = Double.random(in: 1.5...2.5)
            let spiralUp = SCNAction.moveBy(x: 0, y: CGFloat(Float.random(in: 3.0...5.0)), z: 0, duration: duration)
            spiralUp.timingMode = .easeOut
            let fadeOut = SCNAction.fadeOut(duration: duration * 0.7)
            let spin = SCNAction.rotateBy(x: CGFloat.random(in: 2...6), y: CGFloat.random(in: 2...6), z: 0, duration: duration)

            node.runAction(.sequence([
                .wait(duration: Double(t) * 0.1),
                .group([spiralUp, .sequence([.wait(duration: duration * 0.3), fadeOut]), spin]),
                .removeFromParentNode()
            ]))

            container.addChildNode(node)
        }

        container.runAction(.sequence([
            .wait(duration: 4.0),
            .removeFromParentNode()
        ]))

        return container
    }

    // MARK: - Streak Break Effect

    /// Fiery shatter effect when a streak is broken — flame particles explode outward and sink
    static func buildStreakBreakEffect(lostStreak: Int) -> SCNNode {
        let container = SCNNode()
        container.name = "streakBreakEffect"

        // More particles for bigger lost streaks
        let count = min(8 + lostStreak * 2, 24)
        let colors: [NSColor] = [
            NSColor(hex: "#FF6D00"), // deep orange
            NSColor(hex: "#F44336"), // red
            NSColor(hex: "#FFD600"), // amber
            NSColor(hex: "#FF3D00"), // red-orange
            NSColor(hex: "#BF360C")  // dark red
        ]

        for i in 0..<count {
            let size: CGFloat = CGFloat.random(in: 0.03...0.06)
            let geo = SCNBox(width: size, height: size, length: size, chamferRadius: size * 0.1)
            let color = colors[i % colors.count]
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.emission.contents = color
            mat.emission.intensity = 1.0
            geo.materials = [mat]

            let node = SCNNode(geometry: geo)
            let angle = Float(i) / Float(count) * Float.pi * 2
            let radius: Float = 0.15
            node.position = SCNVector3(cos(angle) * radius, 1.2, sin(angle) * radius)

            let duration = Double.random(in: 1.2...2.0)
            // Explode outward and fall down
            let explode = SCNAction.moveBy(
                x: CGFloat(cos(angle) * Float.random(in: 0.8...1.5)),
                y: CGFloat(Float.random(in: 0.5...1.5)),
                z: CGFloat(sin(angle) * Float.random(in: 0.8...1.5)),
                duration: duration * 0.4
            )
            explode.timingMode = .easeOut
            let fall = SCNAction.moveBy(
                x: CGFloat(Float.random(in: -0.3...0.3)),
                y: CGFloat(-Float.random(in: 1.5...3.0)),
                z: CGFloat(Float.random(in: -0.3...0.3)),
                duration: duration * 0.6
            )
            fall.timingMode = .easeIn
            let fadeOut = SCNAction.fadeOut(duration: duration * 0.8)
            let spin = SCNAction.rotateBy(
                x: CGFloat.random(in: 2...8),
                y: CGFloat.random(in: 2...8),
                z: CGFloat.random(in: -2...2),
                duration: duration
            )
            let shrink = SCNAction.scale(to: 0.1, duration: duration)
            shrink.timingMode = .easeIn

            node.runAction(.sequence([
                .wait(duration: Double.random(in: 0...0.1)),
                .group([.sequence([explode, fall]), fadeOut, spin, shrink]),
                .removeFromParentNode()
            ]))

            container.addChildNode(node)
        }

        // Brief red flash sphere
        let flashGeo = SCNSphere(radius: 0.6)
        let flashMat = SCNMaterial()
        flashMat.diffuse.contents = NSColor(hex: "#FF1744").withAlphaComponent(0.4)
        flashMat.emission.contents = NSColor(hex: "#FF1744")
        flashMat.emission.intensity = 1.5
        flashMat.transparency = 0.0
        flashGeo.materials = [flashMat]
        let flashNode = SCNNode(geometry: flashGeo)
        flashNode.position = SCNVector3(0, 1.2, 0)
        flashNode.runAction(.sequence([
            .fadeIn(duration: 0.05),
            .wait(duration: 0.1),
            .group([
                .fadeOut(duration: 0.3),
                .scale(to: 2.0, duration: 0.3)
            ]),
            .removeFromParentNode()
        ]))
        container.addChildNode(flashNode)

        container.runAction(.sequence([
            .wait(duration: 3.0),
            .removeFromParentNode()
        ]))

        return container
    }

    // MARK: - Helpers

    private static func buildFloatingCubes(
        count: Int,
        colors: [NSColor],
        size: ClosedRange<CGFloat>,
        dimensions: RoomDimensions,
        speed: ClosedRange<Double>,
        emissionIntensity: CGFloat
    ) -> [SCNNode] {
        var nodes: [SCNNode] = []
        for _ in 0..<count {
            let s = CGFloat.random(in: size)
            let geo = SCNBox(width: s, height: s, length: s, chamferRadius: s * 0.2)
            let color = colors.randomElement()!
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.emission.contents = color
            mat.emission.intensity = emissionIntensity
            geo.materials = [mat]

            let node = SCNNode(geometry: geo)
            node.position = randomPosition(in: dimensions, yRange: 0.3...4.0)
            node.opacity = CGFloat.random(in: 0.3...0.8)

            // Slow drift
            let wander = buildWanderAction(dimensions: dimensions, speed: speed)
            node.runAction(.repeatForever(wander))

            // Slow spin
            let spinDuration = Double.random(in: 4.0...10.0)
            let spin = SCNAction.rotateBy(x: CGFloat.random(in: -1...1), y: CGFloat.random(in: -1...1), z: 0, duration: spinDuration)
            node.runAction(.repeatForever(spin))

            nodes.append(node)
        }
        return nodes
    }

    private static func spawnLightningBolt(on node: SCNNode, colors: [NSColor]) {
        let boltNode = SCNNode()
        let segmentCount = Int.random(in: 3...6)
        var cx: CGFloat = CGFloat.random(in: -0.4...0.4)
        var cy: CGFloat = CGFloat.random(in: -0.3...0.8)
        var cz: CGFloat = CGFloat.random(in: -0.4...0.4)

        let color = colors.randomElement()!
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.emission.contents = color
        mat.emission.intensity = 1.5

        for _ in 0..<segmentCount {
            let nx = cx + CGFloat.random(in: -0.3...0.3)
            let ny = cy + CGFloat.random(in: -0.3...0.3)
            let nz = cz + CGFloat.random(in: -0.3...0.3)

            let mx = (cx + nx) / 2
            let my = (cy + ny) / 2
            let mz = (cz + nz) / 2

            let dx = nx - cx
            let dy = ny - cy
            let dz = nz - cz
            let length = sqrt(dx * dx + dy * dy + dz * dz)

            let segment = SCNBox(width: 0.015, height: 0.015, length: length, chamferRadius: 0)
            segment.materials = [mat]
            let segNode = SCNNode(geometry: segment)
            segNode.position = SCNVector3(mx, my, mz)
            segNode.look(at: SCNVector3(nx, ny, nz))
            boltNode.addChildNode(segNode)

            let glow = SCNSphere(radius: 0.03)
            glow.materials = [mat]
            let glowNode = SCNNode(geometry: glow)
            glowNode.position = SCNVector3(cx, cy, cz)
            boltNode.addChildNode(glowNode)

            cx = nx; cy = ny; cz = nz
        }

        let flashDuration = Double.random(in: 0.08...0.2)
        boltNode.runAction(.sequence([
            .fadeIn(duration: 0.02),
            .wait(duration: flashDuration),
            .fadeOut(duration: 0.1),
            .removeFromParentNode()
        ]))
        node.addChildNode(boltNode)
    }

    private static func randomPosition(in dimensions: RoomDimensions, yRange: ClosedRange<Float>) -> SCNVector3 {
        let halfW = dimensions.width / 2.0 - 1.0
        let depth = dimensions.depth - 2.0
        return SCNVector3(
            Float.random(in: -halfW...halfW),
            Float.random(in: yRange),
            Float.random(in: -1.0...depth)
        )
    }

    private static func buildWanderAction(dimensions: RoomDimensions, speed: ClosedRange<Double>) -> SCNAction {
        let duration = Double.random(in: speed)
        let halfW = dimensions.width / 2.0 - 1.0
        let depth = dimensions.depth - 2.0
        let dx = CGFloat(Float.random(in: -2.0...2.0))
        let dy = CGFloat(Float.random(in: -0.5...0.5))
        let dz = CGFloat(Float.random(in: -2.0...2.0))
        let move = SCNAction.moveBy(x: dx, y: dy, z: dz, duration: duration)
        move.timingMode = .easeInEaseOut

        // Clamp back toward center if too far
        let clamp = SCNAction.run { [halfW, depth] node in
            var pos = node.position
            let hw = CGFloat(halfW)
            let d = CGFloat(depth)
            pos.x = max(-hw, min(hw, pos.x))
            pos.y = max(0.3, min(4.5, pos.y))
            pos.z = max(-1.0, min(d, pos.z))
            node.position = pos
        }

        return .sequence([move, clamp])
    }
}
