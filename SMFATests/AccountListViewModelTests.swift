import Foundation
import Testing
import SMFACore
@testable import SMFA

@MainActor
@Suite("账号列表视图模型", .serialized)
struct AccountListViewModelTests {

    private func makeViewModel() -> AccountListViewModel {
        AccountListViewModel(
            store: KeychainAccountStore(service: "cn.smfa.tests.\(UUID().uuidString)")
        )
    }

    private func makeAccount(issuer: String = "Gitee", name: String,
                             secret: String = "JBSWY3DPEHPK3PXP") -> MFAAccount {
        MFAAccount(id: UUID(), issuer: issuer, name: name, secret: secret,
                   algorithm: .sha1, digits: 6, period: 30,
                   createdAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test("添加后进入列表并写入存储")
    func 添加并持久化() throws {
        let store = KeychainAccountStore(service: "cn.smfa.tests.\(UUID().uuidString)")
        let viewModel = AccountListViewModel(store: store)
        try viewModel.add(makeAccount(name: "a@x.com"))

        #expect(viewModel.accounts.count == 1)
        #expect(try store.load().first?.name == "a@x.com")
        try store.removeAll()
    }

    @Test("重复账号拒绝添加")
    func 拒绝重复() throws {
        let viewModel = makeViewModel()
        let account = makeAccount(name: "a@x.com")
        try viewModel.add(account)

        #expect(throws: AccountListError.duplicate) {
            // 换一个 id 但内容相同，仍应判定为重复
            try viewModel.add(self.makeAccount(name: "a@x.com"))
        }
        #expect(viewModel.accounts.count == 1)
    }

    @Test("按关键词过滤，忽略大小写")
    func 搜索过滤() throws {
        let viewModel = makeViewModel()
        try viewModel.add(makeAccount(issuer: "Gitee", name: "u@x.com"))
        try viewModel.add(makeAccount(issuer: "Google", name: "me@y.com", secret: "MZXW6YTBOI"))

        viewModel.searchText = "goo"
        #expect(viewModel.filteredAccounts.map(\.issuer) == ["Google"])

        viewModel.searchText = "U@X"
        #expect(viewModel.filteredAccounts.map(\.name) == ["u@x.com"])

        viewModel.searchText = ""
        #expect(viewModel.filteredAccounts.count == 2)
    }

    @Test("删除账号")
    func 删除() throws {
        let viewModel = makeViewModel()
        let account = makeAccount(name: "a@x.com")
        try viewModel.add(account)
        try viewModel.delete(account)
        #expect(viewModel.accounts.isEmpty)
    }

    @Test("重命名账号并持久化")
    func 重命名() throws {
        let store = KeychainAccountStore(service: "cn.smfa.tests.\(UUID().uuidString)")
        let viewModel = AccountListViewModel(store: store)
        let account = makeAccount(name: "old@x.com")
        try viewModel.add(account)

        try viewModel.rename(account, to: "  new@x.com  ")

        #expect(viewModel.accounts.first?.name == "new@x.com")
        #expect(try store.load().first?.name == "new@x.com")
        try store.removeAll()
    }

    @Test("重命名为空白时保持原名")
    func 重命名空白() throws {
        let viewModel = makeViewModel()
        let account = makeAccount(name: "old@x.com")
        try viewModel.add(account)

        try viewModel.rename(account, to: "   ")
        #expect(viewModel.accounts.first?.name == "old@x.com")
    }

    @Test("导入合并：新增与跳过分别计数")
    func 导入合并() throws {
        let viewModel = makeViewModel()
        let existing = makeAccount(name: "a@x.com")
        try viewModel.add(existing)

        let result = try viewModel.merge([
            existing,
            makeAccount(name: "b@x.com", secret: "MZXW6YTBOI"),
            makeAccount(name: "c@x.com", secret: "MZXW6YTBOI"),
        ])

        #expect(result.added == 2)
        #expect(result.skipped == 1)
        #expect(viewModel.accounts.count == 3)
    }

    @Test("导入内部重复只算一次")
    func 导入内部去重() throws {
        let viewModel = makeViewModel()
        let duplicated = makeAccount(name: "dup@x.com")
        let result = try viewModel.merge([duplicated, duplicated])

        #expect(result.added == 1)
        #expect(result.skipped == 1)
    }

    @Test("列表按添加时间倒序，新账号在最前")
    func 排序() throws {
        let viewModel = makeViewModel()
        let older = MFAAccount(id: UUID(), issuer: "A", name: "old", secret: "JBSWY3DPEHPK3PXP",
                               algorithm: .sha1, digits: 6, period: 30,
                               createdAt: Date(timeIntervalSince1970: 1_000))
        let newer = MFAAccount(id: UUID(), issuer: "B", name: "new", secret: "MZXW6YTBOI",
                               algorithm: .sha1, digits: 6, period: 30,
                               createdAt: Date(timeIntervalSince1970: 2_000))
        try viewModel.add(older)
        try viewModel.add(newer)
        #expect(viewModel.accounts.map(\.name) == ["new", "old"])
    }

    @Test("按当前时间生成口令与剩余秒数")
    func 口令与倒计时() throws {
        let viewModel = makeViewModel()
        // RFC 6238 SHA1 向量：时间 59 秒对应 8 位口令 94287082
        let account = MFAAccount(id: UUID(), issuer: "", name: "rfc",
                                 secret: "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ",
                                 algorithm: .sha1, digits: 8, period: 30,
                                 createdAt: Date(timeIntervalSince1970: 0))
        try viewModel.add(account)
        viewModel.now = Date(timeIntervalSince1970: 59)

        #expect(viewModel.code(for: account) == "94287082")
        #expect(viewModel.remainingSeconds(for: account) == 1)
    }

    @Test("密钥非法时口令显示为占位符")
    func 非法密钥占位() throws {
        let viewModel = makeViewModel()
        let broken = makeAccount(name: "broken", secret: "11111111")
        viewModel.accounts = [broken]
        #expect(viewModel.code(for: broken) == "------")
    }
}
