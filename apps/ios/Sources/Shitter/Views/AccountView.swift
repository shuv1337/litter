import SwiftUI

struct AccountView: View {
    @Environment(ServerManager.self) private var serverManager
    @Environment(\.dismiss) private var dismiss

    private var connection: ServerConnection? {
        serverManager.activeConnection ?? serverManager.connections.values.first(where: { $0.isConnected })
    }

    var body: some View {
        if let connection {
            AccountConnectionView(connection: connection, dismiss: dismiss)
        } else {
            AccountDisconnectedView(dismiss: dismiss)
        }
    }
}

private struct AccountConnectionView: View {
    let connection: ServerConnection
    let dismiss: DismissAction

    @State private var apiKey = ""
    @State private var isWorking = false

    private var authStatus: AuthStatus {
        connection.authStatus
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ShitterTheme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        currentAccountSection
                        Divider().background(ShitterTheme.surfaceLight)
                        loginSection
                        if let err = connection.lastAuthError {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(ShitterTheme.accent)
                }
            }
        }
    }

    private var currentAccountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CURRENT ACCOUNT")
                .shitterFont(.caption)
                .foregroundColor(ShitterTheme.textMuted)
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                Circle()
                    .fill(authColor)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(authTitle)
                        .shitterFont(.subheadline)
                        .foregroundColor(ShitterTheme.textPrimary)
                    if let sub = authSubtitle {
                        Text(sub)
                            .shitterFont(.caption)
                            .foregroundColor(ShitterTheme.textSecondary)
                    }
                }
                Spacer()
                if authStatus != .notLoggedIn && authStatus != .unknown {
                    Button("Logout") {
                        Task { await connection.logout() }
                    }
                    .shitterFont(.footnote)
                    .foregroundColor(ShitterTheme.danger)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .padding(.horizontal, 16)

            if connection.target == .local, connection.hasOpenAIApiKey {
                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .foregroundColor(Color(hex: "#00AAFF"))
                    Text("Realtime API key saved")
                        .shitterFont(.caption)
                        .foregroundColor(ShitterTheme.textSecondary)
                    Spacer()
                    Button("Delete") {
                        Task {
                            isWorking = true
                            await connection.clearOpenAIApiKey()
                            isWorking = false
                        }
                    }
                    .shitterFont(.caption)
                    .foregroundColor(ShitterTheme.danger)
                    .disabled(isWorking)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var loginSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LOGIN")
                .shitterFont(.caption)
                .foregroundColor(ShitterTheme.textMuted)
                .padding(.horizontal, 20)

            Button {
                Task {
                    isWorking = true
                    await connection.loginWithChatGPT()
                    isWorking = false
                }
            } label: {
                HStack {
                    if isWorking || connection.isChatGPTLoginInProgress {
                        ProgressView().tint(ShitterTheme.textOnAccent).scaleEffect(0.8)
                    }
                    Image(systemName: "person.crop.circle.badge.checkmark")
                    Text("Login with ChatGPT")
                        .shitterFont(.subheadline)
                }
                .foregroundColor(ShitterTheme.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ShitterTheme.accent)
                .cornerRadius(10)
            }
            .padding(.horizontal, 16)
            .disabled(isWorking || connection.isChatGPTLoginInProgress)

            if connection.target == .local {
                Text("— or save an API key for local realtime —")
                    .shitterFont(.caption)
                    .foregroundColor(ShitterTheme.textMuted)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    SecureField("sk-...", text: $apiKey)
                        .shitterFont(.subheadline)
                        .foregroundColor(ShitterTheme.textPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(ShitterTheme.surface)
                        .cornerRadius(8)
                        .padding(.horizontal, 16)

                    Button {
                        let key = apiKey.trimmingCharacters(in: .whitespaces)
                        guard !key.isEmpty else { return }
                        Task {
                            isWorking = true
                            await connection.saveOpenAIApiKey(key)
                            isWorking = false
                            if connection.lastAuthError == nil, connection.hasOpenAIApiKey {
                                apiKey = ""
                                dismiss()
                            }
                        }
                    } label: {
                        Text("Save API Key")
                            .shitterFont(.subheadline)
                            .foregroundColor(ShitterTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(ShitterTheme.accent.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 16)
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty || isWorking)

                    Text("If both are saved, Shitter will keep ChatGPT OAuth for normal Codex requests and use the API key for local realtime.")
                        .shitterFont(.caption)
                        .foregroundColor(ShitterTheme.textSecondary)
                        .padding(.horizontal, 20)
                }
            }
        }
    }

    private var authColor: Color {
        switch authStatus {
        case .chatgpt: return ShitterTheme.accent
        case .apiKey: return Color(hex: "#00AAFF")
        case .notLoggedIn, .unknown: return ShitterTheme.textMuted
        }
    }

    private var authTitle: String {
        switch authStatus {
        case .chatgpt(let email): return email.isEmpty ? "ChatGPT" : email
        case .apiKey: return "API Key"
        case .notLoggedIn: return "Not logged in"
        case .unknown: return "Checking…"
        }
    }

    private var authSubtitle: String? {
        switch authStatus {
        case .chatgpt:
            return connection.hasOpenAIApiKey
                ? "ChatGPT account with saved realtime API key"
                : "ChatGPT account"
        case .apiKey:
            return connection.hasOpenAIApiKey ? "OpenAI API key saved" : "OpenAI API key"
        default: return nil
        }
    }
}

private struct AccountDisconnectedView: View {
    let dismiss: DismissAction

    var body: some View {
        NavigationStack {
            ZStack {
                ShitterTheme.backgroundGradient.ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("Connect to a server first")
                        .shitterFont(.subheadline)
                        .foregroundColor(ShitterTheme.textPrimary)
                    Text("Account settings are tied to the active server connection.")
                        .shitterFont(.caption)
                        .foregroundColor(ShitterTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(ShitterTheme.accent)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Account") {
    ShitterPreviewScene(includeBackground: false) {
        AccountView()
    }
}
#endif
