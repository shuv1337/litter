import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var serverManager: ServerManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("fontFamily") private var fontFamily = FontFamilyOption.mono.rawValue
    @State private var apiKey = ""
    @State private var isAuthWorking = false
    @State private var authError: String?
    @State private var showOAuth = false

    private var conn: ServerConnection? {
        serverManager.activeConnection ?? serverManager.connections.values.first(where: { $0.isConnected })
    }

    private var authStatus: AuthStatus {
        conn?.authStatus ?? .unknown
    }

    private var connectedServers: [ServerConnection] {
        serverManager.connections.values
            .filter { $0.isConnected }
            .sorted { lhs, rhs in
                lhs.server.name.localizedCaseInsensitiveCompare(rhs.server.name) == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ShitterTheme.backgroundGradient.ignoresSafeArea()
                Form {
                    fontSection
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
        .sheet(isPresented: $showOAuth) {
            oauthSheet
        }
        .onChange(of: conn?.oauthURL) { _, url in
            showOAuth = url != nil
        }
        .onChange(of: conn?.loginCompleted) { _, completed in
            if completed == true {
                showOAuth = false
                conn?.loginCompleted = false
            }
        }
    }

    // MARK: - Font Section

    private var fontSection: some View {
        Section {
            ForEach(FontFamilyOption.allCases) { option in
                Button {
                    fontFamily = option.rawValue
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.displayName)
                                .font(ShitterFont.styled(.subheadline))
                                .foregroundColor(ShitterTheme.textPrimary)
                            Text("The quick brown fox")
                                .font(ShitterFont.sampleFont(family: option, size: 14))
                                .foregroundColor(ShitterTheme.textSecondary)
                        }
                        Spacer()
                        if fontFamily == option.rawValue {
                            Image(systemName: "checkmark")
                                .font(.system(.subheadline, weight: .semibold))
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

    // MARK: - Account Section (inline, no nested sheet)

    private var accountSection: some View {
        Section {
            // Current status
            HStack(spacing: 12) {
                Circle()
                    .fill(authColor)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(authTitle)
                        .font(ShitterFont.styled(.subheadline))
                        .foregroundColor(ShitterTheme.textPrimary)
                    if let sub = authSubtitle {
                        Text(sub)
                            .font(ShitterFont.styled(.caption))
                            .foregroundColor(ShitterTheme.textSecondary)
                    }
                }
                Spacer()
                if authStatus != .notLoggedIn && authStatus != .unknown {
                    Button("Logout") {
                        Task { await conn?.logout() }
                    }
                    .font(ShitterFont.styled(.caption))
                    .foregroundColor(ShitterTheme.danger)
                }
            }
            .listRowBackground(ShitterTheme.surface.opacity(0.6))

            // Login actions
            if case .notLoggedIn = authStatus {
                Button {
                    Task {
                        isAuthWorking = true
                        authError = nil
                        await conn?.loginWithChatGPT()
                        isAuthWorking = false
                    }
                } label: {
                    HStack {
                        if isAuthWorking {
                            ProgressView().tint(ShitterTheme.textPrimary).scaleEffect(0.8)
                        }
                        Image(systemName: "person.crop.circle.badge.checkmark")
                        Text("Login with ChatGPT")
                            .font(ShitterFont.styled(.subheadline))
                    }
                    .foregroundColor(ShitterTheme.accent)
                }
                .disabled(isAuthWorking)
                .listRowBackground(ShitterTheme.surface.opacity(0.6))

                HStack(spacing: 8) {
                    SecureField("sk-...", text: $apiKey)
                        .font(ShitterFont.styled(.footnote))
                        .foregroundColor(ShitterTheme.textPrimary)
                        .textInputAutocapitalization(.never)
                    Button("Save") {
                        let key = apiKey.trimmingCharacters(in: .whitespaces)
                        guard !key.isEmpty else { return }
                        Task {
                            isAuthWorking = true
                            authError = nil
                            await conn?.loginWithApiKey(key)
                            isAuthWorking = false
                        }
                    }
                    .font(ShitterFont.styled(.caption))
                    .foregroundColor(ShitterTheme.accent)
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty || isAuthWorking)
                }
                .listRowBackground(ShitterTheme.surface.opacity(0.6))
            }

            if case .unknown = authStatus, conn == nil {
                Text("Connect to a server first")
                    .font(ShitterFont.styled(.caption))
                    .foregroundColor(ShitterTheme.textMuted)
                    .listRowBackground(ShitterTheme.surface.opacity(0.6))
            }

            if let err = authError {
                Text(err)
                    .font(ShitterFont.styled(.caption))
                    .foregroundColor(ShitterTheme.danger)
                    .listRowBackground(ShitterTheme.surface.opacity(0.6))
            }
        } header: {
            Text("Account")
                .foregroundColor(ShitterTheme.textSecondary)
        }
    }

    // MARK: - Servers Section

    private var serversSection: some View {
        Section {
            if connectedServers.isEmpty {
                Text("No servers connected")
                    .font(ShitterFont.styled(.footnote))
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
                                .font(ShitterFont.styled(.footnote))
                                .foregroundColor(ShitterTheme.textPrimary)
                            Text(conn.isConnected ? "Connected" : "Disconnected")
                                .font(ShitterFont.styled(.caption))
                                .foregroundColor(conn.isConnected ? ShitterTheme.accent : ShitterTheme.textSecondary)
                        }
                        Spacer()
                        Button("Remove") {
                            serverManager.removeServer(id: conn.id)
                        }
                        .font(ShitterFont.styled(.caption))
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

    // MARK: - OAuth Sheet

    @ViewBuilder
    private var oauthSheet: some View {
        if let url = conn?.oauthURL {
            NavigationStack {
                OAuthWebView(url: url, onCallbackIntercepted: { callbackURL in
                    conn?.forwardOAuthCallback(callbackURL)
                }) {
                    Task { await conn?.cancelLogin() }
                }
                .ignoresSafeArea()
                .navigationTitle("Login with ChatGPT")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            Task { await conn?.cancelLogin() }
                            showOAuth = false
                        }
                        .foregroundColor(ShitterTheme.danger)
                    }
                }
            }
        }
    }

    // MARK: - Auth Helpers

    private var authColor: Color {
        switch authStatus {
        case .chatgpt: return ShitterTheme.accent
        case .apiKey:  return Color(hex: "#00AAFF")
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
        case .chatgpt: return "ChatGPT account"
        case .apiKey: return "OpenAI API key"
        default: return nil
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
