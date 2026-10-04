import SwiftUI

enum VPNState: Equatable { case disconnected, connecting, connected, disconnecting, failed
    var title: String { switch self { case .disconnected: "Not Connected"; case .connecting: "Connecting..."; case .connected: "Connected"; case .disconnecting: "Disconnecting..."; case .failed: "Connection Failed" } }
}
struct VPNServer: Identifiable, Hashable {
    let id: Int
    let flag, country, city, name, ip: String
    let ping, load: Int
    let status: ServerStatus

    nonisolated init(id: Int, flag: String, country: String, city: String, name: String, ip: String = "", ping: Int, load: Int, status: ServerStatus) {
        self.id = id; self.flag = flag; self.country = country; self.city = city; self.name = name; self.ip = ip; self.ping = ping; self.load = load; self.status = status
    }
}
enum ServerStatus: String { case available = "Available", busy = "Busy", slow = "Slow", offline = "Offline"
    var color: Color { switch self { case .available: .green; case .busy: .orange; case .slow: .yellow; case .offline: .secondary } }
}
enum DemoData {
    static let servers: [VPNServer] = [
        make("180.197.121.148", "Japan"), make("219.100.37.195", "Japan"), make("219.100.37.209", "Japan"), make("219.100.37.20", "Japan"), make("219.100.37.200", "Japan"), make("219.100.37.162", "Japan"), make("219.100.37.203", "Japan"), make("219.100.37.28", "Japan"), make("219.100.37.126", "Japan"), make("110.163.135.206", "Japan"), make("124.35.90.44", "Japan"),
        make("150.40.105.4", "Croatia", localName: "Hrvatska"), make("150.40.105.24", "Croatia", localName: "Hrvatska"), make("31.59.137.26", "United Kingdom"), make("150.40.105.25", "Croatia", localName: "Hrvatska"), make("150.40.105.20", "Croatia", localName: "Hrvatska"), make("150.40.105.5", "Croatia", localName: "Hrvatska"), make("150.40.105.12", "Croatia", localName: "Hrvatska"), make("150.40.105.21", "Croatia", localName: "Hrvatska"), make("150.40.105.3", "Croatia", localName: "Hrvatska"), make("150.40.105.15", "Croatia", localName: "Hrvatska"), make("150.40.105.22", "Croatia", localName: "Hrvatska"),
        make("178.32.222.148", "France"), make("150.40.105.19", "Croatia", localName: "Hrvatska"), make("150.40.105.9", "Croatia", localName: "Hrvatska"), make("150.40.105.16", "Croatia", localName: "Hrvatska"), make("36.227.206.157", "Taiwan"), make("150.40.105.18", "Croatia", localName: "Hrvatska"), make("150.40.105.8", "Croatia", localName: "Hrvatska"), make("150.40.105.13", "Croatia", localName: "Hrvatska"), make("150.40.105.10", "Croatia", localName: "Hrvatska"), make("5.78.155.207", "Germany"), make("150.40.105.7", "Croatia", localName: "Hrvatska"),
        make("31.215.111.139", "United Arab Emirates"), make("219.100.37.163", "Japan"), make("219.100.37.206", "Japan"), make("219.100.37.57", "Japan"), make("219.100.37.22", "Japan"), make("115.179.206.241", "Japan"), make("219.100.37.122", "Japan"), make("219.100.37.222", "Japan"), make("219.100.37.21", "Japan"), make("219.100.37.53", "Japan"), make("217.138.212.62", "Romania")
    ]

    private static func make(_ ip: String, _ country: String, localName: String? = nil) -> VPNServer {
        let label = localName.map { "\(country) (\($0))" } ?? country
        return VPNServer(id: ip.hashValue, flag: flag(for: country), country: label, city: "VPN Gate", name: ip, ip: ip, ping: 0, load: 0, status: .available)
    }

    private static func flag(for country: String) -> String {
        switch country { case "Japan": "🇯🇵"; case "Croatia": "🇭🇷"; case "United Kingdom": "🇬🇧"; case "France": "🇫🇷"; case "Taiwan": "🇹🇼"; case "Germany": "🇩🇪"; case "United Arab Emirates": "🇦🇪"; case "Romania": "🇷🇴"; default: "🌐" }
    }
}
