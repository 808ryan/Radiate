import Foundation

enum PRBS {
    static func word(sequence: UInt32, cellIndex: UInt32) -> UInt32 {
        var value = sequence &+ (cellIndex &* 0x9E37_79B9)
        value ^= value >> 16
        value &*= 0x7FEB_352D
        value ^= value >> 15
        value &*= 0x846C_A68B
        value ^= value >> 16
        return value
    }

    static func bit(sequence: UInt32, cellIndex: UInt32) -> Bool {
        (word(sequence: sequence, cellIndex: cellIndex) & 1) == 1
    }
}
