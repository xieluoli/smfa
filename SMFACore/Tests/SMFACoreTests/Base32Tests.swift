import Foundation
import Testing
@testable import SMFACore

@Suite("Base32 解码")
struct Base32Tests {

    // RFC 4648 第 10 节官方测试向量
    @Test("RFC 4648 官方向量", arguments: [
        ("", ""),
        ("MY======", "f"),
        ("MZXQ====", "fo"),
        ("MZXW6===", "foo"),
        ("MZXW6YQ=", "foob"),
        ("MZXW6YTB", "fooba"),
        ("MZXW6YTBOI======", "foobar"),
    ])
    func rfc4648向量(input: String, expected: String) throws {
        let decoded = try Base32.decode(input)
        #expect(String(data: decoded, encoding: .utf8) == expected)
    }

    @Test("忽略大小写、空格与填充")
    func 宽松输入() throws {
        let expected = Data("Hello!".utf8) + Data([0xDE, 0xAD, 0xBE, 0xEF])
        #expect(try Base32.decode("jbsw y3dp ehpk 3pxp") == expected)
        #expect(try Base32.decode("JBSWY3DPEHPK3PXP") == expected)
        #expect(try Base32.decode("JBSWY3DP EHPK3PXP======") == expected)
    }

    @Test("拒绝字母表以外的字符", arguments: ["JBSW1234", "JBSW8YTB", "JBSW0YTB", "JBSW-YTB"])
    func 非法字符(input: String) {
        #expect(throws: Base32Error.invalidCharacter) {
            try Base32.decode(input)
        }
    }

    @Test("拒绝长度不合法的输入")
    func 长度非法() {
        // 单个字符只有 5 bit，凑不满一个字节
        #expect(throws: Base32Error.invalidLength) {
            try Base32.decode("M")
        }
    }
}
