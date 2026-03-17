import SwiftUI

enum ConversationComposerPopupState {
    case none
    case slash([ComposerSlashCommand])
    case file(loading: Bool, error: String?, suggestions: [FuzzyFileSearchResult])
    case skill(loading: Bool, suggestions: [SkillMetadata])
}

struct ConversationComposerPopupOverlayView: View {
    let state: ConversationComposerPopupState
    let onApplySlashSuggestion: (ComposerSlashCommand) -> Void
    let onApplyFileSuggestion: (FuzzyFileSearchResult) -> Void
    let onApplySkillSuggestion: (SkillMetadata) -> Void

    var body: some View {
        switch state {
        case .none:
            EmptyView()

        case .slash(let suggestions):
            suggestionPopup {
                ForEach(Array(suggestions.enumerated()), id: \.element.rawValue) { index, command in
                    VStack(spacing: 0) {
                        Button {
                            onApplySlashSuggestion(command)
                        } label: {
                            HStack(spacing: 10) {
                                Text("/\(command.rawValue)")
                                    .shitterFont(.body)
                                    .foregroundColor(ShitterTheme.success)
                                Text(command.description)
                                    .shitterFont(.body)
                                    .foregroundColor(ShitterTheme.textSecondary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .background(ShitterTheme.border)
                            .opacity(index < suggestions.count - 1 ? 1 : 0)
                    }
                }
            }

        case .file(let loading, let error, let suggestions):
            suggestionPopup {
                if loading {
                    popupStateText("Searching files...")
                } else if let error, !error.isEmpty {
                    popupStateText(error, color: .red)
                } else if suggestions.isEmpty {
                    popupStateText("No matches")
                } else {
                    ForEach(Array(suggestions.prefix(8).enumerated()), id: \.element.id) { index, suggestion in
                        VStack(spacing: 0) {
                            Button {
                                onApplyFileSuggestion(suggestion)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "folder")
                                        .shitterFont(.caption)
                                        .foregroundColor(ShitterTheme.textSecondary)
                                    Text(suggestion.path)
                                        .shitterFont(.footnote)
                                        .foregroundColor(ShitterTheme.textPrimary)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .background(ShitterTheme.border)
                                .opacity(index < min(suggestions.count, 8) - 1 ? 1 : 0)
                        }
                    }
                }
            }

        case .skill(let loading, let suggestions):
            suggestionPopup {
                if loading && suggestions.isEmpty {
                    popupStateText("Loading skills...")
                } else if suggestions.isEmpty {
                    popupStateText("No skills found")
                } else {
                    ForEach(Array(suggestions.prefix(8).enumerated()), id: \.element.id) { index, skill in
                        VStack(spacing: 0) {
                            Button {
                                onApplySkillSuggestion(skill)
                            } label: {
                                HStack(spacing: 8) {
                                    Text("$\(skill.name)")
                                        .shitterFont(.footnote)
                                        .foregroundColor(ShitterTheme.success)
                                    Text(skill.description)
                                        .shitterFont(.footnote)
                                        .foregroundColor(ShitterTheme.textSecondary)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .background(ShitterTheme.border)
                                .opacity(index < min(suggestions.count, 8) - 1 ? 1 : 0)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func popupStateText(_ text: String, color: Color = ShitterTheme.textSecondary) -> some View {
        Text(text)
            .shitterFont(.footnote)
            .foregroundColor(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
    }

    @ViewBuilder
    private func suggestionPopup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity)
        .background(ShitterTheme.surface.opacity(0.95))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ShitterTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .padding(.bottom, 56)
    }
}
