# S-MFA

离线 iOS 虚拟 MFA（TOTP 动态口令）App：扫码或手动添加账号，每 30 秒生成 6 位口令。密钥只存在本机 Keychain，备份由你自设密码加密，不依赖任何服务端。

## 跑起来

```bash
open SMFA.xcodeproj      # 需要 Xcode 26，Swift 6，部署目标 iOS 17，仅 iPhone
```

选一个模拟器或真机直接运行。扫码需要真机——模拟器没有摄像头。

## 能做什么

| 能力 | 说明 |
|---|---|
| 展示 | 列表实时滚动 6 位口令，进度条随剩余秒数收缩、最后 5 秒转红；点卡片复制；按账号名或发行方搜索 |
| 扫码添加 | 相机识别 `otpauth://totp/` 二维码；无效码提示后继续扫，不退出 |
| 手动添加 | 账号名 + Base32 密钥，密钥非法当场报错 |
| 备份 | 全部账号导出成一个 `.smfa` 文件，经系统「文件」保存 |
| 导入备份 | 从「文件」选取，输密码解密，按密钥去重后**合并**（不覆盖现有账号） |
| 管理 | 重命名、删除（二次确认） |

密钥存 iOS Keychain，`WhenUnlockedThisDeviceOnly`——锁屏后不可读，也不同步到 iCloud 钥匙串。

## 口令是怎么来的

站点开启两步验证时给你一个 Base32 密钥。App 用「密钥 + 当前时间」算口令，站点用同一个密钥和自己的时钟算，两边对上就通过——**全程离线，不需要网络，也不需要账号**：

```
计数器 = floor(Unix 时间戳 / 30)
口令   = 动态截断(HMAC-SHA1(密钥, 计数器)) mod 10^6
```

这也解释了一个常见故障：手机系统时间不准，口令就会全部验证失败。它不是「和服务器对答案」，是两边各算各的。

零第三方依赖，密码学原语全走系统 CryptoKit / CommonCrypto：

| 用途 | 依据 |
|---|---|
| 动态口令 | RFC 6238（TOTP）+ RFC 4226（HOTP 动态截断） |
| 密钥编码 | RFC 4648 Base32 |
| 二维码格式 | Key URI Format（`otpauth://`，Google Authenticator 定的事实标准） |
| 备份密钥派生 | PBKDF2-HMAC-SHA256，21 万次迭代（OWASP 2023 推荐值） |
| 备份加密 | AES-256-GCM，密文被改一个字节就解不开 |

口令生成用 RFC 6238 附录 B 的**官方测试向量**校验，不是自编的期望值——同一个密钥，它和 Google Authenticator 算出来的是同一个 6 位数。

## 两件要先知道的事

1. **忘记备份密码 = 这份备份作废**。密码只用来派生密钥，不落盘，无从找回。
2. **阿里云 App 导出的备份导不进来**。那是它的私有加密格式，它自己也写明「仅支持用阿里云APP导入」。迁移得去各站点解绑重绑，用本 App 扫新二维码；解绑前先拿到站点的恢复码。

## 目录

```
SMFACore/     纯逻辑本地包：Base32、TOTP、otpauth 解析、备份编解码，脱离模拟器可测
SMFA/         App target：SwiftUI 界面、Keychain 存储、扫码、文件导入导出
SMFATests/    App 单测          SMFAUITests/  端到端走查，每步产出截图
openspec/     需求与设计工件
```

开发约定见 [CLAUDE.md](CLAUDE.md)。需求与设计取舍见
[openspec/changes/archive/2026-09-02-add-virtual-mfa/](openspec/changes/archive/2026-09-02-add-virtual-mfa/)
（[proposal](openspec/changes/archive/2026-09-02-add-virtual-mfa/proposal.md) ·
[design](openspec/changes/archive/2026-09-02-add-virtual-mfa/design.md)），
主规格在 [openspec/specs/](openspec/specs/)。

## 测试

```bash
cd SMFACore && swift test                                    # 核心逻辑 36 个用例，秒级

xcodebuild test -project SMFA.xcodeproj -scheme SMFA \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'   # App 单测 19 个 + 端到端走查 3 个
```

## 已知限制

- **扫码链路未在真机验证**——模拟器没有摄像头。二维码解析已下沉到可单测的 `OTPAuthURI`，扫码页只剩相机回调几行，但相机链路本身需要真机复验
- 未做 iCloud 备份，只走系统「文件」
- 未配签名、无 App 图标，当前只能跑模拟器

## 许可证

[MIT](LICENSE)
