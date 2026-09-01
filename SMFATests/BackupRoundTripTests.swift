import Foundation
import Testing
import SMFACore
@testable import SMFA

/// 备份导出到导入的完整往返：真实账号 → 加密文件 → 解密 → 合并回列表。
/// 系统「文件」面板不参与，那一层只是把 Data 交给 fileExporter。
@MainActor
@Suite("备份往返", .serialized)
struct BackupRoundTripTests {

    private func makeViewModel() -> AccountListViewModel {
        AccountListViewModel(
            store: KeychainAccountStore(service: "cn.smfa.tests.\(UUID().uuidString)")
        )
    }

    private func makeAccount(name: String, secret: String) -> MFAAccount {
        MFAAccount(id: UUID(), issuer: "Gitee", name: name, secret: secret,
                   algorithm: .sha1, digits: 6, period: 30,
                   createdAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test("换设备场景：导出后在空列表上还原，口令与原设备一致")
    func 换设备还原() throws {
        let source = makeViewModel()
        try source.add(makeAccount(name: "a@x.com", secret: "JBSWY3DPEHPK3PXP"))
        try source.add(makeAccount(name: "b@x.com", secret: "MZXW6YTBOI"))

        let backup = try BackupCodec.export(accounts: source.accounts,
                                            password: "my-backup-pass", createdAt: Date())

        let target = makeViewModel()
        let result = try target.merge(BackupCodec.import(data: backup,
                                                         password: "my-backup-pass"))

        #expect(result.added == 2)
        #expect(result.skipped == 0)

        // 同一时刻两台"设备"应生成完全相同的口令
        let checkTime = Date(timeIntervalSince1970: 1_234_567_890)
        source.now = checkTime
        target.now = checkTime
        for account in source.accounts {
            #expect(source.code(for: account) == target.code(for: account))
        }
    }

    @Test("重复导入同一份备份不会产生副本")
    func 重复导入() throws {
        let viewModel = makeViewModel()
        try viewModel.add(makeAccount(name: "a@x.com", secret: "JBSWY3DPEHPK3PXP"))

        let backup = try BackupCodec.export(accounts: viewModel.accounts,
                                            password: "my-backup-pass", createdAt: Date())
        let first = try viewModel.merge(BackupCodec.import(data: backup, password: "my-backup-pass"))
        let second = try viewModel.merge(BackupCodec.import(data: backup, password: "my-backup-pass"))

        #expect(first.added == 0)
        #expect(second.added == 0)
        #expect(viewModel.accounts.count == 1)
    }

    @Test("错误密码不会写入任何账号")
    func 错误密码不落库() throws {
        let source = makeViewModel()
        try source.add(makeAccount(name: "a@x.com", secret: "JBSWY3DPEHPK3PXP"))
        let backup = try BackupCodec.export(accounts: source.accounts,
                                            password: "right-password", createdAt: Date())

        let target = makeViewModel()
        #expect(throws: BackupError.decryptionFailed) {
            _ = try target.merge(BackupCodec.import(data: backup, password: "wrong-password"))
        }
        #expect(target.accounts.isEmpty)
    }
}
