import Foundation
import Testing
@testable import SMFACore

@Suite("TOTP 口令生成")
struct TOTPGeneratorTests {

    // RFC 6238 Appendix B 官方测试向量。密钥是 ASCII 明文，按算法长度截取/重复。
    private static let sha1Secret = Data("12345678901234567890".utf8)
    private static let sha256Secret = Data("12345678901234567890123456789012".utf8)
    private static let sha512Secret = Data("1234567890123456789012345678901234567890123456789012345678901234".utf8)

    @Test("RFC 6238 SHA1 向量", arguments: [
        (59, "94287082"),
        (1_111_111_109, "07081804"),
        (1_111_111_111, "14050471"),
        (1_234_567_890, "89005924"),
        (2_000_000_000, "69279037"),
        (20_000_000_000, "65353130"),
    ])
    func sha1向量(seconds: Int, expected: String) {
        let code = TOTPGenerator.code(
            secret: Self.sha1Secret,
            at: Date(timeIntervalSince1970: TimeInterval(seconds)),
            algorithm: .sha1, digits: 8, period: 30
        )
        #expect(code == expected)
    }

    @Test("RFC 6238 SHA256 向量", arguments: [
        (59, "46119246"),
        (1_111_111_109, "68084774"),
        (1_234_567_890, "91819424"),
        (20_000_000_000, "77737706"),
    ])
    func sha256向量(seconds: Int, expected: String) {
        let code = TOTPGenerator.code(
            secret: Self.sha256Secret,
            at: Date(timeIntervalSince1970: TimeInterval(seconds)),
            algorithm: .sha256, digits: 8, period: 30
        )
        #expect(code == expected)
    }

    @Test("RFC 6238 SHA512 向量", arguments: [
        (59, "90693936"),
        (1_111_111_109, "25091201"),
        (1_234_567_890, "93441116"),
        (20_000_000_000, "47863826"),
    ])
    func sha512向量(seconds: Int, expected: String) {
        let code = TOTPGenerator.code(
            secret: Self.sha512Secret,
            at: Date(timeIntervalSince1970: TimeInterval(seconds)),
            algorithm: .sha512, digits: 8, period: 30
        )
        #expect(code == expected)
    }

    @Test("6 位口令取 8 位口令的后 6 位")
    func 六位口令() {
        let code = TOTPGenerator.code(
            secret: Self.sha1Secret,
            at: Date(timeIntervalSince1970: 59),
            algorithm: .sha1, digits: 6, period: 30
        )
        #expect(code == "287082")
    }

    @Test("同一周期内口令稳定")
    func 同周期稳定() {
        let atStart = TOTPGenerator.code(
            secret: Self.sha1Secret, at: Date(timeIntervalSince1970: 60),
            algorithm: .sha1, digits: 6, period: 30
        )
        let atEnd = TOTPGenerator.code(
            secret: Self.sha1Secret, at: Date(timeIntervalSince1970: 89),
            algorithm: .sha1, digits: 6, period: 30
        )
        #expect(atStart == atEnd)
    }

    @Test("跨周期口令翻转")
    func 跨周期翻转() {
        let before = TOTPGenerator.code(
            secret: Self.sha1Secret, at: Date(timeIntervalSince1970: 89),
            algorithm: .sha1, digits: 6, period: 30
        )
        let after = TOTPGenerator.code(
            secret: Self.sha1Secret, at: Date(timeIntervalSince1970: 90),
            algorithm: .sha1, digits: 6, period: 30
        )
        #expect(before != after)
    }

    @Test("剩余秒数随周期递减", arguments: [
        (60, 30), (61, 29), (89, 1), (90, 30),
    ])
    func 剩余秒数(seconds: Int, expected: Int) {
        let remaining = TOTPGenerator.remainingSeconds(
            at: Date(timeIntervalSince1970: TimeInterval(seconds)), period: 30
        )
        #expect(remaining == expected)
    }

    @Test("口令不足位数时左侧补零")
    func 补零() {
        // 该密钥/时间组合的 8 位口令为 07081804，取 6 位后首位为 0，必须保留
        let code = TOTPGenerator.code(
            secret: Self.sha1Secret,
            at: Date(timeIntervalSince1970: 1_111_111_109),
            algorithm: .sha1, digits: 8, period: 30
        )
        #expect(code.count == 8)
        #expect(code.hasPrefix("0"))
    }
}
