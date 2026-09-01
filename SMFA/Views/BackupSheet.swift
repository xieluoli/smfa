import SMFACore
import SwiftUI

/// 设置备份密码并导出。密码只用于派生加密密钥，App 不保存它——忘了就解不开备份。
struct BackupSheet: View {

    let accounts: [MFAAccount]
    let onExport: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        password.count >= BackupCodec.minimumPasswordLength && !confirmation.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("""
                    误删账号、清理数据、换手机都会导致 MFA 丢失，建议尽早备份。

                    备份文件会用你设置的密码加密，只有输入同一个密码才能导入。密码不会保存在 App 里，也无法找回，请自行记牢。
                    """)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section {
                    SecureField("至少 \(BackupCodec.minimumPasswordLength) 位", text: $password)
                        .accessibilityIdentifier("backupPasswordField")
                    SecureField("再次输入", text: $confirmation)
                        .accessibilityIdentifier("backupConfirmationField")
                } header: {
                    Text("备份密码")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                Section {
                    Button("备份到「文件」", action: submit)
                        .disabled(!canSubmit)
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("备份 MFA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func submit() {
        guard password == confirmation else {
            errorMessage = "两次输入的密码不一致。"
            return
        }
        do {
            let data = try BackupCodec.export(accounts: accounts, password: password,
                                              createdAt: Date())
            onExport(data)
            dismiss()
        } catch BackupError.emptyAccounts {
            errorMessage = "还没有可备份的账号。"
        } catch BackupError.weakPassword {
            errorMessage = "密码至少需要 \(BackupCodec.minimumPasswordLength) 位。"
        } catch {
            errorMessage = "备份失败：\(error.localizedDescription)"
        }
    }
}
