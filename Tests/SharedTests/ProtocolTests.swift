import XCTest
@testable import RadiateMac

final class ProtocolTests: XCTestCase {
    func testHeaderRoundTrip() throws {
        for profile in BenchmarkProfile.allCases {
            let expected = FrameHeader(profile: profile, sequence: 0xDEAD_BEEF)
            let decoded = try XCTUnwrap(FrameHeader(bits: expected.bits))
            XCTAssertEqual(decoded, expected)
            XCTAssertEqual(expected.bits.count, FrameHeader.bitCount)
        }
    }

    func testHeaderRejectsCorruption() {
        var bits = FrameHeader(profile: .balanced, sequence: 42).bits
        bits[73].toggle()
        XCTAssertNil(FrameHeader(bits: bits))
    }

    func testProfilesHaveRoomForRepeatedHeader() {
        for profile in BenchmarkProfile.allCases {
            XCTAssertGreaterThanOrEqual(
                profile.columns,
                BenchmarkProfile.headerBitCount * BenchmarkProfile.headerRepeatCount
            )
            XCTAssertGreaterThan(profile.rows, BenchmarkProfile.headerRowCount)
        }
    }

    func testPRBSKnownValues() {
        XCTAssertEqual(PRBS.word(sequence: 0, cellIndex: 0), 0)
        XCTAssertEqual(PRBS.word(sequence: 1, cellIndex: 0), 0x6889_90C0)
        XCTAssertEqual(PRBS.word(sequence: 42, cellIndex: 17), 0xE6B3_7130)
    }

    @MainActor
    func testEachSenderStartCreatesANewRunGeneration() {
        let sender = SenderModel()

        sender.start()
        let firstGeneration = sender.runGeneration
        XCTAssertTrue(sender.isRunning)

        sender.stop()
        XCTAssertFalse(sender.isRunning)

        sender.start()
        XCTAssertTrue(sender.isRunning)
        XCTAssertEqual(sender.runGeneration, firstGeneration + 1)
    }
}
