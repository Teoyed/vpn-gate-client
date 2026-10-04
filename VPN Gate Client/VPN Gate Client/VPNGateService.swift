import Foundation
import Network

enum VPNGateError: LocalizedError {
    case invalidResponse
    case noServers
    var errorDescription: String? {
        switch self { case .invalidResponse: "VPN Gate returned an invalid server list."; case .noServers: "No VPN Gate servers are currently available." }
    }
}

struct VPNGateService {
    private let endpoint = URL(string: "https://www.vpngate.net/api/iphone/")!

    func fetchServers() async throws -> [VPNServer] {
        var request = URLRequest(url: endpoint, timeoutInterval: 30)
        request.setValue("VPN Gate Client/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw VPNGateError.invalidResponse }

        let csv = String(decoding: data, as: UTF8.self)
        let rows = csv.split(whereSeparator: \.isNewline).drop { $0.first == "*" }
        guard let header = rows.first else { throw VPNGateError.noServers }
        let columns = parseCSV(String(header))
        guard let ipIndex = columns.firstIndex(of: "IP"), let countryIndex = columns.firstIndex(of: "CountryLong") else { throw VPNGateError.invalidResponse }

        let servers = rows.dropFirst().compactMap { line -> VPNServer? in
            let values = parseCSV(String(line))
            guard values.count > max(ipIndex, countryIndex), let ip = IPv4Address(values[ipIndex]) else { return nil }
            let country = values[countryIndex].isEmpty ? "Unknown" : values[countryIndex]
            let city = values.first(where: { $0.contains("/") })?.split(separator: "/").first.map(String.init) ?? "VPN Gate"
            let address = String(describing: ip)
            return VPNServer(id: address.hashValue, flag: flag(for: country), country: country, city: city, name: address, ip: address, ping: 0, load: 0, status: .available)
        }
        guard !servers.isEmpty else { throw VPNGateError.noServers }
        return Array(Dictionary(grouping: servers, by: { $0.ip }).compactMap { $0.value.first })
    }

    func ping(_ server: VPNServer) async -> Int? {
        let host = NWEndpoint.Host(server.ip)
        let start = ContinuousClock.now
        return await withCheckedContinuation { continuation in
            let connection = NWConnection(host: host, port: 443, using: .tcp)
            let gate = PingCompletionGate()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard gate.claim() else { return }
                    let elapsed = start.duration(to: .now)
                    connection.cancel()
                    continuation.resume(returning: Int(elapsed.components.attoseconds / 1_000_000_000_000_000) + Int(elapsed.components.seconds * 1_000))
                case .failed, .cancelled:
                    guard gate.claim() else { return }
                    connection.cancel()
                    continuation.resume(returning: nil)
                default: break
                }
            }
            connection.start(queue: .global(qos: .utility))
        }
    }

    private func parseCSV(_ line: String) -> [String] {
        var values: [String] = [], value = "", quoted = false
        for character in line {
            if character == "\"" { quoted.toggle() }
            else if character == "," && !quoted { values.append(value); value = "" }
            else { value.append(character) }
        }
        values.append(value)
        return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func flag(for country: String) -> String {
        let codes = ["United States": "🇺🇸", "Germany": "🇩🇪", "United Kingdom": "🇬🇧", "Japan": "🇯🇵", "Canada": "🇨🇦", "Netherlands": "🇳🇱"]
        return codes[country] ?? "🌐"
    }
}

private final class PingCompletionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false

    func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !completed else { return false }
        completed = true
        return true
    }
}
