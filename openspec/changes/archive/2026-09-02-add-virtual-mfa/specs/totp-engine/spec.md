## ADDED Requirements

### Requirement: 生成 TOTP 动态口令
系统必须按 RFC 6238 由密钥与当前时间计算动态口令，默认算法 SHA1、位数 6、周期 30 秒。

#### Scenario: 符合 RFC 6238 官方测试向量
- **当** 用密钥 `12345678901234567890`、时间戳 59 秒、SHA1、8 位计算口令
- **则** 结果必须为 `94287082`

#### Scenario: 同周期内口令稳定
- **当** 在同一个 30 秒周期内的任意两个时刻计算同一账号的口令
- **则** 两次结果必须相同

#### Scenario: 跨周期口令翻转
- **当** 时间跨过周期边界
- **则** 必须生成新的口令，且剩余秒数重置为完整周期

### Requirement: Base32 密钥解码
系统必须按 RFC 4648 解码 Base32 密钥，忽略大小写、空格与 `=` 填充。

#### Scenario: 解码带空格和小写的密钥
- **当** 输入 `jbsw y3dp ehpk 3pxp`
- **则** 必须解码为字节序列 `Hello!\xDE\xAD\xBE\xEF`

#### Scenario: 拒绝非法字符
- **当** 输入包含 Base32 字母表以外的字符（如 `1`、`8`、`0`）
- **则** 必须抛出解码错误，不得返回部分结果

### Requirement: 解析 otpauth URI
系统必须解析 `otpauth://totp/` 格式的 URI，提取发行方、账号名、密钥及算法参数。

#### Scenario: 解析带发行方前缀的标准 URI
- **当** 输入 `otpauth://totp/Gitee:user@x.com?secret=JBSWY3DPEHPK3PXP&issuer=Gitee&digits=6&period=30`
- **则** 必须解析出发行方 `Gitee`、账号 `user@x.com`、对应密钥字节，以及位数 6、周期 30

#### Scenario: 缺失参数时取默认值
- **当** URI 未指定 `algorithm`、`digits`、`period`
- **则** 必须分别取 SHA1、6、30

#### Scenario: 拒绝非 totp 类型
- **当** 输入 `otpauth://hotp/...` 或缺少 `secret` 参数
- **则** 必须抛出解析错误
