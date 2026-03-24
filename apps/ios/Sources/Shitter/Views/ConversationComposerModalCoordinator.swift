import SwiftUI
import PhotosUI
import UIKit

struct ConversationComposerModalCoordinator<Content: View>: View {
    @Environment(AppState.self) private var appState

    let snapshot: ConversationComposerSnapshot
    let experimentalFeatures: [ExperimentalFeature]
    let experimentalFeaturesLoading: Bool
    let skills: [SkillMetadata]
    let skillsLoading: Bool
    @Binding var showAttachMenu: Bool
    @Binding var showPhotoPicker: Bool
    @Binding var showCamera: Bool
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var attachedImage: UIImage?
    @Binding var showModelSelector: Bool
    @Binding var showPermissionsSheet: Bool
    @Binding var showExperimentalSheet: Bool
    @Binding var showSkillsSheet: Bool
    @Binding var showRenamePrompt: Bool
    @Binding var renameCurrentThreadTitle: String
    @Binding var renameDraft: String
    @Binding var slashErrorMessage: String?
    @Binding var showMicPermissionAlert: Bool
    let onOpenSettings: () -> Void
    let onLoadSelectedPhoto: (PhotosPickerItem) async -> Void
    let onLoadExperimentalFeatures: () async -> Void
    let onIsExperimentalFeatureEnabled: (String, Bool) -> Bool
    let onSetExperimentalFeature: (String, Bool) async -> Void
    let onLoadSkills: (Bool, Bool) async -> Void
    let onRenameThread: (String) async -> Void
    @ViewBuilder let content: Content

    private var selectedModelBinding: Binding<String> {
        Binding(
            get: {
                let pending = appState.selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
                if !pending.isEmpty {
                    return pending
                }
                return snapshot.threadModel.trimmingCharacters(in: .whitespacesAndNewlines)
            },
            set: { appState.selectedModel = $0 }
        )
    }

    private var reasoningEffortBinding: Binding<String> {
        Binding(
            get: {
                let pending = appState.reasoningEffort.trimmingCharacters(in: .whitespacesAndNewlines)
                if !pending.isEmpty {
                    return pending
                }
                return snapshot.threadReasoningEffort?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            },
            set: { appState.reasoningEffort = $0 }
        )
    }

    var body: some View {
        content
            .sheet(isPresented: $showAttachMenu) {
                ConversationComposerAttachSheet(
                    onPickPhotoLibrary: {
                        showAttachMenu = false
                        showPhotoPicker = true
                    },
                    onTakePhoto: {
                        showAttachMenu = false
                        showCamera = true
                    }
                )
                .presentationDetents([.height(210)])
                .presentationDragIndicator(.visible)
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task { await onLoadSelectedPhoto(item) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: $attachedImage)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showModelSelector) {
                ModelSelectorSheet(
                    models: snapshot.availableModels,
                    selectedModel: selectedModelBinding,
                    reasoningEffort: reasoningEffortBinding
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showPermissionsSheet) {
                NavigationStack {
                    List {
                        ForEach(ComposerPermissionPreset.allCases) { preset in
                            Button {
                                appState.approvalPolicy = preset.approvalPolicy
                                appState.sandboxMode = preset.sandboxMode
                                showPermissionsSheet = false
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(preset.title)
                                            .foregroundColor(ShitterTheme.textPrimary)
                                            .shitterFont(.subheadline)
                                        Spacer()
                                        if preset.approvalPolicy == appState.approvalPolicy && preset.sandboxMode == appState.sandboxMode {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(ShitterTheme.accent)
                                        }
                                    }
                                    Text(preset.description)
                                        .foregroundColor(ShitterTheme.textSecondary)
                                        .shitterFont(.caption)
                                }
                            }
                            .listRowBackground(ShitterTheme.surface.opacity(0.6))
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(ShitterTheme.backgroundGradient.ignoresSafeArea())
                    .navigationTitle("Permissions")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showPermissionsSheet = false }
                                .foregroundColor(ShitterTheme.accent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showExperimentalSheet) {
                NavigationStack {
                    Group {
                        if experimentalFeaturesLoading {
                            ProgressView().tint(ShitterTheme.accent)
                        } else if experimentalFeatures.isEmpty {
                            Text("No experimental features available")
                                .shitterFont(.footnote)
                                .foregroundColor(ShitterTheme.textMuted)
                        } else {
                            List {
                                ForEach(Array(experimentalFeatures.enumerated()), id: \.element.id) { _, feature in
                                    HStack(alignment: .top, spacing: 10) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(feature.displayName ?? feature.name)
                                                .shitterFont(.subheadline)
                                                .foregroundColor(ShitterTheme.textPrimary)
                                            Text(feature.description ?? feature.stage)
                                                .shitterFont(.caption)
                                                .foregroundColor(ShitterTheme.textSecondary)
                                        }
                                        Spacer(minLength: 0)
                                        Toggle(
                                            "",
                                            isOn: Binding(
                                                get: { onIsExperimentalFeatureEnabled(feature.id, feature.enabled) },
                                                set: { value in
                                                    Task { await onSetExperimentalFeature(feature.name, value) }
                                                }
                                            )
                                        )
                                        .labelsHidden()
                                        .tint(ShitterTheme.accent)
                                    }
                                    .listRowBackground(ShitterTheme.surface.opacity(0.6))
                                }
                            }
                            .scrollContentBackground(.hidden)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ShitterTheme.backgroundGradient.ignoresSafeArea())
                    .navigationTitle("Experimental")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Reload") { Task { await onLoadExperimentalFeatures() } }
                                .foregroundColor(ShitterTheme.accent)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showExperimentalSheet = false }
                                .foregroundColor(ShitterTheme.accent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showSkillsSheet) {
                NavigationStack {
                    Group {
                        if skillsLoading {
                            ProgressView().tint(ShitterTheme.accent)
                        } else if skills.isEmpty {
                            Text("No skills available for this workspace")
                                .shitterFont(.footnote)
                                .foregroundColor(ShitterTheme.textMuted)
                        } else {
                            List {
                                ForEach(skills) { skill in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(skill.name)
                                                .shitterFont(.subheadline)
                                                .foregroundColor(ShitterTheme.textPrimary)
                                            Spacer()
                                            if skill.enabled {
                                                Text("enabled")
                                                    .shitterFont(.caption2)
                                                    .foregroundColor(ShitterTheme.accent)
                                            }
                                        }
                                        Text(skill.description)
                                            .shitterFont(.caption)
                                            .foregroundColor(ShitterTheme.textSecondary)
                                        Text(skill.path)
                                            .shitterFont(.caption2)
                                            .foregroundColor(ShitterTheme.textMuted)
                                    }
                                    .listRowBackground(ShitterTheme.surface.opacity(0.6))
                                }
                            }
                            .scrollContentBackground(.hidden)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ShitterTheme.backgroundGradient.ignoresSafeArea())
                    .navigationTitle("Skills")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Reload") { Task { await onLoadSkills(true, true) } }
                                .foregroundColor(ShitterTheme.accent)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showSkillsSheet = false }
                                .foregroundColor(ShitterTheme.accent)
                        }
                    }
                }
            }
            .alert("Rename Thread", isPresented: Binding(
                get: { showRenamePrompt },
                set: { isPresented in
                    showRenamePrompt = isPresented
                    if !isPresented {
                        renameCurrentThreadTitle = ""
                        renameDraft = ""
                    }
                }
            )) {
                TextField("New thread title", text: $renameDraft)
                Button("Cancel", role: .cancel) {
                    showRenamePrompt = false
                }
                Button("Rename") {
                    let nextName = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !nextName.isEmpty else { return }
                    Task { await onRenameThread(nextName) }
                }
            } message: {
                Text("Current thread title:\n\(renameCurrentThreadTitle)")
            }
            .alert("Slash Command Error", isPresented: Binding(
                get: { slashErrorMessage != nil },
                set: { if !$0 { slashErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { slashErrorMessage = nil }
            } message: {
                Text(slashErrorMessage ?? "Unknown error")
            }
            .alert("Microphone Access", isPresented: $showMicPermissionAlert) {
                Button("Open Settings", action: onOpenSettings)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Microphone permission is required for voice input. Enable it in Settings.")
            }
    }
}
