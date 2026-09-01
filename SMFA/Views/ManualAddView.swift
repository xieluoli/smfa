import SMFACore
import SwiftUI

/// 手动添加账号：站点不提供二维码、或不方便扫码时用。
struct ManualAddView: View {

    let onAdd: (MFAAccount) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var secret = ""
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !secret.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("请填写", text: $name)
                        .accessibilityIdentifier("accountNameField")
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("账号")
                }

                Section {
                    TextField("请从网站复制密钥并在此处粘贴", text: $secret, axis: .vertical)
                        .accessibilityIdentifier("secretField")
                        .lineLimit(3...6)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Text("密钥")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("添加账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定", action: submit).disabled(!canSubmit)
                }
            }
        }
    }

    private func submit() {
        let trimmedSecret = secret.trimmingCharacters(in: .whitespaces)
        guard let decoded = try? Base32.decode(trimmedSecret), !decoded.isEmpty else {
            errorMessage = "密钥格式不正确，请确认是网站给出的 Base32 密钥。"
            return
        }

        let account = MFAAccount(
            id: UUID(),
            issuer: "",
            name: name.trimmingCharacters(in: .whitespaces),
            secret: trimmedSecret.uppercased(),
            algorithm: .sha1, digits: 6, period: 30,
            createdAt: Date()
        )

        do {
            try onAdd(account)
            dismiss()
        } catch AccountListError.duplicate {
            errorMessage = "该账号已存在，无需重复添加。"
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
    }
}
