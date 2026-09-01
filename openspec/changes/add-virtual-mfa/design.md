## Context

全新空仓，无历史包袱。目标是一个纯本地、无服务端的 iOS App。本机工具链已核实：Xcode 26.6、Swift 6.3.3、可用模拟器含 iOS 18.1 与 26.5；本机**未安装** XcodeGen / Tuist，所以 `.xcodeproj` 需手写。

TOTP 是完全公开的算法（RFC 6238），有官方测试向量，适合先用 TDD 把引擎做实，再套 UI。

## Goals / Non-Goals

**Goals:**

- 口令、密钥永不出本机，除非用户主动导出加密备份
- 核心算法（Base32 / TOTP / otpauth / 备份编解码）做成独立 Swift Package，可用 `swift test` 秒级验证，不依赖模拟器
- 备份文件自解释、可跨设备，且只有知道密码的人能解开
- 零第三方依赖，加密只用系统 CryptoKit / CommonCrypto

**Non-Goals:**

- 不做 iCloud 备份（需要付费开发者账号配置 iCloud 容器 entitlement，本轮无法验证；见「未决问题」）
- 不做 HOTP（计数器型）——参考产品与实际站点均用 TOTP
- 不做 App 启动生物识别锁、不做账号分组/排序/拖拽、不做 Apple Watch
- 不做多端同步、不做任何网络请求
- 不做 iPad 专门适配（能跑但只按 iPhone 布局验收）

## Decisions

### 1. 工程结构：App target + 本地 Swift Package

```
smfa/
├── SMFA.xcodeproj          手写 pbxproj
├── SMFA/                   App target：UI、Keychain、扫码、文件读写
├── SMFACore/               本地 Swift Package：纯逻辑，零 UIKit 依赖
│   ├── Sources/SMFACore/   Base32 / TOTPGenerator / OTPAuthURI / MFAAccount / BackupCodec
│   └── Tests/SMFACoreTests/
└── SMFATests/              App 单测：Keychain 存储
```

**为什么拆包**：算法部分不碰 UI 也不碰 Keychain，放进 Package 后 `swift test` 在 macOS 上直接跑，一轮 TDD 循环几秒钟；如果全塞进 App target，每次都得起模拟器，红绿循环会慢一个数量级。

**pbxproj 手写方案**：用 `objectVersion = 77` 的 `PBXFileSystemSynchronizedRootGroup`（Xcode 16+ 特性）——整个 `SMFA/` 目录自动同步，新增源文件不需要改 pbxproj。这把手写 pbxproj 的主要痛点（逐文件维护 `PBXBuildFile` / `PBXFileReference`）消掉了。

### 2. TOTP 引擎

- HMAC 走 CryptoKit：`Insecure.SHA1`（默认）/ `SHA256` / `SHA512`
- Base32 自己实现 RFC 4648 解码：只需要 32 字母表 + 5/8 位重组，比引入依赖划算
- 时间源通过参数注入（`Date` 默认值），测试能钉死在 RFC 官方向量的时间戳上，不依赖系统时钟
- 口令刷新：单个 `Timer` 每秒 tick 驱动整个列表重算，而不是每行各起一个定时器——账号数量再多也只有一个时间源，且所有行的进度条严格同步

### 3. 存储：Keychain 存全量账号

一条 Keychain 记录（`kSecClassGenericPassword`，account = `accounts`）存全部账号的 JSON，而不是一账号一条。

**为什么**：账号数量是个位数到几十，一次读写全量的开销可忽略；换来的是原子性——增删改都是一次 `SecItemUpdate`，不会出现「元数据写进去了、密钥没写进去」的半截状态。

可访问性用 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`：锁屏后不可读，且不同步到 iCloud 钥匙串（同步意味着密钥离开本机，与 Goals 冲突）。

### 4. 备份格式与加密

文件扩展名 `.smfa`，内容是 JSON：

```json
{
  "version": 1,
  "app": "S-MFA",
  "createdAt": "2026-08-31T08:00:00Z",
  "kdf":    { "algorithm": "PBKDF2-HMAC-SHA256", "iterations": 210000, "salt": "<base64>" },
  "cipher": { "algorithm": "AES-256-GCM", "nonce": "<base64>", "ciphertext": "<base64>" }
}
```

密文明文体（加密前）：

```json
{ "accounts": [ { "id","issuer","name","secret","algorithm","digits","period","createdAt" } ] }
```

- **KDF 选 PBKDF2-HMAC-SHA256 / 210000 次**：OWASP 2023 起对该组合的推荐值；CommonCrypto 直接提供，无需第三方
- **加密选 AES-256-GCM**：CryptoKit 的 `AES.GCM.SealedBox` 自带认证标签，密文被改一个字节就解密失败，正好满足「篡改必须报错」这条规格；GCM 的 tag 已包含在 `combined` 里，所以 JSON 里不单列 `tag` 字段
- **`version` 字段前置**：导入时先看版本再解析，未来格式变了能给出明确提示而不是崩在解析上
- **对比「厂商内置密钥」方案**（阿里云的做法）：那样备份只能被自家 App 打开，且密钥藏在二进制里，逆向即破。用户自设密码把安全边界交回用户手里，代价是忘记密码等于备份作废——这个取舍在 App 内用文案讲清楚

### 5. 备份导出/导入走系统「文件」

SwiftUI 原生 `.fileExporter` / `.fileImporter`，配合 `Info.plist` 里导出的自定义 UTType `cn.smfa.backup`（`conformsTo: public.data`，扩展名 `smfa`）。不用 `UIDocumentPickerViewController` 包一层 `UIViewControllerRepresentable`，少一层胶水。

### 6. 扫码

`AVCaptureSession` + `AVCaptureMetadataOutput`（`.qr`），用 `UIViewControllerRepresentable` 包进 SwiftUI。识别到字符串后交给 `OTPAuthURI.parse`——**扫码只负责拿到字符串，解析和校验全在可单测的 Core 里**，所以「扫到非法二维码怎么办」这条规格能在不开摄像头的情况下测到。

## 数据模型

```swift
struct MFAAccount: Codable, Identifiable, Equatable {
    let id: UUID
    var issuer: String        // 发行方，可为空
    var name: String          // 账号名
    let secret: String        // Base32 密钥，原样保存
    let algorithm: TOTPAlgorithm  // .sha1 / .sha256 / .sha512
    let digits: Int           // 6 或 8
    let period: Int           // 秒
    let createdAt: Date

    var displayName: String   // issuer 为空则为 name，否则 "issuer:name"
    var dedupeKey: String     // issuer|name|secret，去重用
}
```

## 关键接口契约

```swift
// Base32.swift
enum Base32 { static func decode(_ s: String) throws -> Data }

// TOTPGenerator.swift
struct TOTPGenerator {
    static func code(secret: Data, at date: Date, algorithm: TOTPAlgorithm,
                     digits: Int, period: Int) -> String
    static func remainingSeconds(at date: Date, period: Int) -> Int
}

// OTPAuthURI.swift
enum OTPAuthURI { static func parse(_ uri: String) throws -> MFAAccount }

// BackupCodec.swift
enum BackupCodec {
    static func export(accounts: [MFAAccount], password: String, createdAt: Date) throws -> Data
    static func `import`(data: Data, password: String) throws -> [MFAAccount]
}

// KeychainAccountStore.swift（App target）
final class KeychainAccountStore {
    func load() throws -> [MFAAccount]
    func save(_ accounts: [MFAAccount]) throws
}
```

## Risks / Trade-offs

| 风险 | 应对 |
|---|---|
| 手写 pbxproj 不被 Xcode 26 接受 | 排在第 1 个任务，先用 `xcodebuild build` 跑通空壳 App 再往里加代码；跑不通就改用逐文件声明的传统 objectVersion 56 格式 |
| 模拟器没有摄像头，扫码链路无法端到端验证 | 把 URI 解析全部下沉到 Core 并单测覆盖；扫码页只剩「相机回调 → 调用解析」几行，作为已知限制交付，需真机复验 |
| 忘记备份密码 = 备份永久作废 | 备份弹窗内明确提示；同时账号本体仍在本机 Keychain，备份失效不影响日常使用 |
| PBKDF2 210000 次在旧机型上可能卡顿 | 派生放后台线程，UI 显示进度态；单次导出/导入耗时在百毫秒量级，可接受 |
| Keychain 单条记录存全量，账号极多时读写变慢 | 个人自用场景账号量在几十以内，不做优化；真到瓶颈再改分条存储 |

## Open Questions

1. **Bundle ID 与签名**：暂定 `cn.smfa`，本轮用模拟器构建（无需签名）。装真机需要用户提供开发者账号 Team ID。
2. **iCloud 备份**：参考的阿里云 App 同时提供 iCloud 与「文件」两条路。本轮只做「文件」，iCloud 是否要补取决于问题 1。
3. **App 图标与配色**：当前用系统默认，未做视觉设计。
