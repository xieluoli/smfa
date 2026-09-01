import Foundation
import Testing
@testable import SMFACore

@Suite("备份加密与解密")
struct BackupCodecTests {

    private let exportedAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let password = "correct horse"

    private var sampleAccounts: [MFAAccount] {
        [
            MFAAccount(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!,
                       issuer: "Gitee", name: "u@x.com", secret: "JBSWY3DPEHPK3PXP",
                       algorithm: .sha1, digits: 6, period: 30,
                       createdAt: Date(timeIntervalSince1970: 1_600_000_000)),
            MFAAccount(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!,
                       issuer: "", name: "solo", secret: "MZXW6YTBOI",
                       algorithm: .sha512, digits: 8, period: 60,
                       createdAt: Date(timeIntervalSince1970: 1_650_000_000)),
        ]
    }

    private func export(_ accounts: [MFAAccount]? = nil, password: String? = nil) throws -> Data {
        try BackupCodec.export(accounts: accounts ?? sampleAccounts,
                               password: password ?? self.password,
                               createdAt: exportedAt)
    }

    @Test("导出文件中不含任何明文密钥")
    func 密钥不落明文() throws {
        let data = try export()
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("JBSWY3DPEHPK3PXP"))
        #expect(!text.contains("MZXW6YTBOI"))
        // 账号名同样属于隐私，不应出现在密文之外
        #expect(!text.contains("u@x.com"))
    }

    @Test("导出文件带可读的版本与算法元信息")
    func 元信息可读() throws {
        let json = try #require(
            try JSONSerialization.jsonObject(with: export()) as? [String: Any]
        )
        #expect(json["version"] as? Int == 1)
        #expect(json["app"] as? String == "S-MFA")
        let kdf = try #require(json["kdf"] as? [String: Any])
        #expect(kdf["algorithm"] as? String == "PBKDF2-HMAC-SHA256")
        #expect(kdf["iterations"] as? Int == 210_000)
        let cipher = try #require(json["cipher"] as? [String: Any])
        #expect(cipher["algorithm"] as? String == "AES-256-GCM")
    }

    @Test("拒绝过短的备份密码", arguments: ["", "1234567"])
    func 密码过短(weak: String) {
        #expect(throws: BackupError.weakPassword) {
            try export(password: weak)
        }
    }

    @Test("恰好 8 位的密码可以导出")
    func 密码长度下限() throws {
        #expect(throws: Never.self) {
            try export(password: "12345678")
        }
    }

    @Test("拒绝导出空账号列表")
    func 空列表不导出() {
        #expect(throws: BackupError.emptyAccounts) {
            try export([])
        }
    }

    @Test("正确密码往返后账号完全一致")
    func 往返一致() throws {
        let restored = try BackupCodec.import(data: try export(), password: password)
        #expect(restored == sampleAccounts)
    }

    @Test("每次导出使用不同的盐与随机数")
    func 盐随机() throws {
        #expect(try export() != export())
    }

    @Test("错误密码解密失败")
    func 错误密码() throws {
        let data = try export()
        #expect(throws: BackupError.decryptionFailed) {
            try BackupCodec.import(data: data, password: "wrong password")
        }
    }

    @Test("密文被篡改后解密失败")
    func 密文篡改() throws {
        var json = try #require(
            try JSONSerialization.jsonObject(with: try export()) as? [String: Any]
        )
        var cipher = try #require(json["cipher"] as? [String: Any])
        let encodedCiphertext = try #require(cipher["ciphertext"] as? String)
        let original = try #require(Data(base64Encoded: encodedCiphertext))
        var tampered = original
        tampered[0] ^= 0xFF
        cipher["ciphertext"] = tampered.base64EncodedString()
        json["cipher"] = cipher

        let data = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: BackupError.decryptionFailed) {
            try BackupCodec.import(data: data, password: password)
        }
    }

    @Test("版本高于支持范围时明确报错")
    func 版本过高() throws {
        var json = try #require(
            try JSONSerialization.jsonObject(with: try export()) as? [String: Any]
        )
        json["version"] = 99
        let data = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: BackupError.unsupportedVersion(99)) {
            try BackupCodec.import(data: data, password: password)
        }
    }

    @Test("非备份文件报格式错误")
    func 文件格式错误() {
        #expect(throws: BackupError.malformedFile) {
            try BackupCodec.import(data: Data("这不是备份文件".utf8), password: password)
        }
    }
}
