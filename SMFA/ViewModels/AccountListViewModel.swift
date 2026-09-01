import Foundation
import SMFACore

enum AccountListError: Error, Equatable {
    case duplicate
}

@MainActor
@Observable
final class AccountListViewModel {

    /// 密钥解不开时列表里显示的占位串，避免一个坏账号让整页崩掉。
    static let invalidCodePlaceholder = "------"

    var accounts: [MFAAccount] = []
    var searchText: String = ""

    /// 所有行共用的时间基准。界面只有一个每秒 tick 的定时器推进它，
    /// 这样全列表的口令和进度条严格同步，测试也能把时间钉死。
    var now: Date = Date()

    private let store: KeychainAccountStore

    init(store: KeychainAccountStore = KeychainAccountStore()) {
        self.store = store
        accounts = (try? store.load()) ?? []
        sortAccounts()
    }

    var filteredAccounts: [MFAAccount] {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return accounts }
        return accounts.filter {
            $0.name.localizedCaseInsensitiveContains(keyword)
                || $0.issuer.localizedCaseInsensitiveContains(keyword)
        }
    }

    func add(_ account: MFAAccount) throws {
        guard !accounts.contains(where: { $0.dedupeKey == account.dedupeKey }) else {
            throw AccountListError.duplicate
        }
        accounts.append(account)
        sortAccounts()
        try store.save(accounts)
    }

    func rename(_ account: MFAAccount, to newName: String) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[index].name = trimmed
        try store.save(accounts)
    }

    func delete(_ account: MFAAccount) throws {
        accounts.removeAll { $0.id == account.id }
        try store.save(accounts)
    }

    /// 导入是合并而不是覆盖：已存在的跳过，避免误操作抹掉本机账号。
    func merge(_ imported: [MFAAccount]) throws -> (added: Int, skipped: Int) {
        var existingKeys = Set(accounts.map(\.dedupeKey))
        var added = 0

        for account in imported where existingKeys.insert(account.dedupeKey).inserted {
            accounts.append(account)
            added += 1
        }
        sortAccounts()
        try store.save(accounts)
        return (added, imported.count - added)
    }

    func code(for account: MFAAccount) -> String {
        guard let secret = try? Base32.decode(account.secret), !secret.isEmpty else {
            return Self.invalidCodePlaceholder
        }
        return TOTPGenerator.code(secret: secret, at: now, algorithm: account.algorithm,
                                  digits: account.digits, period: account.period)
    }

    func remainingSeconds(for account: MFAAccount) -> Int {
        TOTPGenerator.remainingSeconds(at: now, period: account.period)
    }

    private func sortAccounts() {
        accounts.sort { $0.createdAt > $1.createdAt }
    }
}
