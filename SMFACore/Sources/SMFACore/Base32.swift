import Foundation

public enum Base32Error: Error, Equatable {
    case invalidCharacter
    case invalidLength
}

/// RFC 4648 Base32 解码。TOTP 密钥一律以 Base32 分发，站点给出的字符串常带空格和大小写混用，这里统一容忍。
public enum Base32 {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    public static func decode(_ text: String) throws -> Data {
        let normalized = text.uppercased()
            .filter { !$0.isWhitespace && $0 != "=" }

        var bitBuffer = 0
        var bitCount = 0
        var bytes = [UInt8]()
        bytes.reserveCapacity(normalized.count * 5 / 8)

        for character in normalized {
            guard let value = alphabet.firstIndex(of: character) else {
                throw Base32Error.invalidCharacter
            }
            bitBuffer = (bitBuffer << 5) | value
            bitCount += 5
            if bitCount >= 8 {
                bitCount -= 8
                bytes.append(UInt8((bitBuffer >> bitCount) & 0xFF))
            }
        }

        // 末尾允许残留不足 8 位的填充位，但这些位必须全为 0；非零说明输入被截断。
        guard bitCount < 5, bitBuffer & ((1 << bitCount) - 1) == 0 else {
            throw Base32Error.invalidLength
        }
        return Data(bytes)
    }
}
