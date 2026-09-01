import SMFACore
import SwiftUI

/// 单个账号卡片：账号名、添加时间、大字号口令，底部一条随剩余时间收缩的进度条。
struct AccountRowView: View {

    let account: MFAAccount
    let code: String
    let remainingSeconds: Int
    let onCopy: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    /// 进入最后 5 秒时转为警示色，提示用户这一轮口令快过期了。
    private var progressColor: Color {
        remainingSeconds <= 5 ? .red : .green
    }

    private var progress: Double {
        Double(remainingSeconds) / Double(account.period)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.displayName)
                        .font(.headline)
                    Text("添加时间：\(Self.dateFormatter.string(from: account.createdAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("重命名", systemImage: "pencil", action: onRename)
                        .accessibilityIdentifier("rowRename")
                    Button("删除", systemImage: "trash", role: .destructive, action: onDelete)
                        .accessibilityIdentifier("rowDelete")
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 32, alignment: .trailing)
                        .contentShape(.rect)
                }
                .accessibilityLabel("更多操作")
                .accessibilityIdentifier("rowMenu")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Text(code)
                .font(.system(size: 44, weight: .regular))
                .monospacedDigit()
                .accessibilityLabel("动态口令 \(code)，剩余 \(remainingSeconds) 秒")
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geometry in
                Rectangle()
                    .fill(progressColor)
                    .frame(width: geometry.size.width * progress)
                    .animation(.linear(duration: 0.25), value: remainingSeconds)
            }
            .frame(height: 3)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .contentShape(.rect)
        .onTapGesture(perform: onCopy)
        .accessibilityElement(children: .contain)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
