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
    @State private var errorMsg: String?
    @State private var showOAuth = false

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
                        if let err = errorMsg {
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
        .sheet(isPresented: $showOAuth) {
            oauthSheet
        }
        .onChange(of: connection.oauthURL) { _, url in
            showOAuth = url != nil
        }
        .onChange(of: connection.loginCompleted) { _, completed in
            if completed == true {
                showOAuth = false
                connection.loginCompleted = false
            }
        }
    }

    private var currentAccountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CURRENT ACCOUNT")
                .font(ShitterFont.styled(.caption))
                .foregroundColor(ShitterTheme.textMuted)
                .padding(.horizontal, 20)

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
                        Task { await connection.logout() }
                    }
                    .font(ShitterFont.styled(.footnote))
                    .foregroundColor(ShitterTheme.danger)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .padding(.horizontal, 16)
        }
    }

    private var loginSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LOGIN")
                .font(ShitterFont.styled(.caption))
                .foregroundColor(ShitterTheme.textMuted)
                .padding(.horizontal, 20)

            Button {
                Task {
                    isWorking = true
                    errorMsg = nil
                    await connection.loginWithChatGPT()
                    isWorking = false
                }
            } label: {
                HStack {
                    if isWorking {
                        ProgressView().tint(ShitterTheme.textOnAccent).scaleEffect(0.8)
                    }
                    Image(systemName: "person.crop.circle.badge.checkmark")
                    Text("Login with ChatGPT")
                        .font(ShitterFont.styled(.subheadline))
                }
                .foregroundColor(ShitterTheme.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ShitterTheme.accent)
                .cornerRadius(10)
            }
            .padding(.horizontal, 16)
            .disabled(isWorking)

            Text("— or use an API key —")
                .font(ShitterFont.styled(.caption))
                .foregroundColor(ShitterTheme.textMuted)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                SecureField("sk-...", text: $apiKey)
                    .font(ShitterFont.styled(.subheadline))
                    .foregroundColor(ShitterTheme.textPrimary)
                    .padding(12)
                    .background(ShitterTheme.surface)
                    .cornerRadius(8)
                    .padding(.horizontal, 16)

                Button {
                    let key = apiKey.trimmingCharacters(in: .whitespaces)
                    guard !key.isEmpty else { return }
                    Task {
                        isWorking = true
                        errorMsg = nil
                        await connection.loginWithApiKey(key)
                        isWorking = false
                        if case .apiKey = connection.authStatus {
                            dismiss()
                        }
                    }
                } label: {
                    Text("Save API Key")
                        .font(ShitterFont.styled(.subheadline))
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
            }
        }
    }

    @ViewBuilder
    private var oauthSheet: some View {
        if let url = connection.oauthURL {
            NavigationStack {
                OAuthWebView(url: url, onCallbackIntercepted: { callbackURL in
                    connection.forwardOAuthCallback(callbackURL)
                }) {
                    Task { await connection.cancelLogin() }
                }
                .ignoresSafeArea()
                .navigationTitle("Login with ChatGPT")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            Task { await connection.cancelLogin() }
                            showOAuth = false
                        }
                        .foregroundColor(ShitterTheme.danger)
                    }
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
        case .chatgpt: return "ChatGPT account"
        case .apiKey: return "OpenAI API key"
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
                        .font(ShitterFont.styled(.subheadline))
                        .foregroundColor(ShitterTheme.textPrimary)
                    Text("Account settings are tied to the active server connection.")
                        .font(ShitterFont.styled(.caption))
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
