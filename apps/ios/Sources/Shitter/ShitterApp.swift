import SwiftUI
import Combine
import Inject
import UIKit

@main
struct ShitterApp: App {
    @StateObject private var serverManager = ServerManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serverManager)
                .task { await serverManager.reconnectAll() }
        }
    }
}

struct ContentView: View {
    @ObserveInjection var inject
    @EnvironmentObject var serverManager: ServerManager
    @StateObject private var appState = AppState()
    @State private var sidebarDragOffset: CGFloat = 0
    @State private var isEdgeOpeningSidebar = false
    @State private var keyboardHeight: CGFloat = 0

    private let sidebarAnimation = Animation.spring(response: 0.3, dampingFraction: 0.86)

    private var sidebarRevealProgress: CGFloat {
        guard appState.sidebarOpen else { return 0 }
        return min(1, max(0, 1 + (sidebarDragOffset / SidebarOverlay.sidebarWidth)))
    }

    var body: some View {
        GeometryReader { geometry in
        ZStack {
            ShitterTheme.backgroundGradient.ignoresSafeArea()

            mainContent(topInset: geometry.safeAreaInsets.top, bottomInset: keyboardHeight > 0 ? 0 : geometry.safeAreaInsets.bottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: [.top, .bottom])
                .overlay(alignment: .top) {
                    if serverManager.activeThreadKey != nil {
                        HeaderView(topInset: geometry.safeAreaInsets.top)
                    }
                }
                .overlay {
                    if appState.showModelSelector {
                        Color.black.opacity(0.01)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    appState.showModelSelector = false
                                }
                            }
                    }
                }
            .offset(x: sidebarRevealProgress * 284)
            .scaleEffect(1 - (0.04 * sidebarRevealProgress), anchor: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 20 * sidebarRevealProgress, style: .continuous))
            .shadow(color: .black.opacity(0.22 * sidebarRevealProgress), radius: 26, x: 8, y: 0)
            .allowsHitTesting(sidebarRevealProgress < 0.01)
            .animation(sidebarAnimation, value: appState.sidebarOpen)
            .animation(sidebarAnimation, value: sidebarDragOffset)
            .simultaneousGesture(edgeOpenGesture)

            SidebarOverlay(dragOffset: $sidebarDragOffset, topInset: geometry.safeAreaInsets.top)

            if let approval = serverManager.activePendingApproval {
                ApprovalPromptView(approval: approval) { decision in
                    serverManager.respondToPendingApproval(requestId: approval.requestId, decision: decision)
                }
            }
        }
        .ignoresSafeArea(.container)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = frame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .environmentObject(appState)
        .onAppear {
            let forceDiscoveryForUITest =
                ProcessInfo.processInfo.environment["CODEXIOS_UI_TEST_FORCE_DISCOVERY"] == "1"
            if forceDiscoveryForUITest {
                appState.showServerPicker = true
            }
        }
        .onChange(of: appState.sidebarOpen) { _, isOpen in
            if !isOpen { sidebarDragOffset = 0 }
        }
        .enableInjection()
        .sheet(isPresented: $appState.showServerPicker) {
            NavigationStack {
                DiscoveryView(onServerSelected: { server in
                    appState.showServerPicker = false
                    appState.sidebarOpen = true
                })
                .environmentObject(serverManager)
            }
        }
    }

    private var edgeOpenGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                guard !appState.sidebarOpen || isEdgeOpeningSidebar else { return }

                if !isEdgeOpeningSidebar {
                    let startsAtEdge = value.startLocation.x <= 24
                    let horizontalIntent = abs(value.translation.width) > abs(value.translation.height)
                    guard startsAtEdge, horizontalIntent, value.translation.width > 0 else { return }
                    isEdgeOpeningSidebar = true
                    var transaction = Transaction()
                    transaction.animation = nil
                    withTransaction(transaction) {
                        appState.sidebarOpen = true
                        sidebarDragOffset = -SidebarOverlay.sidebarWidth
                    }
                }

                let translationX = max(0, value.translation.width)
                sidebarDragOffset = min(
                    0,
                    max(-SidebarOverlay.sidebarWidth, -SidebarOverlay.sidebarWidth + translationX)
                )
            }
            .onEnded { value in
                guard isEdgeOpeningSidebar else { return }
                isEdgeOpeningSidebar = false

                let projectedOpenDistance = max(value.translation.width, value.predictedEndTranslation.width)
                let shouldOpen = projectedOpenDistance > SidebarOverlay.sidebarWidth * 0.35
                withAnimation(sidebarAnimation) {
                    appState.sidebarOpen = shouldOpen
                    sidebarDragOffset = 0
                }
            }
    }

    private func mainContent(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        Group {
            if serverManager.activeThreadKey != nil {
                ConversationView(topInset: topInset, bottomInset: bottomInset)
            } else {
                HomeNavigationView()
                    .environmentObject(serverManager)
                    .environmentObject(appState)
            }
        }
    }
}

private struct HomeNavigationView: View {
    @EnvironmentObject var serverManager: ServerManager
    @EnvironmentObject var appState: AppState
    @State private var showSessions = false

    var body: some View {
        NavigationStack {
            DiscoveryView(onServerSelected: { _ in
                showSessions = true
            })
            .environmentObject(serverManager)
            .navigationDestination(isPresented: $showSessions) {
                SessionSidebarView()
                    .navigationTitle("Sessions")
                    .navigationBarTitleDisplayMode(.inline)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ShitterTheme.backgroundGradient.ignoresSafeArea())
            }
        }
    }
}

private struct ApprovalPromptView: View {
    let approval: ServerManager.PendingApproval
    let onDecision: (ServerManager.ApprovalDecision) -> Void

    private var title: String {
        switch approval.kind {
        case .commandExecution:
            return "Command Approval Required"
        case .fileChange:
            return "File Change Approval Required"
        }
    }

    private var requesterLabel: String? {
        let nickname = approval.requesterAgentNickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let role = approval.requesterAgentRole?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !nickname.isEmpty && !role.isEmpty {
            return "\(nickname) [\(role)]"
        }
        if !nickname.isEmpty {
            return nickname
        }
        if !role.isEmpty {
            return "[\(role)]"
        }
        return nil
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(ShitterFont.styled(.headline))
                    .foregroundColor(ShitterTheme.textPrimary)

                if let reason = approval.reason, !reason.isEmpty {
                    Text(reason)
                        .font(ShitterFont.styled(.footnote))
                        .foregroundColor(ShitterTheme.textSecondary)
                }

                if let requesterLabel {
                    Text("Requester: \(requesterLabel)")
                        .font(ShitterFont.styled(.caption))
                        .foregroundColor(ShitterTheme.textMuted)
                }

                if let command = approval.command, !command.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Command")
                            .font(ShitterFont.styled(.caption))
                            .foregroundColor(ShitterTheme.textMuted)
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(command)
                                .font(ShitterFont.styled(.footnote))
                                .foregroundColor(ShitterTheme.textBody)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(ShitterTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                if let cwd = approval.cwd, !cwd.isEmpty {
                    Text("CWD: \(cwd)")
                        .font(ShitterFont.styled(.caption))
                        .foregroundColor(ShitterTheme.textMuted)
                }

                if let grantRoot = approval.grantRoot, !grantRoot.isEmpty {
                    Text("Grant Root: \(grantRoot)")
                        .font(ShitterFont.styled(.caption))
                        .foregroundColor(ShitterTheme.textMuted)
                }

                VStack(spacing: 8) {
                    Button("Allow Once") { onDecision(.accept) }
                        .buttonStyle(.borderedProminent)
                        .tint(ShitterTheme.accent)
                        .frame(maxWidth: .infinity)

                    Button("Allow for Session") { onDecision(.acceptForSession) }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)

                    HStack(spacing: 8) {
                        Button("Deny") { onDecision(.decline) }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)

                        Button("Abort") { onDecision(.cancel) }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                    }
                }
                .font(ShitterFont.styled(.callout))
            }
            .padding(16)
            .modifier(GlassRectModifier(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(ShitterTheme.border, lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
        .transition(.opacity)
    }
}

struct LaunchView: View {
    var body: some View {
        ZStack {
            ShitterTheme.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 24) {
                BrandLogo(size: 132)
                Text("AI coding agent on iOS")
                    .font(ShitterFont.styled(.body))
                    .foregroundColor(ShitterTheme.textMuted)
            }
        }
    }
}
