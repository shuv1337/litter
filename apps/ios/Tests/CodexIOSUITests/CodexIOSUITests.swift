import XCTest

final class CodexIOSUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureScreenshots() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CODEXIOS_UI_TEST_FORCE_DISCOVERY"] = "1"
        setupSnapshot(app)
        app.launch()

        XCTAssertTrue(presentDiscovery(in: app), "Unable to open discovery")
        XCTAssertTrue(waitForDiscoveryServers(in: app, timeout: 20), "No discovery servers found")
        _ = waitForDiscoveryListToPopulate(in: app, timeout: 12, minimumRows: 3)
        snapshot("01DiscoveryLoaded")

        XCTAssertTrue(
            selectPreferredDiscoveryServer(in: app, preferredHostFragment: ".203"),
            "Unable to tap the .203 server"
        )
        _ = waitForDiscoveryDismissed(in: app, timeout: 20)
        ensureSidebarClosed(in: app)
        _ = waitForSidebarClosed(in: app, timeout: 8)
        _ = waitForMainContentReady(in: app, timeout: 12)
        sleep(1)
        snapshot("02AfterSelecting203Server")

        XCTAssertTrue(openSidebar(in: app), "Unable to open sidebar")
        XCTAssertTrue(waitForAnySidebarSession(in: app, timeout: 12), "No sidebar sessions to select")
        sleep(1)
        snapshot("03SidebarOpened")

        XCTAssertTrue(selectSidebarSession(in: app), "Unable to select a sidebar session")
        _ = waitForSidebarClosed(in: app, timeout: 8)
        _ = waitForMainContentReady(in: app, timeout: 10)
        sleep(2)
        snapshot("04SidebarItemLoaded")
    }

    private func presentDiscovery(in app: XCUIApplication) -> Bool {
        if isDiscoveryVisible(in: app) {
            return true
        }

        let connectButton = app.buttons["Connect to Server"]
        if connectButton.waitForExistence(timeout: 2), connectButton.isHittable {
            connectButton.tap()
            if waitForDiscoveryVisible(in: app, timeout: 8) {
                return true
            }
        }

        guard openSidebar(in: app) else { return false }

        let addServerButton = app.buttons["sidebar.addServerButton"]
        if addServerButton.waitForExistence(timeout: 3), addServerButton.isHittable {
            addServerButton.tap()
            return waitForDiscoveryVisible(in: app, timeout: 8)
        }

        let sidebarConnectButton = app.buttons["sidebar.connectButton"]
        if sidebarConnectButton.waitForExistence(timeout: 2), sidebarConnectButton.isHittable {
            sidebarConnectButton.tap()
            return waitForDiscoveryVisible(in: app, timeout: 8)
        }

        return waitForDiscoveryVisible(in: app, timeout: 5)
    }

    private func waitForDiscoveryServers(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let codexRows = codexDiscoveryRows(in: app)
        let sshRows = sshDiscoveryRows(in: app)
        let preferredHost = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", ".203"))

        return waitUntil(timeout: timeout) {
            preferredHost.firstMatch.exists || codexRows.firstMatch.exists || sshRows.firstMatch.exists
        }
    }

    private func waitForDiscoveryListToPopulate(
        in app: XCUIApplication,
        timeout: TimeInterval,
        minimumRows: Int
    ) -> Bool {
        let codexRows = codexDiscoveryRows(in: app)
        let sshRows = sshDiscoveryRows(in: app)
        let preferredHost = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", ".203"))
        let scanningLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Scanning")
        )

        return waitUntil(timeout: timeout) {
            let totalRows = codexRows.count + sshRows.count
            if totalRows >= minimumRows {
                return true
            }
            if preferredHost.firstMatch.exists && totalRows > 0 && !scanningLabel.firstMatch.exists {
                return true
            }
            return false
        }
    }

    private func selectPreferredDiscoveryServer(in app: XCUIApplication, preferredHostFragment: String) -> Bool {
        let discoveryList = identifiedElement("discovery.list", in: app)
        guard discoveryList.waitForExistence(timeout: 8) else { return false }

        for _ in 0..<5 {
            if tapPreferredDiscoveryRow(in: app, hostFragment: preferredHostFragment) ||
                tapPreferredHostText(in: app, hostFragment: preferredHostFragment) {
                return true
            }
            discoveryList.swipeUp()
        }

        for _ in 0..<5 {
            if tapPreferredDiscoveryRow(in: app, hostFragment: preferredHostFragment) ||
                tapPreferredHostText(in: app, hostFragment: preferredHostFragment) {
                return true
            }
            discoveryList.swipeDown()
        }

        let codexRows = codexDiscoveryRows(in: app)
        if codexRows.firstMatch.waitForExistence(timeout: 4), codexRows.firstMatch.isHittable {
            codexRows.firstMatch.tap()
            return true
        }

        return false
    }

    private func tapPreferredDiscoveryRow(in app: XCUIApplication, hostFragment: String) -> Bool {
        let normalized = hostFragment
            .lowercased()
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: ":", with: "_")

        let query = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND identifier CONTAINS[c] %@",
                "discovery.server.codex.",
                normalized
            )
        )
        let row = query.firstMatch
        guard row.waitForExistence(timeout: 1), row.isHittable else { return false }
        row.tap()
        return true
    }

    private func tapPreferredHostText(in app: XCUIApplication, hostFragment: String) -> Bool {
        let hostTexts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", hostFragment))
        let first = hostTexts.firstMatch
        guard first.waitForExistence(timeout: 1) else { return false }
        guard first.isHittable else { return false }
        first.tap()
        return true
    }

    private func waitForDiscoveryVisible(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        waitUntil(timeout: timeout) { isDiscoveryVisible(in: app) }
    }

    private func waitForDiscoveryDismissed(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let discoveryList = identifiedElement("discovery.list", in: app)
        return waitUntil(timeout: timeout) { !discoveryList.exists || !discoveryList.isHittable }
    }

    private func isDiscoveryVisible(in app: XCUIApplication) -> Bool {
        let discoveryList = identifiedElement("discovery.list", in: app)
        return discoveryList.exists && discoveryList.isHittable
    }

    private func openSidebar(in app: XCUIApplication) -> Bool {
        if isSidebarOpen(in: app) {
            return true
        }

        let toggle = app.buttons["header.sidebarButton"]
        if toggle.waitForExistence(timeout: 8), toggle.isHittable {
            toggle.tap()
        }
        if waitForSidebarOpen(in: app, timeout: 3) {
            return true
        }

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.5))
        start.press(forDuration: 0.02, thenDragTo: end)

        return waitForSidebarOpen(in: app, timeout: 4)
    }

    private func waitForSidebarOpen(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        waitUntil(timeout: timeout) { isSidebarOpen(in: app) }
    }

    private func ensureSidebarClosed(in app: XCUIApplication) {
        guard isSidebarOpen(in: app) else { return }

        let toggle = app.buttons["header.sidebarButton"]
        if toggle.exists && toggle.isHittable {
            toggle.tap()
        }
        if waitForSidebarClosed(in: app, timeout: 2) {
            return
        }

        // Tap away on the dimmed area.
        let dismissPoint = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        dismissPoint.tap()
    }

    private func waitForSidebarClosed(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let sidebar = identifiedElement("sidebar.container", in: app)
        return waitUntil(timeout: timeout) {
            guard sidebar.exists else { return true }
            return sidebar.frame.maxX <= 0
        }
    }

    private func isSidebarOpen(in app: XCUIApplication) -> Bool {
        let newSession = app.buttons["sidebar.newSessionButton"]
        if newSession.exists && newSession.isHittable {
            return true
        }

        let addServer = app.buttons["sidebar.addServerButton"]
        if addServer.exists && addServer.isHittable {
            return true
        }

        let connect = app.buttons["sidebar.connectButton"]
        if connect.exists && connect.isHittable {
            return true
        }

        let rows = app.descendants(matching: .any).matching(identifier: "sidebar.sessionRow")
        if rows.firstMatch.exists && rows.firstMatch.isHittable {
            return true
        }

        let sidebar = identifiedElement("sidebar.container", in: app)
        guard sidebar.exists else { return false }
        return sidebar.frame.minX > -40 && sidebar.isHittable
    }

    private func waitForAnySidebarSession(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let rows = app.descendants(matching: .any).matching(identifier: "sidebar.sessionRow")
        return waitUntil(timeout: timeout) {
            rows.firstMatch.exists
        }
    }

    private func selectSidebarSession(in app: XCUIApplication) -> Bool {
        let sidebar = identifiedElement("sidebar.container", in: app)
        let rowQuery = app.descendants(matching: .any).matching(identifier: "sidebar.sessionRow")

        for _ in 0..<8 {
            let count = min(rowQuery.count, 12)
            if count > 0 {
                for index in 0..<count {
                    let row = rowQuery.element(boundBy: index)
                    if row.exists && row.isHittable {
                        row.tap()
                        return true
                    }
                }
            }
            if sidebar.exists {
                sidebar.swipeUp()
            } else {
                break
            }
        }

        let titles = app.staticTexts.matching(identifier: "sidebar.sessionTitle")
        let titleCount = min(titles.count, 12)
        for index in 0..<titleCount {
            let title = titles.element(boundBy: index)
            if title.exists && title.isHittable {
                title.tap()
                return true
            }
        }

        return false
    }

    private func waitForMainContentReady(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        waitUntil(timeout: timeout) {
            app.buttons["header.sidebarButton"].exists && !isDiscoveryVisible(in: app)
        }
    }

    private func waitUntil(timeout: TimeInterval, poll: TimeInterval = 0.2, condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(poll))
        }
        return condition()
    }

    private func identifiedElement(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func codexDiscoveryRows(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "discovery.server.codex."))
    }

    private func sshDiscoveryRows(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "discovery.server.ssh."))
    }
}
