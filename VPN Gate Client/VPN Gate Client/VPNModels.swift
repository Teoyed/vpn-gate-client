import SwiftUI

enum VPNState: Equatable { case disconnected, connecting, connected, disconnecting, failed
    var title: String { switch self { case .disconnected: "Not Connected"; case .connecting: "Connecting..."; case .connected: "Connected"; case .disconnecting: "Disconnecting..."; case .failed: "Connection Failed" } }
}
struct VPNServer: Identifiable, Hashable {
    let id: Int
    let flag, country, city, name, ip: String
    let ping, load: Int
    let status: ServerStatus

    init(id: Int, flag: String, country: String, city: String, name: String, ip: String = "", ping: Int, load: Int, status: ServerStatus) {
        self.id = id; self.flag = flag; self.country = country; self.city = city; self.name = name; self.ip = ip; self.ping = ping; self.load = load; self.status = status
    }
}
enum ServerStatus: String { case available = "Available", busy = "Busy", slow = "Slow", offline = "Offline"
    var color: Color { switch self { case .available: .green; case .busy: .orange; case .slow: .yellow; case .offline: .secondary } }
}
enum DemoData { static let servers = [
    VPNServer(id: 1, flag: "🇺🇸", country: "United States", city: "New York", name: "US-nyc-01", ping: 32, load: 24, status: .available),
    VPNServer(id: 2, flag: "🇩🇪", country: "Germany", city: "Frankfurt", name: "DE-fra-03", ping: 48, load: 41, status: .available),
    VPNServer(id: 3, flag: "🇬🇧", country: "United Kingdom", city: "London", name: "UK-lon-02", ping: 55, load: 63, status: .busy),
    VPNServer(id: 4, flag: "🇯🇵", country: "Japan", city: "Tokyo", name: "JP-tyo-01", ping: 118, load: 76, status: .slow),
    VPNServer(id: 5, flag: "🇨🇦", country: "Canada", city: "Toronto", name: "CA-tor-04", ping: 42, load: 18, status: .available),
    VPNServer(id: 6, flag: "🇳🇱", country: "Netherlands", city: "Amsterdam", name: "NL-ams-06", ping: 51, load: 100, status: .offline)
] }
