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
        manager.localizedDescription = "VPN Gate"
        let configuration = NEVPNProtocolIPSec()
        configuration.serverAddress = server.ip
        configuration.username = "vpn"
        configuration.passwordReference = try credentialReference(service: "com.vpngate.client.l2tp.password", account: "vpn", value: "vpn")
        configuration.sharedSecretReference = try credentialReference(service: "com.vpngate.client.l2tp.shared-secret", account: "vpn", value: "vpn")
        configuration.authenticationMethod = .sharedSecret
        configuration.useExtendedAuthentication = true
        configuration.disconnectOnSleep = false
        // Full-tunnel mode: route all device traffic through the VPN.
        configuration.includeAllNetworks = true
        configuration.excludeLocalNetworks = false
        manager.protocolConfiguration = configuration
        manager.isEnabled = true
        manager.isOnDemandEnabled = false
        try await manager.saveToPreferences()
        try manager.connection.startVPNTunnel()
    }

    func disconnect() {
        manager.connection.stopVPNTunnel()
    }

    private func credentialReference(service: String, account: String, value: String) throws -> Data {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnPersistentRef as String: true]
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let reference = result as? Data { return reference }
        let add: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecValueData as String: Data(value.utf8)]
        guard SecItemAdd(add as CFDictionary, &result) == errSecSuccess else { throw VPNConnectionError.unavailable }
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let reference = result as? Data else { throw VPNConnectionError.unavailable }
        return reference
    }
}
