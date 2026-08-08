import Foundation

enum BenchmarkProfile: UInt8, CaseIterable, Codable, Identifiable, Sendable {
    case safe = 1
    case balanced = 2
    case aggressive = 3
    case stretch = 4

    static let headerBitCount = 80
    static let headerRepeatCount = 3
    static let headerRowCount = 6

    var id: UInt8 { rawValue }

    var name: String {
        switch self {
        case .safe: "Safe"
        case .balanced: "Balanced"
        case .aggressive: "Aggressive"
        case .stretch: "Stretch"
        }
    }

    var columns: Int {
        switch self {
        case .safe: 256
        case .balanced: 384
        case .aggressive: 512
        case .stretch: 640
        }
    }

    var rows: Int {
        switch self {
        case .safe: 160
        case .balanced: 240
        case .aggressive: 320
        case .stretch: 400
        }
    }

    var payloadCellCount: Int {
        columns * (rows - Self.headerRowCount)
    }

    var payloadByteCount: Int {
        payloadCellCount / 8
    }

    func rawBytesPerSecond(symbolRate: Double) -> Double {
        Double(payloadByteCount) * symbolRate
    }

    var dimensions: String { "\(columns) × \(rows)" }
}
