import Foundation
import SMFACore

enum KeychainStoreError: Error {
    case unexpectedStatus(OSStatus)
}

/// 账号密钥的落地存储。
///
/// 全部账号序列化成一条 Keychain 记录，而不是一账号一条：账号量级很小，
/// 一次读写全量的开销可忽略，换来的是增删改的原子性——不会出现写了一半的状态。
final class KeychainAccountStore {

    private let service: String

    init(service: String = "cc.space01.smfa.accounts") {
        self.service = service
    }

    func load() throws -> [MFAAccount] {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(baseQuery.merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]) { _, new in new } as CFDictionary, &result)

        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else { throw KeychainStoreError.unexpectedStatus(status) }
        guard let data = result as? Data else { return [] }
        return try Self.decoder.decode([MFAAccount].self, from: data)
    }

    func save(_ accounts: [MFAAccount]) throws {
        let data = try Self.encoder.encode(accounts)
        let status = SecItemUpdate(baseQuery as CFDictionary,
                                   [kSecValueData as String: data] as CFDictionary)

        if status == errSecItemNotFound {
            let addStatus = SecItemAdd(baseQuery.merging([
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            ]) { _, new in new } as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainStoreError.unexpectedStatus(addStatus)
            }
            return
        }
        guard status == errSecSuccess else { throw KeychainStoreError.unexpectedStatus(status) }
    }

    func removeAll() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "accounts",
        ]
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
