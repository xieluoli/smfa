import CommonCrypto
import CryptoKit
import Foundation

public enum BackupError: Error, Equatable {
    case emptyAccounts
    case weakPassword
    case decryptionFailed
    case unsupportedVersion(Int)
    case malformedFile
}

/// `.smfa` 备份文件的编解码。
///
/// 外层是明文 JSON（版本与算法元信息可读，便于将来兼容处理），账号本体整体加密：
/// 用户密码经 PBKDF2-HMAC-SHA256 派生出 256 位密钥，再用 AES-GCM 加密。
/// GCM 自带认证标签，密文或元信息被改动都会解密失败，正好满足"篡改必须报错"。
public enum BackupCodec {

    public static let currentVersion = 1
    public static let minimumPasswordLength = 8
    private static let iterations = 210_000   // OWASP 2023 对 PBKDF2-HMAC-SHA256 的推荐值
    private static let saltLength = 16

    private struct Payload: Codable {
        let accounts: [MFAAccount]
    }

    private struct BackupFile: Codable {
        struct KDF: Codable {
            let algorithm: String
            let iterations: Int
            let salt: String
        }
        struct Cipher: Codable {
            let algorithm: String
            let nonce: String
            let ciphertext: String
        }
        let version: Int
        let app: String
        let createdAt: Date
        let kdf: KDF
        let cipher: Cipher
    }

    public static func export(accounts: [MFAAccount], password: String,
                              createdAt: Date) throws -> Data {
        guard !accounts.isEmpty else { throw BackupError.emptyAccounts }
        guard password.count >= minimumPasswordLength else { throw BackupError.weakPassword }

        let salt = randomBytes(count: saltLength)
        let key = try deriveKey(password: password, salt: salt, iterations: iterations)
        let plaintext = try jsonEncoder.encode(Payload(accounts: accounts))
        let sealed = try AES.GCM.seal(plaintext, using: key)

        // ciphertext 用 combined 减去 nonce 部分，即密文 + 16 字节认证标签。
        let file = BackupFile(
            version: currentVersion,
            app: "S-MFA",
            createdAt: createdAt,
            kdf: .init(algorithm: "PBKDF2-HMAC-SHA256", iterations: iterations,
                       salt: salt.base64EncodedString()),
            cipher: .init(algorithm: "AES-256-GCM",
                          nonce: Data(sealed.nonce).base64EncodedString(),
                          ciphertext: (sealed.ciphertext + sealed.tag).base64EncodedString())
        )
        return try jsonEncoder.encode(file)
    }

    public static func `import`(data: Data, password: String) throws -> [MFAAccount] {
        guard let file = try? jsonDecoder.decode(BackupFile.self, from: data) else {
            throw BackupError.malformedFile
        }
        guard file.version <= currentVersion else {
            throw BackupError.unsupportedVersion(file.version)
        }
        guard let salt = Data(base64Encoded: file.kdf.salt),
              let nonceData = Data(base64Encoded: file.cipher.nonce),
              let ciphertext = Data(base64Encoded: file.cipher.ciphertext) else {
            throw BackupError.malformedFile
        }

        let key = try deriveKey(password: password, salt: salt, iterations: file.kdf.iterations)
        guard let nonce = try? AES.GCM.Nonce(data: nonceData),
              let box = try? AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext.dropLast(16),
                                               tag: ciphertext.suffix(16)),
              let plaintext = try? AES.GCM.open(box, using: key),
              let payload = try? jsonDecoder.decode(Payload.self, from: plaintext) else {
            throw BackupError.decryptionFailed
        }
        return payload.accounts
    }

    private static func deriveKey(password: String, salt: Data,
                                  iterations: Int) throws -> SymmetricKey {
        var derived = Data(count: 32)
        let passwordBytes = Array(password.utf8)
        let status = derived.withUnsafeMutableBytes { derivedBuffer in
            salt.withUnsafeBytes { saltBuffer in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes, passwordBytes.count,
                    saltBuffer.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    derivedBuffer.bindMemory(to: UInt8.self).baseAddress, 32
                )
            }
        }
        guard status == kCCSuccess else { throw BackupError.malformedFile }
        return SymmetricKey(data: derived)
    }

    private static func randomBytes(count: Int) -> Data {
        var bytes = Data(count: count)
        _ = bytes.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!)
        }
        return bytes
    }

    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
