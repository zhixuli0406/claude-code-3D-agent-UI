import SceneKit

/// Builds 3D cosmetic hat nodes for the VoxelCharacterNode
enum CosmeticHatBuilder {

    static func buildHat(_ style: CosmeticHatStyle) -> SCNNode {
        switch style {
        case .topHat:
            return buildTopHat()
        case .wizardHat:
            return buildWizardHat()
        case .santaHat:
            return buildSantaHat()
        case .bunnyEars:
            return buildBunnyEars()
        case .pirateHat:
            return buildPirateHat()
        case .halo:
            return buildHalo()
        case .devilHorns:
            return buildDevilHorns()
        case .samuraiHelmet:
            return buildSamuraiHelmet()
        case .partyHat:
            return buildPartyHat()
        case .pumpkinHead:
            return buildPumpkinHead()
        }
    }

    // MARK: - Top Hat

    private static func buildTopHat() -> SCNNode {
        let node = SCNNode()
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(hex: "#212121")
        material.metalness.contents = 0.3

        // Brim
        let brim = SCNCylinder(radius: 0.28, height: 0.02)
        brim.materials = [material]
        let brimNode = SCNNode(geometry: brim)
        brimNode.position = SCNVector3(0, 0.2, 0)
        node.addChildNode(brimNode)

        // Crown (tall cylinder)
        let crown = SCNCylinder(radius: 0.18, height: 0.3)
        crown.materials = [material]
        let crownNode = SCNNode(geometry: crown)
        crownNode.position = SCNVector3(0, 0.36, 0)
        node.addChildNode(crownNode)

        // Band
        let bandMaterial = SCNMaterial()
        bandMaterial.diffuse.contents = NSColor(hex: "#D32F2F")
        let band = SCNCylinder(radius: 0.19, height: 0.03)
        band.materials = [bandMaterial]
        let bandNode = SCNNode(geometry: band)
        bandNode.position = SCNVector3(0, 0.24, 0)
        node.addChildNode(bandNode)

        return node
    }

    // MARK: - Wizard Hat

    private static func buildWizardHat() -> SCNNode {
        let node = SCNNode()
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(hex: "#1A237E")
        material.emission.contents = NSColor(hex: "#283593")
        material.emission.intensity = 0.2

        // Brim
        let brim = SCNCylinder(radius: 0.3, height: 0.02)
        brim.materials = [material]
        let brimNode = SCNNode(geometry: brim)
        brimNode.position = SCNVector3(0, 0.2, 0)
        node.addChildNode(brimNode)

        // Cone
        let cone = SCNCone(topRadius: 0.02, bottomRadius: 0.18, height: 0.45)
        cone.materials = [material]
        let coneNode = SCNNode(geometry: cone)
        coneNode.position = SCNVector3(0, 0.44, 0)
        node.addChildNode(coneNode)

        // Star decoration
        let starMaterial = SCNMaterial()
        starMaterial.diffuse.contents = NSColor(hex: "#FFD700")
        starMaterial.emission.contents = NSColor(hex: "#FFD700")
        starMaterial.emission.intensity = 0.8
        let star = SCNSphere(radius: 0.04)
        star.materials = [starMaterial]
        let starNode = SCNNode(geometry: star)
        starNode.position = SCNVector3(0, 0.68, 0)
        node.addChildNode(starNode)

        // Subtle sparkle particles
        let sparkle = SCNSphere(radius: 0.015)
        let sparkleMaterial = SCNMaterial()
        sparkleMaterial.diffuse.contents = NSColor(hex: "#FFD700").withAlphaComponent(0.6)
        sparkleMaterial.emission.contents = NSColor(hex: "#FFD700")
        sparkleMaterial.emission.intensity = 1.0
        sparkleMaterial.blendMode = .add
        sparkle.materials = [sparkleMaterial]

        for i in 0..<3 {
            let sparkleNode = SCNNode(geometry: sparkle)
            let angle = Float(i) * Float.pi * 2.0 / 3.0
            sparkleNode.position = SCNVector3(cos(angle) * 0.12, 0.35 + Float(i) * 0.1, sin(angle) * 0.12)
            let orbit = SCNAction.customAction(duration: 2.0) { n, elapsed in
                let t = Float(elapsed) / 2.0
                let a = angle + t * Float.pi * 2
                n.position = SCNVector3(cos(a) * 0.12, 0.35 + Float(i) * 0.1, sin(a) * 0.12)
            }
            sparkleNode.runAction(.repeatForever(orbit))
            node.addChildNode(sparkleNode)
        }

        return node
    }

    // MARK: - Santa Hat

    private static func buildSantaHat() -> SCNNode {
        let node = SCNNode()
        let redMaterial = SCNMaterial()
        redMaterial.diffuse.contents = NSColor(hex: "#C62828")

        let whiteMaterial = SCNMaterial()
        whiteMaterial.diffuse.contents = NSColor(hex: "#FAFAFA")

        // Brim (white fur band)
        let brim = SCNCylinder(radius: 0.26, height: 0.06)
        brim.materials = [whiteMaterial]
        let brimNode = SCNNode(geometry: brim)
        brimNode.position = SCNVector3(0, 0.22, 0)
        node.addChildNode(brimNode)

        // Red cone (slightly bent)
        let cone = SCNCone(topRadius: 0.02, bottomRadius: 0.2, height: 0.35)
        cone.materials = [redMaterial]
        let coneNode = SCNNode(geometry: cone)
        coneNode.position = SCNVector3(0, 0.42, 0)
        coneNode.eulerAngles.z = 0.2
        node.addChildNode(coneNode)

        // White pompom
        let pompom = SCNSphere(radius: 0.05)
        pompom.materials = [whiteMaterial]
        let pompomNode = SCNNode(geometry: pompom)
        pompomNode.position = SCNVector3(0.1, 0.58, 0)
        node.addChildNode(pompomNode)

        return node
    }

    // MARK: - Bunny Ears

    private static func buildBunnyEars() -> SCNNode {
        let node = SCNNode()
        let outerMaterial = SCNMaterial()
        outerMaterial.diffuse.contents = NSColor(hex: "#FAFAFA")

        let innerMaterial = SCNMaterial()
        innerMaterial.diffuse.contents = NSColor(hex: "#F8BBD0")

        // Left ear
        let earOuter = SCNBox(width: 0.08, height: 0.35, length: 0.04, chamferRadius: 0.02)
        earOuter.materials = [outerMaterial]
        let leftEar = SCNNode(geometry: earOuter)
        leftEar.position = SCNVector3(-0.12, 0.4, 0)
        leftEar.eulerAngles.z = 0.15
        node.addChildNode(leftEar)

        let earInner = SCNBox(width: 0.04, height: 0.25, length: 0.02, chamferRadius: 0.01)
        earInner.materials = [innerMaterial]
        let leftInner = SCNNode(geometry: earInner)
        leftInner.position = SCNVector3(-0.12, 0.4, 0.02)
        leftInner.eulerAngles.z = 0.15
        node.addChildNode(leftInner)

        // Right ear
        let rightEar = SCNNode(geometry: earOuter)
        rightEar.position = SCNVector3(0.12, 0.4, 0)
        rightEar.eulerAngles.z = -0.15
        node.addChildNode(rightEar)

        let rightInner = SCNNode(geometry: earInner)
        rightInner.position = SCNVector3(0.12, 0.4, 0.02)
        rightInner.eulerAngles.z = -0.15
        node.addChildNode(rightInner)

        return node
    }

    // MARK: - Pirate Hat

    private static func buildPirateHat() -> SCNNode {
        let node = SCNNode()
        let hatMaterial = SCNMaterial()
        hatMaterial.diffuse.contents = NSColor(hex: "#212121")

        // Main body (wide brim folded up)
        let body = SCNBox(width: 0.5, height: 0.2, length: 0.35, chamferRadius: 0.05)
        body.materials = [hatMaterial]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 0.3, 0)
        node.addChildNode(bodyNode)

        // Skull and crossbones (simplified as white sphere)
        let skullMaterial = SCNMaterial()
        skullMaterial.diffuse.contents = NSColor(hex: "#FAFAFA")
        let skull = SCNSphere(radius: 0.04)
        skull.materials = [skullMaterial]
        let skullNode = SCNNode(geometry: skull)
        skullNode.position = SCNVector3(0, 0.3, 0.18)
        node.addChildNode(skullNode)

        // Gold trim
        let goldMaterial = SCNMaterial()
        goldMaterial.diffuse.contents = NSColor(hex: "#FFD700")
        goldMaterial.metalness.contents = 0.6
        let trim = SCNBox(width: 0.52, height: 0.02, length: 0.37, chamferRadius: 0)
        trim.materials = [goldMaterial]
        let trimNode = SCNNode(geometry: trim)
        trimNode.position = SCNVector3(0, 0.21, 0)
        node.addChildNode(trimNode)

        return node
    }

    // MARK: - Halo

    private static func buildHalo() -> SCNNode {
        let node = SCNNode()
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(hex: "#FFD700").withAlphaComponent(0.7)
        material.emission.contents = NSColor(hex: "#FFD700")
        material.emission.intensity = 1.0
        material.blendMode = .add

        let ring = SCNTorus(ringRadius: 0.22, pipeRadius: 0.02)
        ring.materials = [material]
        let ringNode = SCNNode(geometry: ring)
        ringNode.position = SCNVector3(0, 0.45, 0)
        node.addChildNode(ringNode)

        // Glow pulse
        let scaleUp = SCNAction.scale(to: 1.1, duration: 1.0)
        scaleUp.timingMode = .easeInEaseOut
        let scaleDown = SCNAction.scale(to: 0.95, duration: 1.0)
        scaleDown.timingMode = .easeInEaseOut
        ringNode.runAction(.repeatForever(.sequence([scaleUp, scaleDown])))

        return node
    }

    // MARK: - Devil Horns

    private static func buildDevilHorns() -> SCNNode {
        let node = SCNNode()
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(hex: "#B71C1C")
        material.emission.contents = NSColor(hex: "#D32F2F")
        material.emission.intensity = 0.3

        // Left horn
        let horn = SCNCone(topRadius: 0.01, bottomRadius: 0.04, height: 0.2)
        horn.materials = [material]
        let leftHorn = SCNNode(geometry: horn)
        leftHorn.position = SCNVector3(-0.15, 0.32, 0)
        leftHorn.eulerAngles.z = 0.3
        node.addChildNode(leftHorn)

        // Right horn
        let rightHorn = SCNNode(geometry: horn)
        rightHorn.position = SCNVector3(0.15, 0.32, 0)
        rightHorn.eulerAngles.z = -0.3
        node.addChildNode(rightHorn)

        return node
    }

    // MARK: - Samurai Helmet

    private static func buildSamuraiHelmet() -> SCNNode {
        let node = SCNNode()
        let metalMaterial = SCNMaterial()
        metalMaterial.diffuse.contents = NSColor(hex: "#37474F")
        metalMaterial.metalness.contents = 0.7
        metalMaterial.roughness.contents = 0.3

        // Dome
        let dome = SCNSphere(radius: 0.25)
        dome.materials = [metalMaterial]
        let domeNode = SCNNode(geometry: dome)
        domeNode.position = SCNVector3(0, 0.25, 0)
        domeNode.scale = SCNVector3(1, 0.6, 1)
        node.addChildNode(domeNode)

        // Crest (maedate)
        let crestMaterial = SCNMaterial()
        crestMaterial.diffuse.contents = NSColor(hex: "#FFD700")
        crestMaterial.metalness.contents = 0.8
        let crest = SCNBox(width: 0.04, height: 0.2, length: 0.02, chamferRadius: 0)
        crest.materials = [crestMaterial]
        let crestNode = SCNNode(geometry: crest)
        crestNode.position = SCNVector3(0, 0.42, 0.1)
        node.addChildNode(crestNode)

        // Side flaps (shikoro)
        let flapMaterial = SCNMaterial()
        flapMaterial.diffuse.contents = NSColor(hex: "#263238")
        flapMaterial.metalness.contents = 0.5
        for xOff: Float in [-0.2, 0.2] {
            let flap = SCNBox(width: 0.06, height: 0.12, length: 0.15, chamferRadius: 0)
            flap.materials = [flapMaterial]
            let flapNode = SCNNode(geometry: flap)
            flapNode.position = SCNVector3(xOff, 0.15, 0)
            node.addChildNode(flapNode)
        }

        return node
    }

    // MARK: - Party Hat

    private static func buildPartyHat() -> SCNNode {
        let node = SCNNode()
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(hex: "#E91E63")

        let cone = SCNCone(topRadius: 0.01, bottomRadius: 0.15, height: 0.3)
        cone.materials = [material]
        let coneNode = SCNNode(geometry: cone)
        coneNode.position = SCNVector3(0, 0.35, 0)
        node.addChildNode(coneNode)

        // Pompom on top
        let pompomMaterial = SCNMaterial()
        pompomMaterial.diffuse.contents = NSColor(hex: "#FFEB3B")
        let pompom = SCNSphere(radius: 0.035)
        pompom.materials = [pompomMaterial]
        let pompomNode = SCNNode(geometry: pompom)
        pompomNode.position = SCNVector3(0, 0.51, 0)
        node.addChildNode(pompomNode)

        // Stripe decorations
        let stripeMaterial = SCNMaterial()
        stripeMaterial.diffuse.contents = NSColor(hex: "#FFD700")
        for y: Float in [0.28, 0.38, 0.48] {
            let stripe = SCNCylinder(radius: CGFloat(0.15 - (y - 0.28) * 0.3), height: 0.015)
            stripe.materials = [stripeMaterial]
            let stripeNode = SCNNode(geometry: stripe)
            stripeNode.position = SCNVector3(0, y, 0)
            node.addChildNode(stripeNode)
        }

        return node
    }

    // MARK: - Pumpkin Head

    private static func buildPumpkinHead() -> SCNNode {
        let node = SCNNode()
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(hex: "#E65100")
        material.emission.contents = NSColor(hex: "#FF6D00")
        material.emission.intensity = 0.3

        // Pumpkin body
        let pumpkin = SCNSphere(radius: 0.25)
        pumpkin.materials = [material]
        let pumpkinNode = SCNNode(geometry: pumpkin)
        pumpkinNode.position = SCNVector3(0, 0.3, 0)
        pumpkinNode.scale = SCNVector3(1, 0.8, 0.9)
        node.addChildNode(pumpkinNode)

        // Stem
        let stemMaterial = SCNMaterial()
        stemMaterial.diffuse.contents = NSColor(hex: "#33691E")
        let stem = SCNCylinder(radius: 0.03, height: 0.08)
        stem.materials = [stemMaterial]
        let stemNode = SCNNode(geometry: stem)
        stemNode.position = SCNVector3(0, 0.52, 0)
        node.addChildNode(stemNode)

        // Glowing eyes (triangle-ish)
        let eyeMaterial = SCNMaterial()
        eyeMaterial.diffuse.contents = NSColor(hex: "#FFEB3B")
        eyeMaterial.emission.contents = NSColor(hex: "#FFEB3B")
        eyeMaterial.emission.intensity = 1.0
        let eye = SCNBox(width: 0.06, height: 0.05, length: 0.02, chamferRadius: 0)
        eye.materials = [eyeMaterial]

        let leftEye = SCNNode(geometry: eye)
        leftEye.position = SCNVector3(-0.08, 0.35, 0.22)
        node.addChildNode(leftEye)

        let rightEye = SCNNode(geometry: eye)
        rightEye.position = SCNVector3(0.08, 0.35, 0.22)
        node.addChildNode(rightEye)

        // Mouth
        let mouth = SCNBox(width: 0.12, height: 0.03, length: 0.02, chamferRadius: 0)
        mouth.materials = [eyeMaterial]
        let mouthNode = SCNNode(geometry: mouth)
        mouthNode.position = SCNVector3(0, 0.24, 0.22)
        node.addChildNode(mouthNode)

        return node
    }
}
