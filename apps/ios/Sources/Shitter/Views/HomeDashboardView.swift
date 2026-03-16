import SwiftUI

struct HomeDashboardView: View {
    let recentSessions: [ThreadState]
    let connectedServers: [ServerConnection]
    let openingRecentSessionKey: ThreadKey?
    let isStartingNewSession: Bool
    let onOpenRecentSession: @MainActor (ThreadState) async -> Void
    let onOpenServerSessions: (ServerConnection) -> Void
    let onNewSession: () -> Void
    let onConnectServer: () -> Void
    let onShowSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                recentSessionsSection
                connectedServersSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(ShitterTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onShowSettings) {
                    Image(systemName: "gearshape")
                        .foregroundColor(ShitterTheme.textSecondary)
                }
            }
            ToolbarItem(placement: .principal) {
                BrandLogo(size: 44)
            }
        }
    }

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Recent Sessions",
                buttonTitle: "New Session",
                systemImage: "plus",
                showsLoading: isStartingNewSession,
                action: onNewSession
            )

            if recentSessions.isEmpty {
                emptyStateCard(
                    title: "No recent sessions",
                    message: connectedServers.isEmpty
                        ? "Connect a server to start your first session."
                        : "Start a new session on one of your connected servers."
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(recentSessions) { thread in
                        Button {
                            Task { await onOpenRecentSession(thread) }
                        } label: {
                            recentSessionCard(thread)
                        }
                        .buttonStyle(.plain)
                        .disabled(openingRecentSessionKey != nil || isStartingNewSession)
                    }
                }
            }
        }
    }

    private var connectedServersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Connected Servers", buttonTitle: "Connect Server", systemImage: "bolt.horizontal.circle", action: onConnectServer)

            if connectedServers.isEmpty {
                emptyStateCard(
                    title: "No connected servers",
                    message: "Use Connect Server to add a server and its sessions will appear here."
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(connectedServers) { connection in
                        Button {
                            onOpenServerSessions(connection)
                        } label: {
                            connectedServerRow(connection)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sectionHeader(
        title: String,
        buttonTitle: String,
        systemImage: String,
        showsLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(ShitterFont.styled(.headline))
                .foregroundColor(ShitterTheme.textPrimary)

            Spacer(minLength: 0)

            Button(action: action) {
                Group {
                    if showsLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(ShitterTheme.accent)
                            .frame(width: 74)
                    } else {
                        Label(buttonTitle, systemImage: systemImage)
                            .font(ShitterFont.styled(.caption))
                            .foregroundColor(ShitterTheme.accent)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ShitterTheme.surface.opacity(0.72))
                .overlay(
                    Capsule()
                        .stroke(ShitterTheme.border.opacity(0.7), lineWidth: 1)
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(showsLoading)
        }
    }

    private func recentSessionCard(_ thread: ThreadState) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: thread.hasTurnActive ? "sparkles" : "text.bubble")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ShitterTheme.accent)
                .frame(width: 28, height: 28)
                .background(ShitterTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(thread.sessionTitle)
                    .font(ShitterFont.styled(.subheadline))
                    .foregroundColor(ShitterTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(thread.serverName)

                    if let workspace = HomeDashboardSupport.workspaceLabel(for: thread) {
                        metadataDivider
                        Text(workspace)
                    }

                    metadataDivider
                    Text(thread.updatedAt, style: .relative)
                }
                .font(ShitterFont.styled(.caption))
                .foregroundColor(ShitterTheme.textMuted)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            if openingRecentSessionKey == thread.key {
                ProgressView()
                    .controlSize(.small)
                    .tint(ShitterTheme.accent)
            } else if thread.hasTurnActive {
                statusBadge("Thinking")
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ShitterTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(ShitterTheme.surface.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(ShitterTheme.border.opacity(0.7), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("home.recentSessionCard")
    }

    private func connectedServerRow(_ connection: ServerConnection) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: connection.server.source == .local ? "iphone" : "server.rack")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ShitterTheme.accent)
                .frame(width: 28, height: 28)
                .background(ShitterTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(connection.server.name)
                    .font(ShitterFont.styled(.subheadline))
                    .foregroundColor(ShitterTheme.textPrimary)
                    .lineLimit(1)

                Text(HomeDashboardSupport.serverSubtitle(for: connection.server))
                    .font(ShitterFont.styled(.caption))
                    .foregroundColor(ShitterTheme.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Circle()
                    .fill(ShitterTheme.accent)
                    .frame(width: 8, height: 8)

                Text("Connected")
                    .font(ShitterFont.styled(.caption))
                    .foregroundColor(ShitterTheme.textMuted)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ShitterTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(ShitterTheme.surface.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(ShitterTheme.border.opacity(0.7), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("home.connectedServerRow")
    }

    private func emptyStateCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ShitterFont.styled(.subheadline))
                .foregroundColor(ShitterTheme.textPrimary)

            Text(message)
                .font(ShitterFont.styled(.caption))
                .foregroundColor(ShitterTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ShitterTheme.surface.opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ShitterTheme.border.opacity(0.65), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statusBadge(_ title: String) -> some View {
        Text(title)
            .font(ShitterFont.styled(.caption))
            .foregroundColor(ShitterTheme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(ShitterTheme.accent.opacity(0.14))
            .clipShape(Capsule())
    }

    private var metadataDivider: some View {
        Circle()
            .fill(ShitterTheme.textMuted.opacity(0.7))
            .frame(width: 3, height: 3)
    }
}
