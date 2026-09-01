import Foundation

public enum OTPAuthURIError: Error, Equatable {
    case unsupportedType
    case missingSecret
    case invalidSecret
    case invalidParameter
    case missingAccountName
}

/// 解析 `otpauth://totp/[发行方:]账号?secret=...` 二维码内容。
/// 扫码页只负责把字符串交到这里，所有校验都在此完成，因此不开摄像头也能测全。
public enum OTPAuthURI {
    public static func parse(_ uri: String, id: UUID = UUID(),
                             createdAt: Date = Date()) throws -> MFAAccount {
        guard let components = URLComponents(string: uri),
              components.scheme?.lowercased() == "otpauth",
              components.host?.lowercased() == "totp" else {
            throw OTPAuthURIError.unsupportedType
        }

        let queryItems = components.queryItems ?? []
        func value(_ name: String) -> String? {
            queryItems.first { $0.name.lowercased() == name }?.value
        }

        guard let secret = value("secret"), !secret.isEmpty else {
            throw OTPAuthURIError.missingSecret
        }
        guard let decoded = try? Base32.decode(secret), !decoded.isEmpty else {
            throw OTPAuthURIError.invalidSecret
        }

        // path 形如 "/发行方:账号"，URLComponents.path 已完成百分号解码。
        let label = String(components.path.dropFirst())
        let separatorIndex = label.firstIndex(of: ":")
        let labelIssuer = separatorIndex.map { String(label[label.startIndex..<$0]) } ?? ""
        let name = separatorIndex
            .map { String(label[label.index(after: $0)...]) }
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? label
        guard !name.isEmpty else {
            throw OTPAuthURIError.missingAccountName
        }

        // RFC 建议：issuer 参数与 label 前缀冲突时以参数为准。
        let issuer = value("issuer") ?? labelIssuer

        let algorithm: TOTPAlgorithm
        if let raw = value("algorithm") {
            guard let parsed = TOTPAlgorithm(rawValue: raw.uppercased()) else {
                throw OTPAuthURIError.invalidParameter
            }
            algorithm = parsed
        } else {
            algorithm = .sha1
        }

        let digits = try intValue(value("digits"), default: 6, allowed: 6...8)
        let period = try intValue(value("period"), default: 30, allowed: 1...300)

        return MFAAccount(id: id, issuer: issuer, name: name, secret: secret.uppercased(),
                          algorithm: algorithm, digits: digits, period: period,
                          createdAt: createdAt)
    }

    private static func intValue(_ raw: String?, default fallback: Int,
                                 allowed: ClosedRange<Int>) throws -> Int {
        guard let raw else { return fallback }
        guard let parsed = Int(raw), allowed.contains(parsed) else {
            throw OTPAuthURIError.invalidParameter
        }
        return parsed
    }
}
