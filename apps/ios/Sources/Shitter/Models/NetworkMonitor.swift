import Foundation
import Network

@MainActor
final class NetworkMonitor {
    private(set) var isNetworkAvailable = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "Shitter.NetworkMonitor")

    var onNetworkRestored: (() -> Void)?
    var onNetworkLost: (() -> Void)?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let satisfied = path.status == .satisfied
                let wasAvailable = self.isNetworkAvailable
                self.isNetworkAvailable = satisfied
                if satisfied && !wasAvailable {
                    NSLog("[network] path restored")
                    self.onNetworkRestored?()
                } else if !satisfied && wasAvailable {
                    NSLog("[network] path lost")
                    self.onNetworkLost?()
                }
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}
