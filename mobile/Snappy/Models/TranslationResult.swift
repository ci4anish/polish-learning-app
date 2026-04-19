import Foundation

struct TextBlock: Codable, Identifiable, Sendable, Equatable {
    var id: String { "\(relativeHeight)-\(original.prefix(40))" }
    let relativeHeight: CGFloat
    let original: String
}
