import SwiftUI

struct ConversationComposerAttachSheet: View {
    let onPickPhotoLibrary: () -> Void
    let onTakePhoto: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Attach")
                .shitterFont(.headline, weight: .semibold)
                .foregroundColor(ShitterTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onPickPhotoLibrary) {
                sheetButtonLabel("Photo Library", systemImage: "photo.on.rectangle")
            }

            Button(action: onTakePhoto) {
                sheetButtonLabel("Take Photo", systemImage: "camera")
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ShitterTheme.backgroundGradient.ignoresSafeArea())
    }

    @ViewBuilder
    private func sheetButtonLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .shitterFont(.body, weight: .medium)
                .foregroundColor(ShitterTheme.accent)
                .frame(width: 20)

            Text(title)
                .shitterFont(.body, weight: .medium)
                .foregroundColor(ShitterTheme.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .modifier(GlassRoundedRectModifier(cornerRadius: 18))
    }
}
