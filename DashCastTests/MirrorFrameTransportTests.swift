import XCTest
@testable import DashCast

final class MirrorFrameTransportTests: XCTestCase {
    private var url: URL!
    private let capacity = 4096

    override func setUp() {
        super.setUp()
        url = FileManager.default.temporaryDirectory.appendingPathComponent("mirror-\(UUID().uuidString).bin")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
        super.tearDown()
    }

    func testLittleEndianRoundTrip() {
        var data = Data()
        data.mirrorAppendLE(UInt32(0xDEADBEEF))
        data.mirrorAppendLE(UInt64(42))
        XCTAssertEqual(data.mirrorReadLE(UInt32.self, at: 0), 0xDEADBEEF)
        XCTAssertEqual(data.mirrorReadLE(UInt64.self, at: 4), 42)
        XCTAssertNil(data.mirrorReadLE(UInt64.self, at: 8))
    }

    func testEmptyFileHasNoFrame() throws {
        _ = try XCTUnwrap(MirrorFrameWriter(url: url, slotCapacity: capacity))
        XCTAssertNil(MirrorFrameReader.latestFrame(at: url, slotCapacity: capacity))
    }

    func testMissingFileHasNoFrame() {
        XCTAssertNil(MirrorFrameReader.latestFrame(at: url, slotCapacity: capacity))
    }

    func testWriteThenReadRoundTrip() throws {
        let writer = try XCTUnwrap(MirrorFrameWriter(url: url, slotCapacity: capacity))
        let payload = Data((0..<1000).map { UInt8($0 % 251) })
        XCTAssertTrue(writer.write(jpeg: payload, width: 640, height: 360, timestamp: 12.5))
        let frame = try XCTUnwrap(MirrorFrameReader.latestFrame(at: url, slotCapacity: capacity))
        XCTAssertEqual(frame, MirrorFrame(sequence: 1, timestamp: 12.5, width: 640, height: 360, jpeg: payload))
    }

    func testReaderReturnsNewestOfTwoSlotsAndSkipsAlreadySeen() throws {
        let writer = try XCTUnwrap(MirrorFrameWriter(url: url, slotCapacity: capacity))
        writer.write(jpeg: Data([1, 1, 1]), width: 1, height: 1)
        writer.write(jpeg: Data([2, 2]), width: 2, height: 2)
        writer.write(jpeg: Data([3]), width: 3, height: 3)
        let newest = try XCTUnwrap(MirrorFrameReader.latestFrame(at: url, slotCapacity: capacity))
        XCTAssertEqual(newest.sequence, 3)
        XCTAssertEqual(newest.jpeg, Data([3]))
        XCTAssertNil(MirrorFrameReader.latestFrame(at: url, newerThan: 3, slotCapacity: capacity))
    }

    func testOversizedAndEmptyFramesAreRejected() throws {
        let writer = try XCTUnwrap(MirrorFrameWriter(url: url, slotCapacity: capacity))
        XCTAssertFalse(writer.write(jpeg: Data(count: capacity + 1), width: 1, height: 1))
        XCTAssertFalse(writer.write(jpeg: Data(), width: 1, height: 1))
        XCTAssertEqual(writer.sequence, 0)
        XCTAssertNil(MirrorFrameReader.latestFrame(at: url, slotCapacity: capacity))
    }

    func testTornSlotIsIgnored() throws {
        let writer = try XCTUnwrap(MirrorFrameWriter(url: url, slotCapacity: capacity))
        writer.write(jpeg: Data([1]), width: 1, height: 1) // slot 1
        writer.write(jpeg: Data([2]), width: 1, height: 1) // slot 0
        // Simulate a writer that bumped seqBegin of slot 1 (seq 3) and died mid-payload.
        let handle = try FileHandle(forUpdating: url)
        let base = MirrorFrameLayout.slotOffset(1, capacity: capacity)
        try handle.seek(toOffset: base + UInt64(MirrorFrameLayout.seqBeginOffset))
        var begin = Data()
        begin.mirrorAppendLE(UInt64(3))
        try handle.write(contentsOf: begin)
        try handle.close()

        let frame = try XCTUnwrap(MirrorFrameReader.latestFrame(at: url, slotCapacity: capacity))
        XCTAssertEqual(frame.sequence, 2)
        XCTAssertEqual(frame.jpeg, Data([2]))
    }

    func testNewWriterContinuesSequenceAfterPreviousBroadcast() throws {
        do {
            let first = try XCTUnwrap(MirrorFrameWriter(url: url, slotCapacity: capacity))
            first.write(jpeg: Data([1]), width: 1, height: 1)
            first.write(jpeg: Data([2]), width: 1, height: 1)
        }
        let second = try XCTUnwrap(MirrorFrameWriter(url: url, slotCapacity: capacity))
        XCTAssertEqual(second.sequence, 2)
        second.write(jpeg: Data([9]), width: 1, height: 1)
        let frame = try XCTUnwrap(MirrorFrameReader.latestFrame(at: url, newerThan: 2, slotCapacity: capacity))
        XCTAssertEqual(frame.sequence, 3)
        XCTAssertEqual(frame.jpeg, Data([9]))
    }

    func testDisplayStateRules() {
        XCTAssertEqual(CarMirrorDisplayState.resolve(featureEnabled: false, vehicleMoving: false, lastFrameAge: 0.1), .instructions)
        XCTAssertEqual(CarMirrorDisplayState.resolve(featureEnabled: true, vehicleMoving: true, lastFrameAge: 0.1), .pausedWhileMoving)
        XCTAssertEqual(CarMirrorDisplayState.resolve(featureEnabled: true, vehicleMoving: false, lastFrameAge: nil), .instructions)
        XCTAssertEqual(CarMirrorDisplayState.resolve(featureEnabled: true, vehicleMoving: false, lastFrameAge: 5), .instructions)
        XCTAssertEqual(CarMirrorDisplayState.resolve(featureEnabled: true, vehicleMoving: false, lastFrameAge: 0.2), .mirroring)
    }

    func testFeatureFlagDefaultsOff() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "mirror-test-\(UUID().uuidString)"))
        XCTAssertFalse(CarMirrorFeature.isEnabled(in: defaults))
        CarMirrorFeature.setEnabled(true, in: defaults)
        XCTAssertTrue(CarMirrorFeature.isEnabled(in: defaults))
    }
}
