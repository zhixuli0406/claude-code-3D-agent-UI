import Foundation

extension Foundation.Bundle {
    static let module: Bundle = {
        let mainPath = Bundle.main.bundleURL.appendingPathComponent("AgentCommand_AgentCommand.bundle").path
        let buildPath = "/Users/lizhixu/Project/claude-code-3D-agent-UI/AgentCommand/.build/x86_64-apple-macosx/debug/AgentCommand_AgentCommand.bundle"

        let preferredBundle = Bundle(path: mainPath)

        guard let bundle = preferredBundle ?? Bundle(path: buildPath) else {
            // Users can write a function called fatalError themselves, we should be resilient against that.
            Swift.fatalError("could not load resource bundle: from \(mainPath) or \(buildPath)")
        }

        return bundle
    }()
}