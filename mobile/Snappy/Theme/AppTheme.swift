import SwiftUI

enum AppTheme {
    static let cornerRadius: CGFloat = 16
    static let smallCornerRadius: CGFloat = 10
    static let padding: CGFloat = 16
    static let smallPadding: CGFloat = 8
    static let largePadding: CGFloat = 24

    static let titleFont: Font = .system(.title, design: .rounded, weight: .bold)
    static let headlineFont: Font = .system(.headline, design: .rounded, weight: .semibold)
    static let bodyFont: Font = .system(.body, design: .rounded)
    static let captionFont: Font = .system(.caption, design: .rounded)

    static let textViewFont: UIFont = .systemFont(ofSize: 20, weight: .regular)
    static let textViewLineSpacing: CGFloat = 8
    static let textViewParagraphSpacing: CGFloat = 12

    static func hapticTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func hapticSuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
