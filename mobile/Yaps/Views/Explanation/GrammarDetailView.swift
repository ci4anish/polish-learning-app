import SwiftUI

struct GrammarDetailView: View {
    let result: ExplanationResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    translationSection
                    if let declension = result.declension, !declension.isEmpty {
                        declensionSection(declension)
                    }
                    examplesSection
                    audioSection
                }
                .padding(YapsTheme.padding)
            }
            .navigationTitle(result.selectedText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var translationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Translation", icon: "character.book.closed.fill")

            VStack(alignment: .leading, spacing: 8) {
                Text(result.translation)
                    .font(.system(.title2, design: .rounded, weight: .bold))

                HStack(spacing: 12) {
                    infoPill(result.partOfSpeech)
                    if let gender = result.gender {
                        infoPill(gender)
                    }
                    if let gramCase = result.grammaticalCase {
                        infoPill(gramCase)
                    }
                }
            }
            .padding(YapsTheme.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: YapsTheme.smallCornerRadius))
        }
    }

    private func declensionSection(_ entries: [ExplanationResult.DeclensionEntry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Declension Table", icon: "tablecells")

            VStack(spacing: 0) {
                headerRow
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    declensionRow(entry, isEven: index % 2 == 0)
                }
            }
            .clipShape(.rect(cornerRadius: YapsTheme.smallCornerRadius))
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("Case")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Singular")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Plural")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(.caption, design: .rounded, weight: .bold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.tint.opacity(0.1))
    }

    private func declensionRow(_ entry: ExplanationResult.DeclensionEntry, isEven: Bool) -> some View {
        HStack(spacing: 0) {
            Text(entry.caseName)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(entry.singular)
                .font(.system(.caption, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(entry.plural)
                .font(.system(.caption, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isEven ? Color.clear : Color.primary.opacity(0.03))
    }

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Examples", icon: "text.quote")

            VStack(spacing: 10) {
                ForEach(result.examples) { example in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(example.polish)
                            .font(.system(.body, design: .rounded, weight: .medium))
                        Text(example.english)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: YapsTheme.smallCornerRadius))
                }
            }
        }
    }

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Pronunciation", icon: "speaker.wave.2.fill")

            AudioButton()
                .frame(maxWidth: .infinity)
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(.primary)
    }

    private func infoPill(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption2, design: .rounded, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.tint.opacity(0.12), in: .capsule)
            .foregroundStyle(.tint)
    }
}
