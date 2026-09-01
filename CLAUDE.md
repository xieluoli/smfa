# S-MFA

个人自用的 iOS 虚拟 MFA（TOTP 动态口令）App，展示名 **S-MFA**。账号与密钥全部留在本机，备份文件由用户自设密码加密，不依赖任何服务端。

## 技术栈

- Swift 6 / SwiftUI，最低 iOS 17.0，仅 iPhone 竖屏
- 零第三方依赖：TOTP 走 CryptoKit，密码派生走 CommonCrypto
- `SMFA.xcodeproj` 为手写 pbxproj（objectVersion 77，用文件系统同步组），新增源文件放进对应目录即可，不需要改工程文件

## 目录

| 路径 | 职责 |
|---|---|
| `SMFACore/` | 本地 Swift Package，纯逻辑：Base32、TOTP、otpauth URI 解析、备份编解码。不依赖 UIKit，可脱离模拟器测试 |
| `SMFA/` | App target：SwiftUI 界面、Keychain 存储、相机扫码、文件导入导出 |
| `SMFATests/` | App 单测：Keychain、ViewModel、备份往返 |
| `SMFAUITests/` | 端到端走查，每步产出截图 |
| `openspec/` | 需求与设计工件 |

## 常用命令

```bash
# 核心逻辑测试（秒级，不用起模拟器）
cd SMFACore && swift test

# App 单测
xcodebuild test -project SMFA.xcodeproj -scheme SMFA \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:SMFATests

# 端到端走查（产出截图，约 100 秒）
xcodebuild test -project SMFA.xcodeproj -scheme SMFA \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:SMFAUITests -resultBundlePath .build/UIResult.xcresult

# 从 xcresult 取截图
xcrun xcresulttool export attachments --path .build/UIResult.xcresult --output-path .build/shots
```

## 命名

展示名 `S-MFA`，技术标识符一律用 `smfa`：Bundle ID `cn.smfa`、备份文件类型 `cn.smfa.backup`、扩展名 `.smfa`、Keychain service `cn.smfa.accounts`。

**改 Keychain service 会让旧数据读不出来**——它是账号存储的键，改了等于换了个抽屉。真机上用过之后不要再动。

## 约定

- 可测的逻辑一律下沉到 `SMFACore` 或 ViewModel，视图层只做展示与转发——扫码页就是这么做的，所以「无效二维码怎么处理」不用摄像头也能测
- 时间通过参数注入（`TOTPGenerator.code(at:)`、`AccountListViewModel.now`），测试才能钉死在 RFC 官方向量的时间戳上
- 备份格式改动必须提升 `BackupCodec.currentVersion`，并保留旧版本的解析路径
