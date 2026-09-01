import SMFACore
import SwiftUI

struct AccountListView: View {

    @State private var viewModel = AccountListViewModel()
    @State private var presentedSheet: Sheet?
    @State private var pendingDeletion: MFAAccount?
    @State private var renamingAccount: MFAAccount?
    @State private var renameText = ""
    @State private var exportDocument: BackupDocument?
    @State private var isImporterPresented = false
    @State private var toast: String?
    @State private var alertMessage: String?

    /// 整个列表共用一个每秒 tick 的时间源，所有卡片的口令与进度条因此严格同步。
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private enum Sheet: Identifiable {
        case scanner
        case manualAdd
        case backup
        case importBackup(Data)

        var id: String {
            switch self {
            case .scanner: "scanner"
            case .manualAdd: "manualAdd"
            case .backup: "backup"
            case .importBackup: "importBackup"
            }
        }
    }

    var body: some View {
        NavigationStack {
            content
                .background(Color(.systemGroupedBackground))
                .navigationTitle("S-MFA")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $viewModel.searchText,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: "搜索账号名称")
                .toolbar { toolbarContent }
        }
        .onReceive(ticker) { viewModel.now = $0 }
        .sheet(item: $presentedSheet, content: sheetContent)
        .fileExporter(
            isPresented: Binding(get: { exportDocument != nil },
                                 set: { if !$0 { exportDocument = nil } }),
            document: exportDocument,
            contentType: .mfaBackup,
            defaultFilename: "S-MFA-备份-\(Self.fileStampFormatter.string(from: Date()))"
        ) { result in
            if case .failure(let error) = result {
                alertMessage = "保存失败：\(error.localizedDescription)"
            } else {
                toast = "备份已保存"
            }
        }
        .fileImporter(isPresented: $isImporterPresented,
                      allowedContentTypes: [.mfaBackup]) { result in
            handleImportedFile(result)
        }
        .alert("删除账号",
               isPresented: Binding(get: { pendingDeletion != nil },
                                    set: { if !$0 { pendingDeletion = nil } })) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let account = pendingDeletion { perform { try viewModel.delete(account) } }
            }
        } message: {
            Text("删除后该账号的动态口令将无法再生成，且不可恢复。确定删除「\(pendingDeletion?.displayName ?? "")」吗？")
        }
        .alert("重命名",
               isPresented: Binding(get: { renamingAccount != nil },
                                    set: { if !$0 { renamingAccount = nil } })) {
            TextField("账号名称", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("保存") {
                if let account = renamingAccount {
                    perform { try viewModel.rename(account, to: renameText) }
                }
            }
        }
        .alert("出错了",
               isPresented: Binding(get: { alertMessage != nil },
                                    set: { if !$0 { alertMessage = nil } })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .overlay(alignment: .bottom) { toastView }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.accounts.isEmpty {
            ContentUnavailableView {
                Label("还没有 MFA 账号", systemImage: "lock.shield")
            } description: {
                Text("点击右上角「+」，扫描站点的二维码或手动填写密钥来添加第一个账号。")
            } actions: {
                Button("扫码添加") { presentedSheet = .scanner }
                    .accessibilityIdentifier("emptyStateScan")
                Button("手动添加") { presentedSheet = .manualAdd }
                    .accessibilityIdentifier("emptyStateManualAdd")
            }
        } else if viewModel.filteredAccounts.isEmpty {
            ContentUnavailableView.search(text: viewModel.searchText)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    hintBanner
                    ForEach(viewModel.filteredAccounts) { account in
                        AccountRowView(
                            account: account,
                            code: viewModel.code(for: account),
                            remainingSeconds: viewModel.remainingSeconds(for: account),
                            onCopy: { copy(account) },
                            onRename: {
                                renameText = account.name
                                renamingAccount = account
                            },
                            onDelete: { pendingDeletion = account }
                        )
                        .clipShape(.rect(cornerRadius: 12))
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.vertical, 12)
            }
        }
    }

    private var hintBanner: some View {
        Text("账号与密钥只保存在这台设备上，不会上传。误删、清数据或换手机都会导致丢失，建议尽早备份。")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.accentColor.opacity(0.12), in: .rect(cornerRadius: 12))
            .padding(.horizontal, 12)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("扫码添加", systemImage: "qrcode.viewfinder") { presentedSheet = .scanner }
                    .accessibilityIdentifier("menuScan")
                Button("手动添加", systemImage: "plus.square") { presentedSheet = .manualAdd }
                    .accessibilityIdentifier("menuManualAdd")
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityIdentifier("addMenu")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("备份 MFA", systemImage: "externaldrive.badge.timemachine") {
                    guard !viewModel.accounts.isEmpty else {
                        alertMessage = "还没有可备份的账号。"
                        return
                    }
                    presentedSheet = .backup
                }
                .accessibilityIdentifier("menuBackup")
                Button("导入备份", systemImage: "square.and.arrow.down") {
                    isImporterPresented = true
                }
                .accessibilityIdentifier("menuImport")
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityIdentifier("moreMenu")
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: Sheet) -> some View {
        switch sheet {
        case .scanner:
            ScannerView(onAdd: { try viewModel.add($0) },
                        onManualAdd: { presentedSheet = .manualAdd })
        case .manualAdd:
            ManualAddView(onAdd: { try viewModel.add($0) })
        case .backup:
            BackupSheet(accounts: viewModel.accounts) { data in
                exportDocument = BackupDocument(data: data)
            }
        case .importBackup(let data):
            ImportSheet(backupData: data) { imported in
                let result = try viewModel.merge(imported)
                toast = result.skipped == 0
                    ? "已导入 \(result.added) 个账号"
                    : "已导入 \(result.added) 个，跳过重复 \(result.skipped) 个"
                return result
            }
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.footnote)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: .capsule)
                .padding(.bottom, 24)
                .transition(.opacity)
                .task(id: toast) {
                    try? await Task.sleep(for: .seconds(2))
                    self.toast = nil
                }
        }
    }

    private func copy(_ account: MFAAccount) {
        let code = viewModel.code(for: account)
        guard code != AccountListViewModel.invalidCodePlaceholder else {
            alertMessage = "这个账号的密钥无法解析，请删除后重新添加。"
            return
        }
        UIPasteboard.general.string = code
        toast = "口令已复制"
    }

    private func handleImportedFile(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            // 「文件」返回的是沙箱外的地址，必须显式申请访问权限。
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                presentedSheet = .importBackup(try Data(contentsOf: url))
            } catch {
                alertMessage = "读取备份文件失败：\(error.localizedDescription)"
            }
        case .failure(let error):
            alertMessage = "选择文件失败：\(error.localizedDescription)"
        }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private static let fileStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
