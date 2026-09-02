import Foundation
import Testing
import SMFACore
@testable import SMFA

@Suite("Keychain 账号存储", .serialized)
struct KeychainAccountStoreTests {

    /// 每个测试用独立 service，避免相互污染，也不碰 App 正式数据。
    private func makeStore() -> KeychainAccountStore {
        KeychainAccountStore(service: "cc.space01.smfa.tests.\(UUID().uuidString)")
    }

    private func makeAccount(name: String) -> MFAAccount {
        MFAAccount(id: UUID(), issuer: "Gitee", name: name, secret: "JBSWY3DPEHPK3PXP",
                   algorithm: .sha1, digits: 6, period: 30,
                   createdAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test("空存储读出空数组")
    func 空存储() throws {
        #expect(try makeStore().load().isEmpty)
    }

    @Test("写入后能原样读回")
    func 往返一致() throws {
        let store = makeStore()
        let accounts = [makeAccount(name: "a@x.com"), makeAccount(name: "b@x.com")]
        try store.save(accounts)
        #expect(try store.load() == accounts)
        try store.removeAll()
    }

    @Test("重复写入是覆盖而非追加")
    func 覆盖写() throws {
        let store = makeStore()
        try store.save([makeAccount(name: "first")])
        try store.save([makeAccount(name: "second")])
        let loaded = try store.load()
        #expect(loaded.count == 1)
        #expect(loaded.first?.name == "second")
        try store.removeAll()
    }

    @Test("清空后读出空数组")
    func 清空() throws {
        let store = makeStore()
        try store.save([makeAccount(name: "a@x.com")])
        try store.removeAll()
        #expect(try store.load().isEmpty)
    }

    @Test("Keychain 项限定本机且仅解锁后可读")
    func 可访问性() throws {
        let service = "cc.space01.smfa.tests.\(UUID().uuidString)"
        let store = KeychainAccountStore(service: service)
        try store.save([makeAccount(name: "a@x.com")])

        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecReturnAttributes: true,
        ] as CFDictionary, &result)

        #expect(status == errSecSuccess)
        let attributes = try #require(result as? [String: Any])
        #expect(attributes[kSecAttrAccessible as String] as? String
                == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        try store.removeAll()
    }
}
