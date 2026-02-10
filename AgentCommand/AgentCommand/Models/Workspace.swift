import Foundation

struct Workspace: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var lastUsedAt: Date
    var isDefault: Bool

    var url: URL { URL(fileURLWithPath: path) }

    var displayPath: String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}
