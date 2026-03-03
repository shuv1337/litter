import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var serverManager: ServerManager
    @Environment(\.dismiss) private var dismiss
    @State private var showAccount = false

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
                    Section {
                        Button {
                            showAccount = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Account")
                                        .foregroundColor(.white)
                                        .font(ShitterFont.monospaced(.subheadline))
                                    Text(accountSummary)
                                        .font(ShitterFont.monospaced(.caption))
                                        .foregroundColor(ShitterTheme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(ShitterTheme.textMuted)
                                    .font(.caption)
                            }
                        }
                        .listRowBackground(ShitterTheme.surface.opacity(0.6))
                    } header: {
                        Text("Authentication")
                            .foregroundColor(ShitterTheme.textSecondary)
                    }

                    Section {
                        if connectedServers.isEmpty {
                            Text("No servers connected")
                                .font(ShitterFont.monospaced(.footnote))
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
                                            .font(ShitterFont.monospaced(.footnote))
                                            .foregroundColor(.white)
                                        Text(conn.isConnected ? "Connected" : "Disconnected")
                                            .font(ShitterFont.monospaced(.caption))
                                            .foregroundColor(conn.isConnected ? ShitterTheme.accent : ShitterTheme.textSecondary)
                                    }
                                    Spacer()
                                    Button("Remove") {
                                        serverManager.removeServer(id: conn.id)
                                    }
                                    .font(ShitterFont.monospaced(.caption))
                                    .foregroundColor(Color(hex: "#FF5555"))
                                }
                                .listRowBackground(ShitterTheme.surface.opacity(0.6))
                            }
                        }
                    } header: {
                        Text("Servers")
                            .foregroundColor(ShitterTheme.textSecondary)
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom Font")
                                .font(ShitterFont.monospaced(.subheadline))
                                .foregroundColor(.white)
                            Text("Using Berkeley Mono for app typography.")
                                .font(ShitterFont.monospaced(.caption))
                                .foregroundColor(ShitterTheme.textSecondary)
                        }
                        .listRowBackground(ShitterTheme.surface.opacity(0.6))
                    } header: {
                        Text("Typography")
                            .foregroundColor(ShitterTheme.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(ShitterTheme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAccount) {
            AccountView()
                .environmentObject(serverManager)
        }
    }

    private var accountSummary: String {
        let conn = serverManager.activeConnection ?? serverManager.connections.values.first(where: { $0.isConnected })
        guard let conn else { return "Connect first" }
        switch conn.authStatus {
        case .chatgpt(let email): return email.isEmpty ? "ChatGPT" : email
        case .apiKey: return "API Key"
        case .notLoggedIn: return "Not logged in"
        case .unknown: return conn.isConnected ? "Checking…" : "Connect first"
        }
    }
}
