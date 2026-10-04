import Foundation
import NetworkExtension
import Security

enum VPNConnectionError: LocalizedError {
    case unavailable
    var errorDescription: String? { "VPN access is not configured for this app yet. Add the Network Extension entitlement and try again." }
}

struct VPNConnectionService {
    private let manager = NEVPNManager.shared()

    func connect(to server: VPNServer) async throws {
        try await manager.loadFromPreferences()
        let configuration = NEVPNProtocolIPSec()
        configuration.serverAddress = server.ip
        configuration.username = "vpn"
        configuration.passwordReference = try passwordReference()
        configuration.authenticationMethod = .sharedSecret
        configuration.useExtendedAuthentication = true
        configuration.disconnectOnSleep = false
        manager.protocolConfiguration = configuration
        manager.isEnabled = true
        try await manager.saveToPreferences()
        try manager.connection.startVPNTunnel()
    }

    func disconnect() {
        manager.connection.stopVPNTunnel()
    }

    private func passwordReference() throws -> Data {
        let service = "com.vpngate.client.l2tp"
        let account = "vpn"
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true]
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data { return data }
        let password = Data("vpn".utf8)
        let add: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecValueData as String: password]
        guard SecItemAdd(add as CFDictionary, &result) == errSecSuccess else { throw VPNConnectionError.unavailable }
        let lookup: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnPersistentRef as String: true]
        guard SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess, let reference = result as? Data else { throw VPNConnectionError.unavailable }
        return reference
    }
}
