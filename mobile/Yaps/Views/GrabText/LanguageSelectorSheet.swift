import SwiftUI

struct LanguageSelectorSheet: View {
    let onSelect: (ContentLanguage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [ContentLanguage] {
        guard !searchText.isEmpty else { return ContentLanguage.all }
        let query = searchText.lowercased()
        return ContentLanguage.all.filter {
            $0.name.lowercased().contains(query) ||
            $0.nativeName.lowercased().contains(query) ||
            $0.id.lowercased() == query
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { language in
                Button {
                    YapsTheme.hapticTap()
                    onSelect(language)
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        FlagBadge(colors: language.flagColors, size: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(language.name)
                                .font(.system(.body, design: .rounded, weight: .medium))
                                .foregroundStyle(.primary)
                            Text(language.nativeName)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search languages")
            .navigationTitle("Content Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct FlagBadge: View {
    let colors: [Color]
    var size: CGFloat = 36

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: colors.map { $0.opacity(0.7) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(0.3), lineWidth: 1)
            )
    }
}
