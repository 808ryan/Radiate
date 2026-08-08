import Foundation

struct FrameHeader: Equatable, Sendable {
    static let magic: UInt16 = 0x5244 // "RD"
    static let version: UInt8 = 1
    static let bitCount = 80

    let profile: BenchmarkProfile
    let sequence: UInt32

    var checksum: UInt16 {
        let folded = UInt32(Self.magic)
            ^ (UInt32(Self.version) << 8)
            ^ UInt32(profile.rawValue)
            ^ sequence
            ^ (sequence >> 16)
            ^ 0xA55A
        return UInt16(truncatingIfNeeded: folded)
    }

    var bits: [Bool] {
        var result: [Bool] = []
        result.reserveCapacity(Self.bitCount)
        result.append(contentsOf: Self.bits(of: Self.magic, width: 16))
        result.append(contentsOf: Self.bits(of: Self.version, width: 8))
        result.append(contentsOf: Self.bits(of: profile.rawValue, width: 8))
        result.append(contentsOf: Self.bits(of: sequence, width: 32))
        result.append(contentsOf: Self.bits(of: checksum, width: 16))
        return result
    }

    init(profile: BenchmarkProfile, sequence: UInt32) {
        self.profile = profile
        self.sequence = sequence
    }

    init?(bits: [Bool]) {
        guard bits.count >= Self.bitCount else { return nil }
        var cursor = 0
        let magic = UInt16(Self.read(bits, cursor: &cursor, width: 16))
        let version = UInt8(Self.read(bits, cursor: &cursor, width: 8))
        let profileID = UInt8(Self.read(bits, cursor: &cursor, width: 8))
        let sequence = UInt32(Self.read(bits, cursor: &cursor, width: 32))
        let checksum = UInt16(Self.read(bits, cursor: &cursor, width: 16))

        guard magic == Self.magic,
              version == Self.version,
              let profile = BenchmarkProfile(rawValue: profileID)
        else { return nil }

        self.profile = profile
        self.sequence = sequence
        guard self.checksum == checksum else { return nil }
    }

    private static func bits<T: FixedWidthInteger>(of value: T, width: Int) -> [Bool] {
        (0..<width).map { shift in
            ((value >> T(width - shift - 1)) & 1) == 1
        }
    }

    private static func read(_ bits: [Bool], cursor: inout Int, width: Int) -> UInt64 {
        var value: UInt64 = 0
        for _ in 0..<width {
            value = (value << 1) | (bits[cursor] ? 1 : 0)
            cursor += 1
        }
        return value
    }
}
