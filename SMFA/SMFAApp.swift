import SwiftUI

@main
struct SMFAApp: App {

    init() {
        // UI 测试专用：模拟器的 Keychain 不随 App 卸载清除，不重置的话上一轮账号会带进下一轮。
        if CommandLine.arguments.contains("--reset-store-for-uitest") {
            try? KeychainAccountStore().removeAll()
        }
    }

    var body: some Scene {
        WindowGroup {
            AccountListView()
        }
    }
}
