import SceneKit

struct GitVisualizationBuilder {

    // MARK: - Floating Diff Code Blocks

    static func buildDiffPanel(file: GitDiffFile, index: Int, total: Int) -> SCNNode {
        let container = SCNNode()
        container.name = "diffPanel_\(index)"

        // Arc layout: spread panels in a semi-circle
        let angleSpread: Float = Float.pi * 0.6
        let startAngle: Float = -angleSpread / 2
        let angleStep: Float = total > 1 ? angleSpread / Float(total - 1) : 0
        let angle = startAngle + Float(index) * angleStep
        let radius: Float = 4.0

        container.position = SCNVector3(
            sin(angle) * radius,
            Float(index) * 0.1,
            -cos(angle) * radius
        )

        // Billboard constraint to face camera
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        container.constraints = [billboard]

        // Background plane
        let panelWidth: CGFloat = 3.0
        let panelHeight: CGFloat = 2.2
        let bg = SCNPlane(width: panelWidth, height: panelHeight)
        let bgMat = SCNMaterial()
        bgMat.diffuse.contents = NSColor(hex: "#0D1117").withAlphaComponent(0.88)
        bgMat.emission.contents = NSColor(hex: "#161B22")
        bgMat.emission.intensity = 0.1
        bgMat.isDoubleSided = true
        bg.materials = [bgMat]
        let bgNode = SCNNode(geometry: bg)
        container.addChildNode(bgNode)

        // Border glow
        let borderColor: NSColor
        switch file.status {
        case .added: borderColor = NSColor(hex: "#4CAF50")
        case .deleted: borderColor = NSColor(hex: "#F44336")
        case .modified: borderColor = NSColor(hex: "#FF9800")
        case .renamed: borderColor = NSColor(hex: "#2196F3")
        case .untracked: borderColor = NSColor(hex: "#9E9E9E")
        }

        let borderPlane = SCNPlane(width: panelWidth + 0.04, height: panelHeight + 0.04)
        let borderMat = SCNMaterial()
        borderMat.diffuse.contents = borderColor.withAlphaComponent(0.3)
        borderMat.emission.contents = borderColor
        borderMat.emission.intensity = 0.6
        borderMat.isDoubleSided = true
        borderPlane.materials = [borderMat]
        let borderNode = SCNNode(geometry: borderPlane)
        borderNode.position = SCNVector3(0, 0, -0.005)
        container.addChildNode(borderNode)

        // File path header
        let headerText = SCNText(string: file.filePath, extrusionDepth: 0.005)
        headerText.font = NSFont(name: "Menlo-Bold", size: 0.09) ?? NSFont.monospacedSystemFont(ofSize: 0.09, weight: .bold)
        headerText.flatness = 0.3
        let headerMat = SCNMaterial()
        headerMat.diffuse.contents = NSColor.white
        headerMat.emission.contents = NSColor.white
        headerMat.emission.intensity = 0.3
        headerText.materials = [headerMat]
        let headerNode = SCNNode(geometry: headerText)
        headerNode.position = SCNVector3(-Float(panelWidth / 2) + 0.1, Float(panelHeight / 2) - 0.25, 0.01)
        headerNode.scale = SCNVector3(0.7, 0.7, 0.7)
        container.addChildNode(headerNode)

        // Stats line: +N -N
        let statsStr = "+\(file.additions)  -\(file.deletions)"
        let statsText = SCNText(string: statsStr, extrusionDepth: 0.003)
        statsText.font = NSFont(name: "Menlo", size: 0.07) ?? NSFont.monospacedSystemFont(ofSize: 0.07, weight: .regular)
        statsText.flatness = 0.3
        let statsMat = SCNMaterial()
        statsMat.diffuse.contents = NSColor(hex: "#8B949E")
        statsMat.emission.contents = NSColor(hex: "#8B949E")
        statsMat.emission.intensity = 0.2
        statsText.materials = [statsMat]
        let statsNode = SCNNode(geometry: statsText)
        statsNode.position = SCNVector3(-Float(panelWidth / 2) + 0.1, Float(panelHeight / 2) - 0.45, 0.01)
        statsNode.scale = SCNVector3(0.6, 0.6, 0.6)
        container.addChildNode(statsNode)

        // Diff lines (limited to first hunk, max 20 lines)
        var yOffset: Float = Float(panelHeight / 2) - 0.6
        let lineHeight: Float = 0.08
        var linesShown = 0
        let maxLines = 20

        for hunk in file.hunks {
            guard linesShown < maxLines else { break }
            for line in hunk.lines {
                guard linesShown < maxLines else { break }
                let lineNode = buildDiffLineNode(line: line, yOffset: yOffset, panelWidth: Float(panelWidth))
                container.addChildNode(lineNode)
                yOffset -= lineHeight
                linesShown += 1
            }
        }

        // Floating bob animation
        let bobUp = SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: 2.0 + Double(index) * 0.3)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SCNAction.moveBy(x: 0, y: -0.05, z: 0, duration: 2.0 + Double(index) * 0.3)
        bobDown.timingMode = .easeInEaseOut
        container.runAction(.repeatForever(.sequence([bobUp, bobDown])))

        return container
    }

    private static func buildDiffLineNode(line: GitDiffLine, yOffset: Float, panelWidth: Float) -> SCNNode {
        let color: NSColor
        let prefix: String
        switch line.type {
        case .addition:
            color = NSColor(hex: "#4CAF50")
            prefix = "+"
        case .deletion:
            color = NSColor(hex: "#F44336")
            prefix = "-"
        case .context:
            color = NSColor(hex: "#8B949E")
            prefix = " "
        }

        let displayText = prefix + line.content.prefix(60).description
        let text = SCNText(string: displayText, extrusionDepth: 0.002)
        text.font = NSFont(name: "Menlo", size: 0.06) ?? NSFont.monospacedSystemFont(ofSize: 0.06, weight: .regular)
        text.flatness = 0.4
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.emission.contents = color
        mat.emission.intensity = 0.2
        text.materials = [mat]

        let node = SCNNode(geometry: text)
        node.position = SCNVector3(-panelWidth / 2 + 0.1, yOffset, 0.01)
        node.scale = SCNVector3(0.5, 0.5, 0.5)
        return node
    }

    // MARK: - Branch Tree Structure

    static func buildBranchTree(branches: [GitBranch], currentBranch: String) -> SCNNode {
        let container = SCNNode()
        container.name = "gitBranchTree"

        // Main trunk (vertical cylinder)
        let trunkHeight: CGFloat = 4.0
        let trunk = SCNCylinder(radius: 0.06, height: trunkHeight)
        let trunkMat = SCNMaterial()
        trunkMat.diffuse.contents = NSColor(hex: "#8B949E")
        trunkMat.emission.contents = NSColor(hex: "#8B949E")
        trunkMat.emission.intensity = 0.3
        trunk.materials = [trunkMat]
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, Float(trunkHeight / 2), 0)
        container.addChildNode(trunkNode)

        // "main" label at trunk base
        let mainLabel = buildBranchLabel("main", color: NSColor(hex: "#00BCD4"), isCurrent: currentBranch == "main")
        mainLabel.position = SCNVector3(0.2, 0.3, 0)
        container.addChildNode(mainLabel)

        // Local branches
        let localBranches = branches.filter { !$0.isRemote && $0.name != "main" && $0.name != "master" }
        let branchCount = localBranches.count

        for (i, branch) in localBranches.enumerated() {
            let yPos = Float(trunkHeight) * (Float(i + 1) / Float(branchCount + 1))
            let side: Float = i % 2 == 0 ? 1.0 : -1.0
            let isCurrent = branch.name == currentBranch

            // Branch line
            let branchLength: CGFloat = 1.5
            let line = SCNCylinder(radius: 0.03, height: branchLength)
            let lineMat = SCNMaterial()
            let branchColor = isCurrent ? NSColor(hex: "#00BCD4") : NSColor(hex: "#58A6FF")
            lineMat.diffuse.contents = branchColor
            lineMat.emission.contents = branchColor
            lineMat.emission.intensity = isCurrent ? 0.8 : 0.3
            line.materials = [lineMat]
            let lineNode = SCNNode(geometry: line)
            lineNode.position = SCNVector3(side * Float(branchLength / 2), yPos, 0)
            lineNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            container.addChildNode(lineNode)

            // Branch tip sphere
            let sphere = SCNSphere(radius: 0.08)
            let sphereMat = SCNMaterial()
            sphereMat.diffuse.contents = branchColor
            sphereMat.emission.contents = branchColor
            sphereMat.emission.intensity = isCurrent ? 1.0 : 0.4
            sphere.materials = [sphereMat]
            let sphereNode = SCNNode(geometry: sphere)
            sphereNode.position = SCNVector3(side * Float(branchLength), yPos, 0)
            container.addChildNode(sphereNode)

            // Branch label
            let label = buildBranchLabel(branch.name, color: branchColor, isCurrent: isCurrent)
            label.position = SCNVector3(side * (Float(branchLength) + 0.3), yPos, 0)
            container.addChildNode(label)

            // Pulse animation for current branch tip
            if isCurrent {
                let scaleUp = SCNAction.scale(to: 1.3, duration: 0.8)
                scaleUp.timingMode = .easeInEaseOut
                let scaleDown = SCNAction.scale(to: 1.0, duration: 0.8)
                scaleDown.timingMode = .easeInEaseOut
                sphereNode.runAction(.repeatForever(.sequence([scaleUp, scaleDown])))
            }
        }

        // Slow rotation animation
        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 30.0)
        container.runAction(.repeatForever(rotate))

        return container
    }

    private static func buildBranchLabel(_ name: String, color: NSColor, isCurrent: Bool) -> SCNNode {
        let text = SCNText(string: name, extrusionDepth: 0.005)
        text.font = NSFont(name: "Menlo-Bold", size: 0.1) ?? NSFont.monospacedSystemFont(ofSize: 0.1, weight: .bold)
        text.flatness = 0.3
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.emission.contents = color
        mat.emission.intensity = isCurrent ? 0.6 : 0.2
        text.materials = [mat]

        let node = SCNNode(geometry: text)
        node.scale = SCNVector3(0.6, 0.6, 0.6)

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        node.constraints = [billboard]

        return node
    }

    // MARK: - Commit Timeline

    static func buildCommitTimeline(commits: [GitCommit], agents: [Agent]) -> SCNNode {
        let container = SCNNode()
        container.name = "gitCommitTimeline"

        let commitsToShow = Array(commits.prefix(20))
        guard !commitsToShow.isEmpty else { return container }

        let spacing: Float = 0.8
        let totalWidth = Float(commitsToShow.count - 1) * spacing

        // Timeline axis line
        let axisLength = CGFloat(totalWidth + 1.0)
        let axis = SCNBox(width: axisLength, height: 0.02, length: 0.02, chamferRadius: 0.005)
        let axisMat = SCNMaterial()
        axisMat.diffuse.contents = NSColor(hex: "#30363D")
        axisMat.emission.contents = NSColor(hex: "#484F58")
        axisMat.emission.intensity = 0.3
        axis.materials = [axisMat]
        let axisNode = SCNNode(geometry: axis)
        axisNode.position = SCNVector3(0, 0, 0)
        container.addChildNode(axisNode)

        // Commit nodes
        for (i, commit) in commitsToShow.enumerated() {
            let x = -totalWidth / 2 + Float(i) * spacing
            let agent = agents.first { $0.id == commit.agentId }

            let commitNode = buildCommitNode(commit: commit, agent: agent, position: SCNVector3(x, 0, 0))
            container.addChildNode(commitNode)
        }

        return container
    }

    private static func buildCommitNode(commit: GitCommit, agent: Agent?, position: SCNVector3) -> SCNNode {
        let container = SCNNode()
        container.position = position

        // Commit sphere
        let sphereRadius: CGFloat = 0.1
        let sphere = SCNSphere(radius: sphereRadius)
        let sphereMat = SCNMaterial()
        let commitColor = commit.branchName != nil ? NSColor(hex: "#58A6FF") : NSColor(hex: "#8B949E")
        sphereMat.diffuse.contents = commitColor
        sphereMat.emission.contents = commitColor
        sphereMat.emission.intensity = 0.5
        sphere.materials = [sphereMat]
        let sphereNode = SCNNode(geometry: sphere)
        container.addChildNode(sphereNode)

        // Vertical connection line to message
        let connectionHeight: CGFloat = 0.5
        let connection = SCNCylinder(radius: 0.01, height: connectionHeight)
        let connMat = SCNMaterial()
        connMat.diffuse.contents = commitColor.withAlphaComponent(0.5)
        connection.materials = [connMat]
        let connNode = SCNNode(geometry: connection)
        connNode.position = SCNVector3(0, Float(connectionHeight / 2) + Float(sphereRadius), 0)
        container.addChildNode(connNode)

        // Commit hash label
        let hashText = SCNText(string: commit.hash, extrusionDepth: 0.003)
        hashText.font = NSFont(name: "Menlo", size: 0.06) ?? NSFont.monospacedSystemFont(ofSize: 0.06, weight: .regular)
        hashText.flatness = 0.4
        let hashMat = SCNMaterial()
        hashMat.diffuse.contents = NSColor(hex: "#58A6FF")
        hashMat.emission.contents = NSColor(hex: "#58A6FF")
        hashMat.emission.intensity = 0.3
        hashText.materials = [hashMat]
        let hashNode = SCNNode(geometry: hashText)
        hashNode.position = SCNVector3(-0.1, Float(connectionHeight) + 0.15, 0)
        hashNode.scale = SCNVector3(0.5, 0.5, 0.5)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        hashNode.constraints = [billboard]
        container.addChildNode(hashNode)

        // Commit message (truncated)
        let msgStr = String(commit.message.prefix(40))
        let msgText = SCNText(string: msgStr, extrusionDepth: 0.003)
        msgText.font = NSFont(name: "Menlo", size: 0.05) ?? NSFont.monospacedSystemFont(ofSize: 0.05, weight: .regular)
        msgText.flatness = 0.4
        let msgMat = SCNMaterial()
        msgMat.diffuse.contents = NSColor(hex: "#C9D1D9")
        msgMat.emission.contents = NSColor(hex: "#C9D1D9")
        msgMat.emission.intensity = 0.15
        msgText.materials = [msgMat]
        let msgNode = SCNNode(geometry: msgText)
        msgNode.position = SCNVector3(-0.1, Float(connectionHeight) + 0.02, 0)
        msgNode.scale = SCNVector3(0.4, 0.4, 0.4)
        msgNode.constraints = [billboard]
        container.addChildNode(msgNode)

        // Agent mini avatar (colored sphere if linked)
        if let agent = agent {
            let avatarNode = buildMiniAvatar(agent: agent)
            avatarNode.position = SCNVector3(0, -0.25, 0)
            container.addChildNode(avatarNode)
        }

        // Author label below
        let authorText = SCNText(string: commit.author, extrusionDepth: 0.002)
        authorText.font = NSFont.systemFont(ofSize: 0.04, weight: .regular)
        authorText.flatness = 0.4
        let authorMat = SCNMaterial()
        authorMat.diffuse.contents = NSColor(hex: "#8B949E")
        authorText.materials = [authorMat]
        let authorNode = SCNNode(geometry: authorText)
        authorNode.position = SCNVector3(-0.1, -0.35, 0)
        authorNode.scale = SCNVector3(0.4, 0.4, 0.4)
        authorNode.constraints = [billboard]
        container.addChildNode(authorNode)

        return container
    }

    private static func buildMiniAvatar(agent: Agent) -> SCNNode {
        let container = SCNNode()

        // Mini head (simple colored cube as a voxel-style mini head)
        let headSize: CGFloat = 0.12
        let head = SCNBox(width: headSize, height: headSize, length: headSize, chamferRadius: 0.01)
        let headMat = SCNMaterial()
        let skinColor = NSColor(hex: agent.appearance.skinColor)
        headMat.diffuse.contents = skinColor
        headMat.emission.contents = skinColor
        headMat.emission.intensity = 0.2
        head.materials = [headMat]
        let headNode = SCNNode(geometry: head)
        container.addChildNode(headNode)

        // Mini eyes
        let eyeSize: CGFloat = 0.03
        let eyeGeo = SCNBox(width: eyeSize, height: eyeSize, length: 0.01, chamferRadius: 0)
        let eyeMat = SCNMaterial()
        eyeMat.diffuse.contents = NSColor.white
        eyeGeo.materials = [eyeMat]

        let leftEye = SCNNode(geometry: eyeGeo)
        leftEye.position = SCNVector3(-0.025, 0.015, Float(headSize / 2) + 0.005)
        container.addChildNode(leftEye)

        let rightEye = SCNNode(geometry: eyeGeo)
        rightEye.position = SCNVector3(0.025, 0.015, Float(headSize / 2) + 0.005)
        container.addChildNode(rightEye)

        // Name tag
        let nameText = SCNText(string: agent.name, extrusionDepth: 0.002)
        nameText.font = NSFont.systemFont(ofSize: 0.04, weight: .medium)
        nameText.flatness = 0.4
        let nameMat = SCNMaterial()
        nameMat.diffuse.contents = NSColor(hex: "#C9D1D9")
        nameText.materials = [nameMat]
        let nameNode = SCNNode(geometry: nameText)
        nameNode.position = SCNVector3(-0.05, Float(headSize / 2) + 0.02, 0)
        nameNode.scale = SCNVector3(0.3, 0.3, 0.3)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        nameNode.constraints = [billboard]
        container.addChildNode(nameNode)

        return container
    }

    // MARK: - PR Preview Card

    static func buildPRPreviewCard(pr: PRPreviewData) -> SCNNode {
        let container = SCNNode()
        container.name = "gitPRPreview"

        let cardWidth: CGFloat = 4.0
        let cardHeight: CGFloat = 3.0

        // Billboard
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        container.constraints = [billboard]

        // Background
        let bg = SCNPlane(width: cardWidth, height: cardHeight)
        let bgMat = SCNMaterial()
        bgMat.diffuse.contents = NSColor(hex: "#0D1117").withAlphaComponent(0.92)
        bgMat.emission.contents = NSColor(hex: "#161B22")
        bgMat.emission.intensity = 0.1
        bgMat.isDoubleSided = true
        bg.materials = [bgMat]
        let bgNode = SCNNode(geometry: bg)
        container.addChildNode(bgNode)

        // Purple accent border
        let border = SCNPlane(width: cardWidth + 0.04, height: cardHeight + 0.04)
        let borderMat = SCNMaterial()
        borderMat.diffuse.contents = NSColor(hex: "#9C27B0").withAlphaComponent(0.3)
        borderMat.emission.contents = NSColor(hex: "#9C27B0")
        borderMat.emission.intensity = 0.5
        borderMat.isDoubleSided = true
        border.materials = [borderMat]
        let borderNode = SCNNode(geometry: border)
        borderNode.position = SCNVector3(0, 0, -0.005)
        container.addChildNode(borderNode)

        var yPos: Float = Float(cardHeight / 2) - 0.3

        // "Pull Request" header
        let headerText = SCNText(string: "Pull Request", extrusionDepth: 0.005)
        headerText.font = NSFont.systemFont(ofSize: 0.14, weight: .bold)
        headerText.flatness = 0.2
        let headerMat = SCNMaterial()
        headerMat.diffuse.contents = NSColor(hex: "#9C27B0")
        headerMat.emission.contents = NSColor(hex: "#9C27B0")
        headerMat.emission.intensity = 0.5
        headerText.materials = [headerMat]
        let headerNode = SCNNode(geometry: headerText)
        headerNode.position = SCNVector3(-Float(cardWidth / 2) + 0.2, yPos, 0.01)
        headerNode.scale = SCNVector3(0.6, 0.6, 0.6)
        container.addChildNode(headerNode)

        yPos -= 0.35

        // Title
        let titleText = SCNText(string: pr.title, extrusionDepth: 0.003)
        titleText.font = NSFont.systemFont(ofSize: 0.1, weight: .semibold)
        titleText.flatness = 0.3
        let titleMat = SCNMaterial()
        titleMat.diffuse.contents = NSColor.white
        titleMat.emission.contents = NSColor.white
        titleMat.emission.intensity = 0.2
        titleText.materials = [titleMat]
        let titleNode = SCNNode(geometry: titleText)
        titleNode.position = SCNVector3(-Float(cardWidth / 2) + 0.2, yPos, 0.01)
        titleNode.scale = SCNVector3(0.5, 0.5, 0.5)
        container.addChildNode(titleNode)

        yPos -= 0.3

        // Branch info: source -> target
        let branchStr = "\(pr.sourceBranch) → \(pr.targetBranch)"
        let branchText = SCNText(string: branchStr, extrusionDepth: 0.003)
        branchText.font = NSFont(name: "Menlo", size: 0.08) ?? NSFont.monospacedSystemFont(ofSize: 0.08, weight: .regular)
        branchText.flatness = 0.3
        let branchMat = SCNMaterial()
        branchMat.diffuse.contents = NSColor(hex: "#58A6FF")
        branchMat.emission.contents = NSColor(hex: "#58A6FF")
        branchMat.emission.intensity = 0.3
        branchText.materials = [branchMat]
        let branchNode = SCNNode(geometry: branchText)
        branchNode.position = SCNVector3(-Float(cardWidth / 2) + 0.2, yPos, 0.01)
        branchNode.scale = SCNVector3(0.5, 0.5, 0.5)
        container.addChildNode(branchNode)

        yPos -= 0.35

        // Stats: commits, files, +additions, -deletions
        let statsStr = "\(pr.commits.count) commits  ·  \(pr.diffFiles.count) files  ·  +\(pr.totalAdditions)  -\(pr.totalDeletions)"
        let statsText = SCNText(string: statsStr, extrusionDepth: 0.003)
        statsText.font = NSFont(name: "Menlo", size: 0.07) ?? NSFont.monospacedSystemFont(ofSize: 0.07, weight: .regular)
        statsText.flatness = 0.3
        let statsMat = SCNMaterial()
        statsMat.diffuse.contents = NSColor(hex: "#8B949E")
        statsText.materials = [statsMat]
        let statsNode = SCNNode(geometry: statsText)
        statsNode.position = SCNVector3(-Float(cardWidth / 2) + 0.2, yPos, 0.01)
        statsNode.scale = SCNVector3(0.5, 0.5, 0.5)
        container.addChildNode(statsNode)

        yPos -= 0.35

        // File list (top 5)
        for file in pr.diffFiles.prefix(5) {
            let icon: String
            let color: NSColor
            switch file.status {
            case .added: icon = "+"; color = NSColor(hex: "#4CAF50")
            case .deleted: icon = "-"; color = NSColor(hex: "#F44336")
            case .modified: icon = "~"; color = NSColor(hex: "#FF9800")
            case .renamed: icon = "→"; color = NSColor(hex: "#2196F3")
            case .untracked: icon = "?"; color = NSColor(hex: "#9E9E9E")
            }

            let fileStr = "\(icon) \(file.filePath)"
            let fileText = SCNText(string: fileStr, extrusionDepth: 0.002)
            fileText.font = NSFont(name: "Menlo", size: 0.06) ?? NSFont.monospacedSystemFont(ofSize: 0.06, weight: .regular)
            fileText.flatness = 0.4
            let fileMat = SCNMaterial()
            fileMat.diffuse.contents = color
            fileMat.emission.contents = color
            fileMat.emission.intensity = 0.15
            fileText.materials = [fileMat]
            let fileNode = SCNNode(geometry: fileText)
            fileNode.position = SCNVector3(-Float(cardWidth / 2) + 0.3, yPos, 0.01)
            fileNode.scale = SCNVector3(0.4, 0.4, 0.4)
            container.addChildNode(fileNode)
            yPos -= 0.18
        }

        // Floating bob animation
        let bobUp = SCNAction.moveBy(x: 0, y: 0.06, z: 0, duration: 2.5)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SCNAction.moveBy(x: 0, y: -0.06, z: 0, duration: 2.5)
        bobDown.timingMode = .easeInEaseOut
        container.runAction(.repeatForever(.sequence([bobUp, bobDown])))

        return container
    }
}
