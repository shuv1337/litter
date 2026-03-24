import SwiftUI

struct SettingsView: View {
    @Environment(ServerManager.self) private var serverManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("fontFamily") private var fontFamily = FontFamilyOption.mono.rawValue
    @AppStorage("collapseTurns") private var collapseTurns = false

    private var connection: ServerConnection? {
        serverManager.activeConnection ?? serverManager.connections.values.first(where: { $0.isConnected })
    }

    private var connectedServers: [ServerConnection] {
        HomeDashboardSupport.sortedConnectedServers(
            from: Array(serverManager.connections.values),
            activeServerId: serverManager.activeThreadKey?.serverId
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ShitterTheme.backgroundGradient.ignoresSafeArea()
                Form {
                    appearanceSection
                    fontSection
                    conversationSection
                    experimentalSection
                    accountSection
                    serversSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(ShitterTheme.accent)
                }
            }
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section {
            NavigationLink {
                AppearanceSettingsView()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "paintbrush")
                        .foregroundColor(ShitterTheme.accent)
                        .frame(width: 20)
                    Text("Appearance")
                        .shitterFont(.subheadline)
                        .foregroundColor(ShitterTheme.textPrimary)
                }
            }
            .listRowBackground(ShitterTheme.surface.opacity(0.6))
        } header: {
            Text("Theme")
                .foregroundColor(ShitterTheme.textSecondary)
        }
    }

    // MARK: - Conversation Section

    private var conversationSection: some View {
        Section {
            Toggle(isOn: $collapseTurns) {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.compress.vertical")
                        .foregroundColor(ShitterTheme.accent)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Collapse Turns")
                            .shitterFont(.subheadline)
                            .foregroundColor(ShitterTheme.textPrimary)
                        Text("Collapse previous turns into cards")
                            .shitterFont(.caption)
                            .foregroundColor(ShitterTheme.textSecondary)
                    }
                }
            }
            .tint(ShitterTheme.accent)
            .listRowBackground(ShitterTheme.surface.opacity(0.6))
        } header: {
            Text("Conversation")
                .foregroundColor(ShitterTheme.textSecondary)
        }
    }

    // MARK: - Font Section

    private var fontSection: some View {
        Section {
            ForEach(FontFamilyOption.allCases) { option in
                Button {
                    fontFamily = option.rawValue
                    ThemeManager.shared.syncFontPreference()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.displayName)
                                .shitterFont(.subheadline)
                                .foregroundColor(ShitterTheme.textPrimary)
                            Text("The quick brown fox")
                                .font(ShitterFont.sampleFont(family: option, size: 14))
                                .foregroundColor(ShitterTheme.textSecondary)
                        }
                        Spacer()
                        if fontFamily == option.rawValue {
                            Image(systemName: "checkmark")
                                .shitterFont(.subheadline, weight: .semibold)
                                .foregroundColor(ShitterTheme.accentStrong)
                        }
                    }
                }
                .listRowBackground(ShitterTheme.surface.opacity(0.6))
            }
        } header: {
            Text("Font")
                .foregroundColor(ShitterTheme.textSecondary)
        }
    }

    // MARK: - Experimental Section

    private var experimentalSection: some View {
        Section {
            NavigationLink {
                ExperimentalFeaturesView()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "flask")
                        .foregroundColor(ShitterTheme.accent)
                        .frame(width: 20)
                    Text("Experimental Features")
                        .shitterFont(.subheadline)
                        .foregroundColor(ShitterTheme.textPrimary)
                }
            }
            .listRowBackground(ShitterTheme.surface.opacity(0.6))
        } header: {
            Text("Experimental")
                .foregroundColor(ShitterTheme.textSecondary)
        }
    }

    // MARK: - Account Section (inline, no nested sheet)

    private var accountSection: some View {
        Group {
            if let connection {
                SettingsConnectionAccountSection(connection: connection)
            } else {
                SettingsDisconnectedAccountSection()
            }
        }
    }

    // MARK: - Servers Section

    private var serversSection: some View {
        Section {
            if connectedServers.isEmpty {
                Text("No servers connected")
                    .shitterFont(.footnote)
                    .foregroundColor(ShitterTheme.textMuted)
                    .listRowBackground(ShitterTheme.surface.opacity(0.6))
            } else {
                ForEach(connectedServers, id: \.id) { conn in
                    HStack {
                        Image(systemName: serverIconName(for: conn.server.source))
                            .foregroundColor(ShitterTheme.accent)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(conn.server.name)
                                .shitterFont(.footnote)
                                .foregroundColor(ShitterTheme.textPrimary)
                            Text(conn.connectionHealth.settingsLabel)
                                .shitterFont(.caption)
                                .foregroundColor(conn.connectionHealth.settingsColor)
                        }
                        Spacer()
                        Button("Remove") {
                            serverManager.removeServer(id: conn.id)
                        }
                        .shitterFont(.caption)
                        .foregroundColor(ShitterTheme.danger)
                    }
                    .listRowBackground(ShitterTheme.surface.opacity(0.6))
                }
            }
        } header: {
            Text("Servers")
                .foregroundColor(ShitterTheme.textSecondary)
        }
    }

}

private struct SettingsConnectionAccountSection: View {
    let connection: ServerConnection
    @State private var apiKey = ""
    @State private var isAuthWorking = false

    private var authStatus: AuthStatus {
        connection.authStatus
    }

    var body: some View {
        Section {
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
                    .shitterFont(.caption)
                    .foregroundColor(ShitterTheme.danger)
                }
            }
            .listRowBackground(ShitterTheme.surface.opacity(0.6))

            if connection.target == .local, connection.hasOpenAIApiKey {
                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .foregroundColor(Color(hex: "#00AAFF"))
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Realtime API Key Saved")
                            .shitterFont(.subheadline)
                            .foregroundColor(ShitterTheme.textPrimary)
                        Text("Realtime can use the saved OpenAI API key while keeping your current account auth.")
                            .shitterFont(.caption)
                            .foregroundColor(ShitterTheme.textSecondary)
                    }
                    Spacer()
                    Button("Delete") {
                        Task {
                            isAuthWorking = true
                            await connection.clearOpenAIApiKey()
                            isAuthWorking = false
                        }
                    }
                    .shitterFont(.caption)
                    .foregroundColor(ShitterTheme.danger)
                    .disabled(isAuthWorking)
                }
                .listRowBackground(ShitterTheme.surface.opacity(0.6))
            }

            if case .notLoggedIn = authStatus {
                Button {
                    Task {
                        isAuthWorking = true
                        await connection.loginWithChatGPT()
                        isAuthWorking = false
                    }
                } label: {
                    HStack {
                        if isAuthWorking || connection.isChatGPTLoginInProgress {
                            ProgressView().tint(ShitterTheme.textPrimary).scaleEffect(0.8)
                        }
                        Image(systemName: "person.crop.circle.badge.checkmark")
                        Text("Login with ChatGPT")
                            .shitterFont(.subheadline)
                    }
                    .foregroundColor(ShitterTheme.accent)
                }
                .disabled(isAuthWorking || connection.isChatGPTLoginInProgress)
                .listRowBackground(ShitterTheme.surface.opacity(0.6))
            }

            if connection.target == .local, authStatus == .notLoggedIn || authStatus.isChatGPT {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        if authStatus.isChatGPT {
                            Text(connection.hasOpenAIApiKey ? "Update API key for local realtime" : "Save API key for local realtime")
                                .shitterFont(.caption)
                                .foregroundColor(ShitterTheme.textSecondary)
                        }
                        SecureField("sk-...", text: $apiKey)
                            .shitterFont(.footnote)
                            .foregroundColor(ShitterTheme.textPrimary)
                            .textInputAutocapitalization(.never)
                    }
                    Button("Save") {
                        let key = apiKey.trimmingCharacters(in: .whitespaces)
                        guard !key.isEmpty else { return }
                        Task {
                            isAuthWorking = true
                            await connection.saveOpenAIApiKey(key)
                            isAuthWorking = false
                        }
                    }
                    .shitterFont(.caption)
                    .foregroundColor(ShitterTheme.accent)
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty || isAuthWorking)
                }
                .listRowBackground(ShitterTheme.surface.opacity(0.6))
            }

            if let authError = connection.lastAuthError {
                Text(authError)
                    .shitterFont(.caption)
                    .foregroundColor(ShitterTheme.danger)
                    .listRowBackground(ShitterTheme.surface.opacity(0.6))
            }
        } header: {
            Text("Account")
                .foregroundColor(ShitterTheme.textSecondary)
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

private extension AuthStatus {
    var isChatGPT: Bool {
        if case .chatgpt = self {
            return true
        }
        return false
    }
}

private struct SettingsDisconnectedAccountSection: View {
    var body: some View {
        Section {
            Text("Connect to a server first")
                .shitterFont(.caption)
                .foregroundColor(ShitterTheme.textMuted)
                .listRowBackground(ShitterTheme.surface.opacity(0.6))
        } header: {
            Text("Account")
                .foregroundColor(ShitterTheme.textSecondary)
        }
    }
}

#if DEBUG
#Preview("Settings") {
    ShitterPreviewScene(includeBackground: false) {
        SettingsView()
    }
}
#endif
