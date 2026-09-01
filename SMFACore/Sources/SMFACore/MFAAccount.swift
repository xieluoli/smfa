import Foundation

public struct MFAAccount: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let issuer: String
    public var name: String
    public let secret: String
    public let algorithm: TOTPAlgorithm
    public let digits: Int
    public let period: Int
    public let createdAt: Date

    public init(id: UUID, issuer: String, name: String, secret: String,
                algorithm: TOTPAlgorithm, digits: Int, period: Int, createdAt: Date) {
        self.id = id
        self.issuer = issuer
        self.name = name
        self.secret = secret
        self.algorithm = algorithm
        self.digits = digits
        self.period = period
        self.createdAt = createdAt
    }

    /// 列表主标题：有发行方时显示 "发行方:账号"，与各站点二维码里的 label 写法一致。
    public var displayName: String {
        issuer.isEmpty ? name : "\(issuer):\(name)"
    }

    /// 判重依据。密钥参与判重，因为同一账号在站点重置 MFA 后会拿到新密钥，那是另一条记录。
    public var dedupeKey: String {
        "\(issuer)|\(name)|\(secret.uppercased())"
    }
}
