import SwiftUI

struct AudioButton: View {
    var body: some View {
        Button {
            // Audio generation disabled for POC
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "speaker.slash.fill")
                Text("Аудіо")
            }
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.glass)
        .disabled(true)
        .opacity(0.5)
        .accessibilityLabel("Аудіо вимова — незабаром")
    }
}
