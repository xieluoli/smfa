import CryptoKit
import Foundation

public enum TOTPAlgorithm: String, Codable, Sendable, CaseIterable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"
}

/// RFC 6238 TOTP。时间通过参数注入，便于用官方测试向量钉死行为，也便于界面统一驱动刷新。
public enum TOTPGenerator {
    public static func code(secret: Data, at date: Date,
                            algorithm: TOTPAlgorithm, digits: Int, period: Int) -> String {
        let counter = UInt64(floor(date.timeIntervalSince1970 / Double(period)))
        let message = withUnsafeBytes(of: counter.bigEndian) { Data($0) }
        let digest = authenticationCode(for: message, secret: secret, algorithm: algorithm)

        // RFC 4226 动态截断：用摘要最后一字节的低 4 位作为偏移量，从该处取 4 字节。
        let offset = Int(digest[digest.count - 1] & 0x0F)
        let truncated = digest[offset..<(offset + 4)].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        let value = (truncated & 0x7FFF_FFFF) % pow10(digits)

        return String(format: "%0\(digits)u", value)
    }

    public static func remainingSeconds(at date: Date, period: Int) -> Int {
        period - Int(date.timeIntervalSince1970.rounded(.down)) % period
    }

    private static func authenticationCode(for message: Data, secret: Data,
                                           algorithm: TOTPAlgorithm) -> Data {
        let key = SymmetricKey(data: secret)
        switch algorithm {
        case .sha1:
            return Data(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key))
        case .sha256:
            return Data(HMAC<SHA256>.authenticationCode(for: message, using: key))
        case .sha512:
            return Data(HMAC<SHA512>.authenticationCode(for: message, using: key))
        }
    }

    private static func pow10(_ exponent: Int) -> UInt32 {
        (0..<exponent).reduce(UInt32(1)) { product, _ in product * 10 }
    }
}
