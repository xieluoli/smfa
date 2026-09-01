import Foundation
import Testing
@testable import SMFACore

@Suite("otpauth URI 解析")
struct OTPAuthURITests {

    private let fixedID = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func parse(_ uri: String) throws -> MFAAccount {
        try OTPAuthURI.parse(uri, id: fixedID, createdAt: fixedDate)
    }

    @Test("解析带发行方前缀的标准 URI")
    func 标准URI() throws {
        let account = try parse(
            "otpauth://totp/Gitee:user@x.com?secret=JBSWY3DPEHPK3PXP&issuer=Gitee&algorithm=SHA256&digits=8&period=60"
        )
        #expect(account.issuer == "Gitee")
        #expect(account.name == "user@x.com")
        #expect(account.secret == "JBSWY3DPEHPK3PXP")
        #expect(account.algorithm == .sha256)
        #expect(account.digits == 8)
        #expect(account.period == 60)
        #expect(account.id == fixedID)
        #expect(account.createdAt == fixedDate)
    }

    @Test("缺失参数时取默认值")
    func 默认值() throws {
        let account = try parse("otpauth://totp/user@x.com?secret=JBSWY3DPEHPK3PXP")
        #expect(account.issuer == "")
        #expect(account.name == "user@x.com")
        #expect(account.algorithm == .sha1)
        #expect(account.digits == 6)
        #expect(account.period == 30)
    }

    @Test("label 中的百分号编码被还原")
    func URL编码() throws {
        let account = try parse(
            "otpauth://totp/ACME%20Co:john%40example.com?secret=JBSWY3DPEHPK3PXP&issuer=ACME%20Co"
        )
        #expect(account.issuer == "ACME Co")
        #expect(account.name == "john@example.com")
    }

    @Test("issuer 参数优先于 label 前缀")
    func issuer冲突() throws {
        let account = try parse(
            "otpauth://totp/Old:user@x.com?secret=JBSWY3DPEHPK3PXP&issuer=New"
        )
        #expect(account.issuer == "New")
        #expect(account.name == "user@x.com")
    }

    @Test("拒绝非 totp 类型")
    func 非totp() {
        #expect(throws: OTPAuthURIError.unsupportedType) {
            try parse("otpauth://hotp/user?secret=JBSWY3DPEHPK3PXP&counter=1")
        }
    }

    @Test("拒绝非 otpauth scheme")
    func 非otpauth() {
        #expect(throws: OTPAuthURIError.unsupportedType) {
            try parse("https://example.com/totp/user?secret=JBSWY3DPEHPK3PXP")
        }
    }

    @Test("拒绝缺少 secret")
    func 缺secret() {
        #expect(throws: OTPAuthURIError.missingSecret) {
            try parse("otpauth://totp/user@x.com?issuer=Gitee")
        }
    }

    @Test("拒绝非法 Base32 密钥")
    func 非法密钥() {
        #expect(throws: OTPAuthURIError.invalidSecret) {
            try parse("otpauth://totp/user@x.com?secret=JBSW1111")
        }
    }

    @Test("拒绝不支持的位数与周期", arguments: [
        "otpauth://totp/u?secret=JBSWY3DPEHPK3PXP&digits=4",
        "otpauth://totp/u?secret=JBSWY3DPEHPK3PXP&digits=9",
        "otpauth://totp/u?secret=JBSWY3DPEHPK3PXP&period=0",
    ])
    func 非法参数(uri: String) {
        #expect(throws: OTPAuthURIError.invalidParameter) {
            try parse(uri)
        }
    }

    @Test("拒绝空账号名")
    func 空账号名() {
        #expect(throws: OTPAuthURIError.missingAccountName) {
            try parse("otpauth://totp/?secret=JBSWY3DPEHPK3PXP")
        }
    }
}

@Suite("MFAAccount 模型")
struct MFAAccountTests {

    private func account(issuer: String, name: String, secret: String) -> MFAAccount {
        MFAAccount(id: UUID(), issuer: issuer, name: name, secret: secret,
                   algorithm: .sha1, digits: 6, period: 30, createdAt: Date())
    }

    @Test("有发行方时展示名为 发行方:账号")
    func 展示名带发行方() {
        #expect(account(issuer: "Gitee", name: "u@x.com", secret: "JBSWY3DPEHPK3PXP").displayName
                == "Gitee:u@x.com")
    }

    @Test("无发行方时展示名即账号名")
    func 展示名无发行方() {
        #expect(account(issuer: "", name: "u@x.com", secret: "JBSWY3DPEHPK3PXP").displayName
                == "u@x.com")
    }

    @Test("去重键由发行方、账号名、密钥共同决定")
    func 去重键() {
        let base = account(issuer: "Gitee", name: "u@x.com", secret: "JBSWY3DPEHPK3PXP")
        let sameContent = account(issuer: "Gitee", name: "u@x.com", secret: "JBSWY3DPEHPK3PXP")
        let otherSecret = account(issuer: "Gitee", name: "u@x.com", secret: "MZXW6YTBOI======")
        #expect(base.dedupeKey == sameContent.dedupeKey)
        #expect(base.dedupeKey != otherSecret.dedupeKey)
    }
}
