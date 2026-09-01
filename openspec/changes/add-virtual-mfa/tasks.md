## 1. 工程骨架

- [x] 1.1 手写 `SMFA.xcodeproj/project.pbxproj`（objectVersion 77 + 文件系统同步组），建最小 SwiftUI 空壳 App，`xcodebuild build` 跑通模拟器构建
- [x] 1.2 创建本地 Swift Package `SMFACore`（platforms: iOS 17 / macOS 13），`swift test` 跑通空测试
- [x] 1.3 把 `SMFACore` 作为本地包依赖接入 App target，构建验证链路打通
- [x] 1.4 补 `.gitignore`（xcuserdata / .build / DerivedData）与 `CLAUDE.md`（技术栈与常用命令）

## 2. 核心算法（TDD，全部在 SMFACore）

- [x] 2.1 `Base32Tests`：写 RFC 4648 解码用例 + 非法字符用例，确认红灯
- [x] 2.2 实现 `Base32.decode`，转绿
- [x] 2.3 `TOTPGeneratorTests`：写 RFC 6238 官方测试向量（SHA1/SHA256/SHA512 各取样）+ 同周期稳定 + 跨周期翻转 + 剩余秒数，确认红灯
- [x] 2.4 实现 `TOTPAlgorithm` 与 `TOTPGenerator.code` / `remainingSeconds`，转绿
- [x] 2.5 定义 `MFAAccount` 模型（含 `displayName` / `dedupeKey`）
- [x] 2.6 `OTPAuthURITests`：写标准 URI、缺省参数取默认值、非 totp 类型、缺 secret、URL 编码账号名等用例，确认红灯
- [x] 2.7 实现 `OTPAuthURI.parse`，转绿

## 3. 备份编解码（TDD）

- [x] 3.1 `BackupCodecTests`：写「导出后明文密钥不出现在文件字节里」用例，确认红灯
- [x] 3.2 实现 `BackupCodec.export`（PBKDF2-HMAC-SHA256 210000 次 + AES-256-GCM），转绿
- [x] 3.3 `BackupCodecTests`：写往返一致、错误密码、密文篡改、版本过高四个用例，确认红灯
- [x] 3.4 实现 `BackupCodec.import`，转绿

## 4. App 存储层

- [x] 4.1 实现 `KeychainAccountStore`（单条 generic password，`WhenUnlockedThisDeviceOnly`）
- [x] 4.2 `KeychainAccountStoreTests`：写入-读出往返、清空、可访问性属性断言，在模拟器上跑通

## 5. 界面

- [x] 5.1 `AccountListViewModel`：单一 Timer 每秒驱动、账号增删改、搜索过滤、去重合并
- [x] 5.2 `AccountRowView`：账号名 + 添加时间 + 大字号口令 + 底部倒计时进度条（剩余 ≤5 秒转警示色），点击复制
- [x] 5.3 `AccountListView`：搜索框、提示条、空状态、`+` 菜单（扫码/手动）、`···` 菜单（备份/导入）、删除确认
- [x] 5.4 `ManualAddView`：账号名 + 密钥输入，空值禁用确定，非法 Base32 报错
- [x] 5.5 `ScannerView`：AVFoundation 扫码 + 权限拒绝兜底 + 无效码提示不退出
- [x] 5.6 `BackupPasswordSheet`：设置密码（两次输入、≥8 位）+ `.fileExporter` 导出
- [x] 5.7 `ImportPasswordSheet`：`.fileImporter` 选文件 + 输入密码 + 合并结果提示
- [x] 5.8 `Info.plist`：相机权限文案、导出 UTType `cn.smfa.backup`

## 6. 验证与交付

- [x] 6.1 `swift test` 全绿，贴汇总行
- [x] 6.2 `xcodebuild build` 模拟器构建成功
- [x] 6.3 模拟器实机走查：添加账号 → 口令随时间刷新 → 搜索 → 复制 → 备份导出 → 删除 → 导入还原，逐步截图
- [x] 6.4 整理已知限制（扫码需真机、iCloud 未做、未配签名）
