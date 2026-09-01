import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// 与 Info.plist 里 UTExportedTypeDeclarations 声明的标识符一致。
    static let mfaBackup = UTType(exportedAs: "cn.smfa.backup")
}

/// 交给系统「文件」App 保存的备份文档。内容已由 BackupCodec 加密，这里只负责搬运字节。
struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.mfaBackup]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
