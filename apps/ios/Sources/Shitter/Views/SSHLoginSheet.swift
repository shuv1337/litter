import SwiftUI

struct SSHLoginSheet: View {
    let server: DiscoveredServer
    let onConnect: (ConnectionTarget, String?) -> Void
    private let autoLoadSavedCredentials: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var username: String
    @State private var password = ""
    @State private var useKey = false
    @State private var privateKey = ""
    @State private var passphrase = ""
    @State private var rememberCredentials = true
    @State private var hasSavedCredentials = false
    @State private var loadedSavedCredentials = false
    @State private var isConnecting = false
    @State private var errorMessage: String?

    init(
        server: DiscoveredServer,
        autoLoadSavedCredentials: Bool = true,
        initialUsername: String = "",
        onConnect: @escaping (ConnectionTarget, String?) -> Void
    ) {
        self.server = server
        self.onConnect = onConnect
        self.autoLoadSavedCredentials = autoLoadSavedCredentials
        _username = State(initialValue: initialUsername)
    }

    private var sshPort: Int {
        Int(server.resolvedSSHPort)
    }

    private var hostDisplay: String {
        if sshPort == 22 {
            return server.hostname
        }
        return "\(server.hostname):\(sshPort)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ShitterTheme.backgroundGradient.ignoresSafeArea()
                Form {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "terminal")
                                .foregroundColor(ShitterTheme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(server.name)
                                    .font(ShitterFont.styled(.subheadline))
                                    .foregroundColor(ShitterTheme.textPrimary)
                                Text(hostDisplay)
                                    .font(ShitterFont.styled(.caption))
                                    .foregroundColor(ShitterTheme.textSecondary)
                            }
                        }
                    }
                    .listRowBackground(ShitterTheme.surface.opacity(0.6))

                    Section {
                        TextField("username", text: $username)
                            .font(ShitterFont.styled(.footnote))
                            .foregroundColor(ShitterTheme.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    } header: {
                        Text("Username")
                            .foregroundColor(ShitterTheme.textSecondary)
                    }
                    .listRowBackground(ShitterTheme.surface.opacity(0.6))

                    Section {
                        Picker("Method", selection: $useKey) {
                            Text("Password").tag(false)
                            Text("SSH Key").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(ShitterTheme.surface.opacity(0.6))

                        if useKey {
                            TextEditor(text: $privateKey)
                                .font(ShitterFont.styled(.caption))
                                .foregroundColor(ShitterTheme.textPrimary)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 100)
                                .overlay(alignment: .topLeading) {
                                    if privateKey.isEmpty {
                                        Text("Paste private key here...")
                                            .font(ShitterFont.styled(.caption))
                                            .foregroundColor(ShitterTheme.textMuted)
                                            .padding(.top, 8)
                                            .padding(.leading, 4)
                                            .allowsHitTesting(false)
                                    }
                                }
                            SecureField("passphrase (optional)", text: $passphrase)
                                .font(ShitterFont.styled(.footnote))
                                .foregroundColor(ShitterTheme.textPrimary)
                        } else {
                            SecureField("password", text: $password)
                                .font(ShitterFont.styled(.footnote))
                                .foregroundColor(ShitterTheme.textPrimary)
                        }
                    } header: {
                        Text("Authentication")
                            .foregroundColor(ShitterTheme.textSecondary)
                    }
                    .listRowBackground(ShitterTheme.surface.opacity(0.6))

                    Section {
                        Toggle(isOn: $rememberCredentials) {
                            Text("Remember credentials on this device")
                                .font(ShitterFont.styled(.footnote))
                                .foregroundColor(ShitterTheme.textPrimary)
                        }
                        .tint(ShitterTheme.accent)

                        if hasSavedCredentials {
                            Button(role: .destructive) {
                                forgetSavedCredentials()
                            } label: {
                                Text("Forget saved credentials")
                                    .font(ShitterFont.styled(.footnote))
                            }
                        }
                    } header: {
                        Text("Saved Credentials")
                            .foregroundColor(ShitterTheme.textSecondary)
                    }
                    .listRowBackground(ShitterTheme.surface.opacity(0.6))

                    Section {
                        Button {
                            connect()
                        } label: {
                            HStack {
                                if isConnecting {
                                    ProgressView().tint(ShitterTheme.accent)
                                }
                                Text("Connect")
                                    .foregroundColor(ShitterTheme.accent)
                                    .font(ShitterFont.styled(.subheadline))
                            }
                        }
                        .disabled(isConnecting || username.isEmpty || (!useKey && password.isEmpty) || (useKey && privateKey.isEmpty))
                    }
                    .listRowBackground(ShitterTheme.surface.opacity(0.6))

                    if let err = errorMessage {
                        Section {
                            Text(err)
                                .foregroundColor(.red)
                                .font(ShitterFont.styled(.caption))
                        }
                        .listRowBackground(ShitterTheme.surface.opacity(0.6))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("SSH Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(ShitterTheme.accent)
                }
            }
        }
        .task {
            guard autoLoadSavedCredentials else { return }
            loadSavedCredentialsIfNeeded()
        }
    }

    private func connect() {
        let credentials: SSHCredentials
        if useKey {
            credentials = .key(
                username: username,
                privateKey: privateKey,
                passphrase: passphrase.isEmpty ? nil : passphrase
            )
        } else {
            credentials = .password(username: username, password: password)
        }
        isConnecting = true
        errorMessage = nil

        Task {
            do {
                let ssh = SSHSessionManager.shared
                try await ssh.connect(host: server.hostname, port: sshPort, credentials: credentials)
                let port = try await ssh.startRemoteServer()
                let detectedWakeMAC = await ssh.discoverWakeMACAddress()
                var remoteHost = server.hostname
                    .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                    .replacingOccurrences(of: "%25", with: "%")
                if !remoteHost.contains(":"), let pct = remoteHost.firstIndex(of: "%") {
                    remoteHost = String(remoteHost[..<pct])
                }
                let target: ConnectionTarget
                if server.sshPortForwardingEnabled {
                    let localPort = try await ssh.establishLocalPortForward(remotePort: port)
                    target = .remote(host: "127.0.0.1", port: localPort)
                } else {
                    target = .remote(host: remoteHost, port: port)
                }

                do {
                    if rememberCredentials {
                        try SSHCredentialStore.shared.save(
                            savedCredential(from: credentials),
                            host: server.hostname,
                            port: sshPort
                        )
                        hasSavedCredentials = true
                    } else {
                        try SSHCredentialStore.shared.delete(host: server.hostname, port: sshPort)
                        hasSavedCredentials = false
                    }
                } catch {
                    NSLog("[SSH_CREDENTIALS] keychain update failed: %@", error.localizedDescription)
                }

                clearSensitiveInput()
                isConnecting = false
                onConnect(target, detectedWakeMAC)
            } catch {
                isConnecting = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadSavedCredentialsIfNeeded() {
        guard !loadedSavedCredentials else { return }
        loadedSavedCredentials = true

        do {
            guard let saved = try SSHCredentialStore.shared.load(host: server.hostname, port: sshPort) else {
                hasSavedCredentials = false
                return
            }
            hasSavedCredentials = true
            rememberCredentials = true
            username = saved.username
            useKey = saved.method == .key
            if saved.method == .key {
                privateKey = saved.privateKey ?? ""
                passphrase = saved.passphrase ?? ""
                password = ""
            } else {
                password = saved.password ?? ""
                privateKey = ""
                passphrase = ""
            }
        } catch {
            NSLog("[SSH_CREDENTIALS] failed to load: %@", error.localizedDescription)
        }
    }

    private func forgetSavedCredentials() {
        do {
            try SSHCredentialStore.shared.delete(host: server.hostname, port: sshPort)
            hasSavedCredentials = false
            rememberCredentials = false
            clearSensitiveInput()
        } catch {
            NSLog("[SSH_CREDENTIALS] failed to delete: %@", error.localizedDescription)
        }
    }

    private func savedCredential(from credentials: SSHCredentials) -> SavedSSHCredential {
        switch credentials {
        case .password(let username, let password):
            return SavedSSHCredential(
                username: username,
                method: .password,
                password: password,
                privateKey: nil,
                passphrase: nil
            )
        case .key(let username, let privateKey, let passphrase):
            return SavedSSHCredential(
                username: username,
                method: .key,
                password: nil,
                privateKey: privateKey,
                passphrase: passphrase
            )
        }
    }

    private func clearSensitiveInput() {
        password = ""
        privateKey = ""
        passphrase = ""
    }
}

#if DEBUG
#Preview("SSH Login") {
    SSHLoginSheet(
        server: ShitterPreviewData.sampleSSHServer,
        autoLoadSavedCredentials: false,
        initialUsername: "builder"
    ) { _, _ in }
}
#endif
