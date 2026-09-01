## Why

阿里云、Google、GitHub 等平台的两步验证依赖「虚拟 MFA」应用生成 6 位动态口令（TOTP）。目前这些口令分散在各家自带 App 里：阿里云的 MFA 只能用阿里云 App 导入导出，换机、误删、清缓存都会导致口令永久丢失，且备份格式互不相通。

本次要做的是一个**只服务于本人、离线运行的 iOS 虚拟 MFA App**：口令全部存在本机，备份文件由用户自设密码加密，可自行保管、跨设备迁移，不依赖任何厂商的账号体系和服务端。

## What Changes

- 新建 iOS App 工程 `SMFA`（SwiftUI，仅 iOS），以及纯逻辑 Swift Package `SMFACore`
- **命名**（2026-08-31 用户指定）：展示名 `S-MFA`（主屏幕图标名、主界面标题、备份文件名、相机权限文案）；技术标识符统一用 `smfa`——Bundle ID `cn.smfa`、备份文件类型 `cn.smfa.backup`、扩展名 `.smfa`、Keychain service `cn.smfa.accounts`，target / 模块 / 目录 / 仓库名为 `SMFA` / `SMFACore` / `smfa`
- **展示**：账号列表实时滚动 6 位动态码，倒计时进度条随剩余秒数收缩并变色，点击卡片复制口令，支持按账号名搜索
- **添加（扫码）**：相机扫描 `otpauth://totp/...` 二维码，识别后进入确认页
- **添加（手动）**：手工填写账号名 + Base32 密钥
- **备份**：把全部账号导出为一个用户自设密码加密的 `.smfa` 文件，经系统「文件」App 保存
- **导入备份**：从「文件」选取 `.smfa`，输入密码解密，与现有账号按密钥去重后合并
- **管理**：单个账号的重命名与删除

## Capabilities

### New Capabilities

- `totp-engine`: TOTP 口令生成与 `otpauth` URI 解析——Base32 解码、RFC 6238 计算、参数校验
- `account-store`: 账号（含密钥）的本机加密存储、增删改查与去重
- `mfa-backup`: 备份文件的加密导出与解密导入，含文件格式定义
- `mfa-ui`: 列表展示、扫码添加、手动添加、备份/导入的界面与交互

### Modified Capabilities

无（全新项目）。

## Impact

- **新增代码**：`SMFA/`（App）、`SMFACore/`（Swift Package）、`SMFA.xcodeproj`
- **系统权限**：相机（`NSCameraUsageDescription`），用于扫码添加
- **系统能力**：Keychain（存密钥）、Files App 文档选择器（备份导入导出）
- **自定义文件类型**：导出 UTType `cn.smfa.backup`，扩展名 `.smfa`
- **外部依赖**：无第三方库；加密全部走系统 CryptoKit
- **不涉及**：任何服务端、网络请求、账号体系
