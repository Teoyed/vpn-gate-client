import Foundation
import Combine

@MainActor final class VPNViewModel: ObservableObject {
    @Published private(set) var vpnState: VPNState = .disconnected
    @Published private(set) var selectedServer = DemoData.servers[0]
    @Published private(set) var servers = DemoData.servers
    @Published private(set) var isLoadingServers = false
    @Published private(set) var serverError: String?
    @Published private(set) var connectionSeconds = 0
    @Published private(set) var connectionError: String?
    @Published var isPermissionSheetPresented = false
    @Published var isOnboarded = true
    @Published var searchText = ""
    @Published var sortByPing = false
    @Published var autoConnect = false; @Published var connectOnWiFi = true; @Published var connectOnCellular = false; @Published var killSwitch = true; @Published var notifications = true
    private var connectionTask: Task<Void, Never>?
    private let vpnGate = VPNGateService()
    private let connectionService = VPNConnectionService()
    private var isRefreshingServers = false
    private var lastServerRefresh: Date?
    var filteredServers: [VPNServer] { let result = servers.filter { searchText.isEmpty || $0.country.localizedCaseInsensitiveContains(searchText) || $0.city.localizedCaseInsensitiveContains(searchText) || $0.name.localizedCaseInsensitiveContains(searchText) }; return sortByPing ? result.sorted { $0.ping < $1.ping } : result }
    func requestConnection() {
        switch vpnState {
        case .disconnected, .failed:
            if UserDefaults.standard.bool(forKey: "vpnGatePermissionExplained") {
                connect()
            } else {
                isPermissionSheetPresented = true
            }
        case .connected: disconnect()
        case .connecting, .disconnecting: break
        }
    }
    func allowVPNAccess() {
        UserDefaults.standard.set(true, forKey: "vpnGatePermissionExplained")
        isPermissionSheetPresented = false
        connect()
    }
    func refreshServers(force: Bool = false) async {
        guard !isRefreshingServers else { return }
        if !force, let lastServerRefresh, Date().timeIntervalSince(lastServerRefresh) < 3 { return }
        isRefreshingServers = true
        lastServerRefresh = Date()
        isLoadingServers = true
        serverError = nil
        // Live VPN Gate import is intentionally disabled for now.
        // let imported = try await vpnGate.fetchServers()
        let imported = DemoData.servers
        let service = vpnGate
        let measured = await withTaskGroup(of: VPNServer.self, returning: [VPNServer].self) { group in
            for server in imported {
                group.addTask {
                    let latency = await service.ping(server) ?? 0
                    return VPNServer(id: server.id, flag: server.flag, country: server.country, city: server.city, name: server.name, ip: server.ip, ping: latency, load: server.load, status: latency == 0 ? .offline : .available)
                }
            }
            return await group.reduce(into: []) { $0.append($1) }
        }
        servers = measured.sorted { ($0.ping == 0 ? Int.max : $0.ping) < ($1.ping == 0 ? Int.max : $1.ping) }
        isLoadingServers = false
        isRefreshingServers = false
    }
    func connect() {
        connectionTask?.cancel()
        vpnState = .connecting
        connectionError = nil
        connectionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard let self, !Task.isCancelled else { return }
            do {
                try await connectionService.connect(to: selectedServer)
                vpnState = .connected
                connectionSeconds = 0
            } catch {
                vpnState = .failed
                connectionError = error.localizedDescription
                return
            }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                connectionSeconds += 1
            }
        }
    }
    func disconnect() {
        connectionTask?.cancel()
        connectionService.disconnect()
        vpnState = .disconnecting
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard let self, !Task.isCancelled else { return }
            vpnState = .disconnected
            connectionSeconds = 0
        }
    }
    func select(server: VPNServer) { selectedServer = server }
    deinit { connectionTask?.cancel() }
}
func formatTime(_ seconds: Int) -> String { String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60) }
