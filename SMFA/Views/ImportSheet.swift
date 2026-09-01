import SMFACore
import SwiftUI

/// 输入密码解密已选中的备份文件。
struct ImportSheet: View {

    let backupData: Data
    let onImport: ([MFAAccount]) throws -> (added: Int, skipped: Int)

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("备份密码", text: $password)
                } header: {
                    Text("请输入创建这份备份时设置的密码")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                Section {
                    Button("导入", action: submit)
                        .disabled(password.isEmpty)
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("导入备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func submit() {
        do {
            let accounts = try BackupCodec.import(data: backupData, password: password)
            _ = try onImport(accounts)
            dismiss()
        } catch BackupError.decryptionFailed {
            errorMessage = "密码错误，或备份文件已损坏。"
        } catch let BackupError.unsupportedVersion(version) {
            errorMessage = "这份备份来自更新的版本（v\(version)），请先升级 App。"
        } catch BackupError.malformedFile {
            errorMessage = "这不是一份有效的备份文件。"
        } catch {
            errorMessage = "导入失败：\(error.localizedDescription)"
        }
    }
}
