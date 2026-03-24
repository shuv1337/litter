import SwiftUI

struct ExperimentalFeaturesView: View {
    @State private var experimentalFeatures = ExperimentalFeatures.shared

    var body: some View {
        ZStack {
            ShitterTheme.backgroundGradient.ignoresSafeArea()
            Form {
                Section {
                    ForEach(ShitterFeature.allCases) { feature in
                        Toggle(isOn: binding(for: feature)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(feature.displayName)
                                    .shitterFont(.subheadline)
                                    .foregroundColor(ShitterTheme.textPrimary)
                                Text(feature.description)
                                    .shitterFont(.caption)
                                    .foregroundColor(ShitterTheme.textSecondary)
                            }
                        }
                        .tint(ShitterTheme.accentStrong)
                        .listRowBackground(ShitterTheme.surface.opacity(0.6))
                    }
                } header: {
                    Text("Features")
                        .foregroundColor(ShitterTheme.textSecondary)
                } footer: {
                    Text("Experimental features may be unstable or change without notice.")
                        .foregroundColor(ShitterTheme.textMuted)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Experimental")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func binding(for feature: ShitterFeature) -> Binding<Bool> {
        Binding(
            get: { experimentalFeatures.isEnabled(feature) },
            set: { newValue in
                experimentalFeatures.setEnabled(feature, newValue)
            }
        )
    }
}

#if DEBUG
#Preview("Experimental Features") {
    NavigationStack {
        ExperimentalFeaturesView()
    }
}
#endif
