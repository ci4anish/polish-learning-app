import Foundation

struct TextBlock: Codable, Identifiable, Sendable, Equatable {
    var id: String { "\(type)-\(relativeHeight)-\(original.prefix(40))" }
    let type: BlockType
    let relativeHeight: CGFloat
    let original: String

    enum BlockType: String, Codable, Sendable {
        case heading
        case paragraph
    }
}
