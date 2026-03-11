import SwiftUI
import Network

struct DiscoveryView: View {
    var onServerSelected: ((DiscoveredServer) -> Void)?
    @EnvironmentObject var serverManager: ServerManager
    @StateObject private var discovery: NetworkDiscovery
    @State private var sshServer: DiscoveredServer?
    @State private var pendingSSHServer: DiscoveredServer?
    @State private var showManualEntry = false
    @State private var manualConnectionMode: ManualConnectionMode = .ssh
    @State private var manualHost = ""
    @State private var manualCodexPort = "8390"
    @State private var manualSSHPort = "22"
    @State private var manualWakeMAC = ""
    @State private var manualUseSSHPortForward = true
    @State private var autoSSHStarted = false
    @State private var connectingServer: DiscoveredServer?
    @State private var wakingServer: DiscoveredServer?
    @State private var connectError: String?
    @State private var showSettings = false
    private let autoStartDiscovery: Bool
    private let initialServers: [DiscoveredServer]

    init(
        onServerSelected: ((DiscoveredServer) -> Void)? = nil,
        discovery: NetworkDiscovery? = nil,
        autoStartDiscovery: Bool = true,
        initialServers: [DiscoveredServer] = []
    ) {
        self.onServerSelected = onServerSelected
        _discovery = StateObject(wrappedValue: discovery ?? NetworkDiscovery())
        self.autoStartDiscovery = autoStartDiscovery
        self.initialServers = initialServers
    }

    private var localServers: [DiscoveredServer] {
        discovery.servers.filter { $0.source == .local }
    }

    private var networkServers: [DiscoveredServer] {
        let discovered = discovery.servers.filter { $0.source != .local }
        let saved = serverManager.loadSavedServers()
            .map { $0.toDiscoveredServer() }
            .filter { $0.source != .local }
        return mergeServers(discovered + saved)
    }

    private func mergeServers(_ candidates: [DiscoveredServer]) -> [DiscoveredServer] {
        var merged: [String: DiscoveredServer] = [:]

        func sourceRank(_ source: ServerSource) -> Int {
            switch source {
            case .bonjour: return 0
            case .tailscale: return 1
            case .ssh: return 2
            case .manual: return 3
            case .local: return 4
            }
        }

        for candidate in candidates {
            let key = candidate.hostname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let mergeKey = key.isEmpty ? candidate.id : key
            if let existing = merged[mergeKey] {
                let candidateWithWakeMAC = DiscoveredServer(
                    id: candidate.id,
                    name: candidate.name,
                    hostname: candidate.hostname,
                    port: candidate.port,
                    source: candidate.source,
                    hasCodexServer: candidate.hasCodexServer,
                    wakeMAC: candidate.wakeMAC ?? existing.wakeMAC,
                    sshPortForwardingEnabled: candidate.sshPortForwardingEnabled || existing.sshPortForwardingEnabled
                )
                let betterSource = sourceRank(candidate.source) < sourceRank(existing.source)
                let hasCodexUpgrade = candidate.hasCodexServer && !existing.hasCodexServer
                let betterCodexPort = candidate.hasCodexServer && existing.hasCodexServer && candidate.port != existing.port
                let betterName = existing.name == existing.hostname && candidate.name != candidate.hostname
                if betterSource || hasCodexUpgrade || betterCodexPort || betterName {
                    merged[mergeKey] = candidateWithWakeMAC
                } else if existing.wakeMAC == nil, candidateWithWakeMAC.wakeMAC != nil {
                    merged[mergeKey] = DiscoveredServer(
                        id: existing.id,
                        name: existing.name,
                        hostname: existing.hostname,
                        port: existing.port,
                        source: existing.source,
                        hasCodexServer: existing.hasCodexServer,
                        wakeMAC: candidateWithWakeMAC.wakeMAC,
                        sshPortForwardingEnabled: existing.sshPortForwardingEnabled || candidateWithWakeMAC.sshPortForwardingEnabled
                    )
                }
            } else {
                merged[mergeKey] = candidate
            }
        }

        return Array(merged.values).sorted { lhs, rhs in
            let lhsRank = sourceRank(lhs.source)
            let rhsRank = sourceRank(rhs.source)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func applyInitialServersIfNeeded() {
        guard !initialServers.isEmpty, discovery.servers.isEmpty else { return }
        discovery.servers = initialServers
        discovery.isScanning = false
    }

    private func refreshDiscovery() {
        guard autoStartDiscovery else {
            applyInitialServersIfNeeded()
            return
        }
        discovery.startScanning()
    }

    private func handleAppear() {
        refreshDiscovery()
        guard autoStartDiscovery else { return }
        maybeStartSimulatorAutoSSH()
    }

    private func handleDisappear() {
        guard autoStartDiscovery else { return }
        discovery.stopScanning()
    }

    var body: some View {
        ZStack {
            ShitterTheme.backgroundGradient.ignoresSafeArea()
            List {
                serversSection
                manualSection
            }
            .scrollContentBackground(.hidden)
            .refreshable { refreshDiscovery() }
            .accessibilityIdentifier("discovery.list")
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(ShitterTheme.textSecondary)
                }
            }
            ToolbarItem(placement: .principal) {
                BrandLogo(size: 44)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    refreshDiscovery()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(ShitterTheme.accent)
                }
                .accessibilityIdentifier("discovery.refreshButton")
                .disabled(discovery.isScanning)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(serverManager)
        }
        .onAppear { handleAppear() }
        .onDisappear { handleDisappear() }
        .sheet(item: $sshServer) { server in
            SSHLoginSheet(server: server) { target, detectedWakeMAC in
                sshServer = nil
                switch target {
                case .remote(let host, let port):
                    let resolved = DiscoveredServer(
                        id: "\(server.id)-remote-\(port)",
                        name: server.name,
                        hostname: host,
                        port: port,
                        source: server.source,
                        hasCodexServer: true,
                        wakeMAC: detectedWakeMAC ?? server.wakeMAC,
                        sshPortForwardingEnabled: server.sshPortForwardingEnabled
                    )
                    if server.sshPortForwardingEnabled {
                        let bootstrap = DiscoveredServer(
                            id: server.id,
                            name: server.name,
                            hostname: server.hostname,
                            port: server.port,
                            source: server.source,
                            hasCodexServer: false,
                            wakeMAC: detectedWakeMAC ?? server.wakeMAC,
                            sshPortForwardingEnabled: true
                        )
                        Task { await connectToServer(bootstrap, targetOverride: target) }
                    } else {
                        Task { await connectToServer(resolved, targetOverride: target) }
                    }
                default:
                    let enriched = DiscoveredServer(
                        id: server.id,
                        name: server.name,
                        hostname: server.hostname,
                        port: server.port,
                        source: server.source,
                        hasCodexServer: server.hasCodexServer,
                        wakeMAC: detectedWakeMAC ?? server.wakeMAC,
                        sshPortForwardingEnabled: server.sshPortForwardingEnabled
                    )
                    Task { await connectToServer(enriched, targetOverride: target) }
                }
            }
        }
        .sheet(isPresented: $showManualEntry) {
            manualEntrySheet
        }
        .onChange(of: showManualEntry) { _, isPresented in
            guard !isPresented, let pendingSSHServer else { return }
            self.pendingSSHServer = nil
            self.sshServer = pendingSSHServer
        }
        .alert("Connection Failed", isPresented: showConnectError, actions: {
            Button("OK") { connectError = nil }
        }, message: {
            Text(connectError ?? "Unable to connect.")
        })
    }

    // MARK: - Sections

    private var allServers: [DiscoveredServer] {
        localServers + networkServers
    }

    private var serversSection: some View {
        Section {
            if allServers.isEmpty {
                if discovery.isScanning {
                    HStack {
                        ProgressView().tint(ShitterTheme.textMuted).scaleEffect(0.7)
                        Text("Scanning...")
                            .font(ShitterFont.styled(.footnote))
                            .foregroundColor(ShitterTheme.textMuted)
                    }
                    .listRowBackground(ShitterTheme.surface.opacity(0.6))
                } else {
                    Text("No servers found")
                        .font(ShitterFont.styled(.footnote))
                        .foregroundColor(ShitterTheme.textMuted)
                        .listRowBackground(ShitterTheme.surface.opacity(0.6))
                }
            } else {
                ForEach(allServers) { server in
                    serverRow(server)
                }
            }
        } header: {
            HStack(spacing: 8) {
                Text("Servers")
                    .foregroundColor(ShitterTheme.textSecondary)
                Spacer()
                if discovery.isScanning {
                    ProgressView()
                        .tint(ShitterTheme.textMuted)
                        .scaleEffect(0.65)
                }
            }
        }
        .listRowBackground(ShitterTheme.surface.opacity(0.6))
    }

    private var manualSection: some View {
        Section {
                Button {
                    manualConnectionMode = .ssh
                    showManualEntry = true
                } label: {
                HStack {
                    Image(systemName: "plus.circle")
                        .foregroundColor(ShitterTheme.accent)
                    Text("Add Server")
                        .font(ShitterFont.styled(.subheadline))
                        .foregroundColor(ShitterTheme.accent)
                }
            }
            .accessibilityIdentifier("discovery.addServerButton")
            .listRowBackground(ShitterTheme.surface.opacity(0.6))
        }
    }

    // MARK: - Row

    private func serverRow(_ server: DiscoveredServer) -> some View {
        let rowIdentifier = serverRowAccessibilityIdentifier(for: server)
        return Button {
            handleTap(server)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: serverIconName(for: server.source))
                    .foregroundColor(server.hasCodexServer ? ShitterTheme.accent : ShitterTheme.textSecondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name)
                        .font(ShitterFont.styled(.subheadline))
                        .foregroundColor(ShitterTheme.textPrimary)
                    Text(serverSubtitle(server))
                        .font(ShitterFont.styled(.caption))
                        .foregroundColor(ShitterTheme.textSecondary)
                }
                Spacer()
                if serverManager.connections[server.id]?.isConnected == true {
                    Text("connected")
                        .font(ShitterFont.styled(.caption2))
                        .foregroundColor(ShitterTheme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ShitterTheme.accent.opacity(0.15))
                        .cornerRadius(4)
                } else if connectingServer?.id == server.id {
                    ProgressView().controlSize(.small).tint(ShitterTheme.accent)
                } else if wakingServer?.id == server.id {
                    ProgressView().controlSize(.small).tint(ShitterTheme.accent)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(ShitterTheme.textMuted)
                        .font(.caption)
                }
            }
        }
        .accessibilityIdentifier(rowIdentifier)
        .disabled(connectingServer != nil || wakingServer != nil)
    }

    private func serverRowAccessibilityIdentifier(for server: DiscoveredServer) -> String {
        let kind = server.hasCodexServer ? "codex" : "ssh"
        let host = server.hostname
            .lowercased()
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return "discovery.server.\(kind).\(host)"
    }

    private func serverSubtitle(_ server: DiscoveredServer) -> String {
        if server.source == .local { return "In-process server" }
        var parts = [server.hostname]
        if let port = server.port { parts.append(":\(port)") }
        if server.hasCodexServer {
            parts.append(" - codex running")
        } else {
            parts.append(" - SSH (\(server.source.rawString))")
        }
        return parts.joined()
    }

    // MARK: - Actions

    private func handleTap(_ server: DiscoveredServer) {
        Task { await handleTapAsync(server) }
    }

    private func navigateAfterConnect(_ server: DiscoveredServer) {
        if serverManager.connections[server.id]?.authStatus == .notLoggedIn {
            showSettings = true
        } else {
            onServerSelected?(server)
        }
    }

    @MainActor
    private func handleTapAsync(_ server: DiscoveredServer) async {
        if serverManager.connections[server.id]?.isConnected == true {
            navigateAfterConnect(server)
            return
        }

        let prepared = await prepareServerForSelection(server)
        if prepared.server.hasCodexServer {
            await connectToServer(prepared.server)
        } else if prepared.canAttemptSSH {
            sshServer = prepared.server
        } else {
            connectError = "Server did not respond after wake attempt. Enable Wake for network access on the Mac."
        }
    }

    private func prepareServerForSelection(_ server: DiscoveredServer) async -> (server: DiscoveredServer, canAttemptSSH: Bool) {
        guard server.source != .local else {
            return (server, true)
        }

        wakingServer = server
        defer { wakingServer = nil }

        let wakeResult = await waitForWakeSignal(
            host: server.hostname,
            preferredCodexPort: server.hasCodexServer ? server.port : nil,
            timeout: server.hasCodexServer ? 12.0 : 18.0,
            wakeMAC: server.wakeMAC
        )

        switch wakeResult {
        case .codex(let port):
            return (
                DiscoveredServer(
                    id: server.id,
                    name: server.name,
                    hostname: server.hostname,
                    port: port,
                    source: server.source,
                    hasCodexServer: true,
                    wakeMAC: server.wakeMAC,
                    sshPortForwardingEnabled: server.sshPortForwardingEnabled
                ),
                true
            )
        case .ssh:
            return (
                DiscoveredServer(
                    id: server.id,
                    name: server.name,
                    hostname: server.hostname,
                    port: server.port,
                    source: server.source,
                    hasCodexServer: false,
                    wakeMAC: server.wakeMAC,
                    sshPortForwardingEnabled: server.sshPortForwardingEnabled
                ),
                true
            )
        case .none:
            // Don't hard-block when wake probing is inconclusive; continue with
            // normal connect/SSH flow so users can still attempt recovery.
            return (server, true)
        }
    }

    private enum WakeSignalResult {
        case codex(UInt16)
        case ssh
        case none
    }

    private func waitForWakeSignal(
        host: String,
        preferredCodexPort: UInt16?,
        timeout: TimeInterval,
        wakeMAC: String?
    ) async -> WakeSignalResult {
        let codexPorts = orderedCodexPorts(preferred: preferredCodexPort)
        let deadline = Date().addingTimeInterval(max(timeout, 0.5))
        var lastWakePacketAt = Date.distantPast

        while Date() < deadline {
            if let wakeMAC, Date().timeIntervalSince(lastWakePacketAt) >= 2.0 {
                sendWakeMagicPacket(to: wakeMAC, hostHint: host)
                lastWakePacketAt = Date()
            }

            for port in codexPorts {
                if await isPortOpen(host: host, port: port, timeout: 0.7) {
                    return .codex(port)
                }
            }

            if await isPortOpen(host: host, port: 22, timeout: 0.7) {
                return .ssh
            }

            try? await Task.sleep(for: .milliseconds(350))
        }

        return .none
    }

    private func orderedCodexPorts(preferred: UInt16?) -> [UInt16] {
        var ports = [UInt16]()
        if let preferred {
            ports.append(preferred)
        }
        ports.append(contentsOf: [8390, 4222])

        var seen = Set<UInt16>()
        return ports.filter { seen.insert($0).inserted }
    }

    private func sendWakeMagicPacket(to wakeMAC: String, hostHint: String) {
        guard let macBytes = macBytes(from: wakeMAC) else { return }
        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 {
            packet.append(contentsOf: macBytes)
        }

        let targets = wakeBroadcastTargets(for: hostHint)
        for target in targets {
            sendBroadcastUDP(packet: packet, host: target, port: 9)
            sendBroadcastUDP(packet: packet, host: target, port: 7)
        }
    }

    private func macBytes(from normalizedMAC: String) -> [UInt8]? {
        let compact = normalizedMAC.replacingOccurrences(of: ":", with: "")
        guard compact.count == 12 else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(6)
        var index = compact.startIndex
        for _ in 0..<6 {
            let next = compact.index(index, offsetBy: 2)
            let chunk = compact[index..<next]
            guard let byte = UInt8(chunk, radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return bytes
    }

    private func wakeBroadcastTargets(for host: String) -> [String] {
        var targets = ["255.255.255.255"]
        let parts = host.split(separator: ".")
        if parts.count == 4,
           let _ = Int(parts[0]),
           let _ = Int(parts[1]),
           let _ = Int(parts[2]),
           let _ = Int(parts[3]) {
            targets.append("\(parts[0]).\(parts[1]).\(parts[2]).255")
        }
        return Array(Set(targets))
    }

    private func sendBroadcastUDP(packet: Data, host: String, port: UInt16) {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return }
        defer { close(fd) }

        var enabled: Int32 = 1
        withUnsafePointer(to: &enabled) { enabledPtr in
            _ = setsockopt(fd, SOL_SOCKET, SO_BROADCAST, enabledPtr, socklen_t(MemoryLayout<Int32>.size))
        }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = CFSwapInt16HostToBig(port)
        host.withCString { cString in
            _ = inet_pton(AF_INET, cString, &addr.sin_addr)
        }

        packet.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            var destination = addr
            withUnsafePointer(to: &destination) { destinationPtr in
                destinationPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    _ = sendto(fd, base, packet.count, 0, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }

    private func isPortOpen(host: String, port: UInt16, timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
                continuation.resume(returning: false)
                return
            }

            let connection = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: .tcp)
            let gate = WakeProbeResumeGate()

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if gate.markResumed() {
                        connection.stateUpdateHandler = nil
                        connection.cancel()
                        continuation.resume(returning: true)
                    }
                case .failed, .cancelled:
                    if gate.markResumed() {
                        connection.stateUpdateHandler = nil
                        connection.cancel()
                        continuation.resume(returning: false)
                    }
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .utility))

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                if gate.markResumed() {
                    connection.stateUpdateHandler = nil
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }

    private func connectToServer(_ server: DiscoveredServer, targetOverride: ConnectionTarget? = nil) async {
        guard connectingServer == nil else { return }
        connectingServer = server
        connectError = nil

        guard let target = targetOverride ?? server.connectionTarget else {
            connectError = "Server requires SSH login"
            connectingServer = nil
            return
        }

        await serverManager.addServer(server, target: target)

        connectingServer = nil
        if serverManager.connections[server.id]?.isConnected == true {
            navigateAfterConnect(server)
        } else {
            let phase = serverManager.connections[server.id]?.connectionPhase
            connectError = phase?.isEmpty == false ? phase : "Failed to connect"
        }
    }

    // MARK: - Manual Entry

    private var manualEntrySheet: some View {
        NavigationStack {
            ZStack {
                ShitterTheme.backgroundGradient.ignoresSafeArea()
                Form {
                    Section {
                        Picker("Connection Type", selection: $manualConnectionMode) {
                            ForEach(ManualConnectionMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Connection")
                            .foregroundColor(ShitterTheme.textSecondary)
                    }
                    .listRowBackground(ShitterTheme.surface.opacity(0.6))

                    Section {
                        TextField("hostname or IP", text: $manualHost)
                            .font(ShitterFont.styled(.footnote))
                            .foregroundColor(ShitterTheme.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        TextField(manualConnectionMode.portPlaceholder, text: portBinding(for: manualConnectionMode))
                            .font(ShitterFont.styled(.footnote))
                            .foregroundColor(ShitterTheme.textPrimary)
                            .keyboardType(.numberPad)
                        if manualConnectionMode == .ssh {
                            Toggle(isOn: $manualUseSSHPortForward) {
                                Text("Use SSH port forward")
                                    .font(ShitterFont.styled(.footnote))
                                    .foregroundColor(ShitterTheme.textPrimary)
                            }
                            .tint(ShitterTheme.accent)
                        }
                        TextField("wake MAC (optional)", text: $manualWakeMAC)
                            .font(ShitterFont.styled(.footnote))
                            .foregroundColor(ShitterTheme.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    } header: {
                        Text(manualConnectionMode.formHeader)
                            .foregroundColor(ShitterTheme.textSecondary)
                    }
                    .listRowBackground(ShitterTheme.surface.opacity(0.6))

                    Section {
                        Button(manualConnectionMode.primaryButtonTitle) {
                            submitManualEntry()
                        }
                        .foregroundColor(ShitterTheme.accent)
                        .font(ShitterFont.styled(.subheadline))
                    }
                    .listRowBackground(ShitterTheme.surface.opacity(0.6))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { showManualEntry = false }
                        .foregroundColor(ShitterTheme.accent)
                }
            }
        }
    }

    private func maybeStartSimulatorAutoSSH() {
#if DEBUG
        guard !autoSSHStarted else { return }
        let env = ProcessInfo.processInfo.environment
        guard env["CODEXIOS_SIM_AUTO_SSH"] == "1",
              let host = env["CODEXIOS_SIM_AUTO_SSH_HOST"], !host.isEmpty,
              let user = env["CODEXIOS_SIM_AUTO_SSH_USER"], !user.isEmpty,
              let pass = env["CODEXIOS_SIM_AUTO_SSH_PASS"], !pass.isEmpty else {
            return
        }
        autoSSHStarted = true

        Task {
            do {
                NSLog("[AUTO_SSH] connecting to %@ as %@", host, user)
                let ssh = SSHSessionManager.shared
                try await ssh.connect(host: host, credentials: .password(username: user, password: pass))
                let port = try await ssh.startRemoteServer()
                NSLog("[AUTO_SSH] remote app-server port %d", Int(port))
                let server = DiscoveredServer(
                    id: "auto-ssh-\(host):\(port)",
                    name: host,
                    hostname: host,
                    port: port,
                    source: .manual,
                    hasCodexServer: true,
                    sshPortForwardingEnabled: false
                )
                await connectToServer(server)
            } catch {
                NSLog("[AUTO_SSH] failed: %@", error.localizedDescription)
            }
        }
#endif
    }

    private var showConnectError: Binding<Bool> {
        Binding(
            get: { connectError != nil },
            set: { newValue in
                if !newValue {
                    connectError = nil
                }
            }
        )
    }

    private func portBinding(for mode: ManualConnectionMode) -> Binding<String> {
        switch mode {
        case .codex:
            return $manualCodexPort
        case .ssh:
            return $manualSSHPort
        }
    }

    private func submitManualEntry() {
        let host = manualHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else { return }

        let wakeInput = manualWakeMAC.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedWakeMAC = DiscoveredServer.normalizeWakeMAC(wakeInput)
        if !wakeInput.isEmpty && normalizedWakeMAC == nil {
            connectError = "Wake MAC must look like aa:bb:cc:dd:ee:ff"
            return
        }

        switch manualConnectionMode {
        case .codex:
            guard let port = UInt16(manualCodexPort) else {
                connectError = "Codex port must be a valid number"
                return
            }
            let server = DiscoveredServer(
                id: "manual-\(host):\(port)",
                name: host,
                hostname: host,
                port: port,
                source: .manual,
                hasCodexServer: true,
                wakeMAC: normalizedWakeMAC,
                sshPortForwardingEnabled: false
            )
            showManualEntry = false
            Task { await connectToServer(server) }
        case .ssh:
            guard let sshPort = UInt16(manualSSHPort) else {
                connectError = "SSH port must be a valid number"
                return
            }
            pendingSSHServer = DiscoveredServer(
                id: "manual-ssh-\(host):\(sshPort)",
                name: host,
                hostname: host,
                port: sshPort,
                source: .manual,
                hasCodexServer: false,
                wakeMAC: normalizedWakeMAC,
                sshPortForwardingEnabled: manualUseSSHPortForward
            )
            showManualEntry = false
        }
    }
}

private final class WakeProbeResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    func markResumed() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if resumed {
            return false
        }
        resumed = true
        return true
    }
}

private enum ManualConnectionMode: String, CaseIterable, Identifiable {
    case codex
    case ssh

    var id: String { rawValue }

    var label: String {
        switch self {
        case .codex:
            return "Codex"
        case .ssh:
            return "SSH"
        }
    }

    var formHeader: String {
        switch self {
        case .codex:
            return "Codex Server"
        case .ssh:
            return "SSH Bootstrap"
        }
    }

    var portPlaceholder: String {
        switch self {
        case .codex:
            return "codex port"
        case .ssh:
            return "ssh port"
        }
    }

    var primaryButtonTitle: String {
        switch self {
        case .codex:
            return "Connect"
        case .ssh:
            return "Continue to SSH Login"
        }
    }
}

#if DEBUG
#Preview("Discovery") {
    ShitterPreviewScene(
        serverManager: ShitterPreviewData.makeServerManager(includeActiveThread: false),
        includeBackground: false
    ) {
        NavigationStack {
            DiscoveryView(
                autoStartDiscovery: false,
                initialServers: ShitterPreviewData.sampleDiscoveryServers
            )
        }
    }
}
#endif
