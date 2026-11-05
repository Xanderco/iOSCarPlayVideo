import Foundation

// Frame transport from the DashCastBroadcast extension to the DashCast app.
//
// The extension writes each downscaled JPEG frame into a small memory-mapped
// style file in the app group container (two slots, fixed size, written in
// place, so the extension never buffers more than one frame: well under the
// ~50 MB broadcast-extension memory limit). The app polls the newest complete
// slot. Each slot is protected by a sequence lock: `seqBegin` is written
// first, then the payload, then `seqEnd`; a reader only accepts a slot when
// both sequence numbers match after reading the payload, so torn frames
// (writer mid-update) are dropped instead of displayed.
//
// Compiled into both the app and the broadcast extension.

/// Feature flag for "Mirror iPhone to the CarPlay screen". Off by default:
/// the CarPlay window it draws into is only delivered by iOS when the app holds
/// a CarPlay entitlement that grants a window (see ADR-002 §7).
enum CarMirrorFeature {
    static let enabledKey = "carMirror.enabled"

    static func isEnabled(in defaults: UserDefaults? = CarCastShared.sharedDefaults) -> Bool {
        defaults?.bool(forKey: enabledKey) ?? false
    }

    static func setEnabled(_ enabled: Bool, in defaults: UserDefaults? = CarCastShared.sharedDefaults) {
        defaults?.set(enabled, forKey: enabledKey)
    }

    /// Shared frame file in the app group, or nil when the app group is unavailable.
    static var framesURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: CarCastShared.appGroupID)?
            .appendingPathComponent("carplay-mirror-frames.bin")
    }
}

struct MirrorFrame: Equatable {
    var sequence: UInt64
    var timestamp: Double
    var width: UInt32
    var height: UInt32
    var jpeg: Data
}

enum MirrorFrameLayout {
    static let magic: UInt32 = 0x4443_4D46 // "DCMF"
    static let slotCount = 2
    /// 1.5 MB per slot: a 1280 px JPEG at q 0.6 is typically 80–250 KB.
    static let defaultSlotCapacity = 1_536 * 1024

    // Header layout (little endian), 40 bytes.
    static let magicOffset = 0      // UInt32
    static let seqBeginOffset = 4   // UInt64
    static let timestampOffset = 12 // Float64 bit pattern
    static let widthOffset = 20     // UInt32
    static let heightOffset = 24    // UInt32
    static let lengthOffset = 28    // UInt32
    static let seqEndOffset = 32    // UInt64
    static let headerSize = 40

    static func slotOffset(_ index: Int, capacity: Int) -> UInt64 {
        UInt64(index * (headerSize + capacity))
    }

    static func fileSize(capacity: Int) -> Int {
        slotCount * (headerSize + capacity)
    }
}

extension Data {
    mutating func mirrorAppendLE<T: FixedWidthInteger>(_ value: T) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }

    func mirrorReadLE<T: FixedWidthInteger>(_ type: T.Type, at offset: Int) -> T? {
        let size = MemoryLayout<T>.size
        guard offset >= 0, offset + size <= count else { return nil }
        var value: T = 0
        let start = index(startIndex, offsetBy: offset)
        let end = index(start, offsetBy: size)
        _ = Swift.withUnsafeMutableBytes(of: &value) { copyBytes(to: $0, from: start..<end) }
        return T(littleEndian: value)
    }
}

/// Writer side (broadcast extension). Not thread-safe: call from one queue.
final class MirrorFrameWriter {
    let url: URL
    let slotCapacity: Int
    private let handle: FileHandle
    private(set) var sequence: UInt64

    init?(url: URL, slotCapacity: Int = MirrorFrameLayout.defaultSlotCapacity) {
        self.url = url
        self.slotCapacity = slotCapacity
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            guard fileManager.createFile(atPath: url.path, contents: nil) else { return nil }
        }
        // Continue numbering after whatever a previous broadcast left behind so
        // a reader that remembers the last sequence keeps accepting new frames.
        let previous = MirrorFrameReader.highestSequence(at: url, slotCapacity: slotCapacity)
        guard let handle = try? FileHandle(forUpdating: url) else { return nil }
        do {
            try handle.truncate(atOffset: UInt64(MirrorFrameLayout.fileSize(capacity: slotCapacity)))
        } catch {
            try? handle.close()
            return nil
        }
        self.handle = handle
        self.sequence = previous
    }

    deinit {
        try? handle.close()
    }

    /// Writes one frame; returns false when it does not fit or the write fails.
    @discardableResult
    func write(jpeg: Data, width: UInt32, height: UInt32, timestamp: Double = Date().timeIntervalSince1970) -> Bool {
        guard !jpeg.isEmpty, jpeg.count <= slotCapacity else { return false }
        let next = sequence + 1
        let slot = Int(next % UInt64(MirrorFrameLayout.slotCount))
        let base = MirrorFrameLayout.slotOffset(slot, capacity: slotCapacity)

        var begin = Data()
        begin.mirrorAppendLE(MirrorFrameLayout.magic)
        begin.mirrorAppendLE(next)

        var meta = Data()
        meta.mirrorAppendLE(timestamp.bitPattern)
        meta.mirrorAppendLE(width)
        meta.mirrorAppendLE(height)
        meta.mirrorAppendLE(UInt32(jpeg.count))

        var end = Data()
        end.mirrorAppendLE(next)

        do {
            try handle.seek(toOffset: base + UInt64(MirrorFrameLayout.magicOffset))
            try handle.write(contentsOf: begin)
            try handle.seek(toOffset: base + UInt64(MirrorFrameLayout.timestampOffset))
            try handle.write(contentsOf: meta)
            try handle.seek(toOffset: base + UInt64(MirrorFrameLayout.headerSize))
            try handle.write(contentsOf: jpeg)
            try handle.seek(toOffset: base + UInt64(MirrorFrameLayout.seqEndOffset))
            try handle.write(contentsOf: end)
        } catch {
            return false
        }
        sequence = next
        return true
    }
}

/// Reader side (app). Stateless; the caller remembers the last sequence it showed.
enum MirrorFrameReader {
    /// Newest complete frame with a sequence greater than `newerThan`, or nil.
    static func latestFrame(
        at url: URL,
        newerThan: UInt64 = 0,
        slotCapacity: Int = MirrorFrameLayout.defaultSlotCapacity
    ) -> MirrorFrame? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var best: MirrorFrame?
        for slot in 0..<MirrorFrameLayout.slotCount {
            guard let frame = readSlot(slot, handle: handle, slotCapacity: slotCapacity),
                  frame.sequence > newerThan,
                  frame.sequence > (best?.sequence ?? 0) else { continue }
            best = frame
        }
        return best
    }

    /// Highest sequence number found in any slot, complete or not.
    static func highestSequence(at url: URL, slotCapacity: Int = MirrorFrameLayout.defaultSlotCapacity) -> UInt64 {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return 0 }
        defer { try? handle.close() }
        var highest: UInt64 = 0
        for slot in 0..<MirrorFrameLayout.slotCount {
            let base = MirrorFrameLayout.slotOffset(slot, capacity: slotCapacity)
            guard (try? handle.seek(toOffset: base)) != nil,
                  let header = try? handle.read(upToCount: MirrorFrameLayout.headerSize),
                  header.mirrorReadLE(UInt32.self, at: MirrorFrameLayout.magicOffset) == MirrorFrameLayout.magic else { continue }
            let begin = header.mirrorReadLE(UInt64.self, at: MirrorFrameLayout.seqBeginOffset) ?? 0
            let end = header.mirrorReadLE(UInt64.self, at: MirrorFrameLayout.seqEndOffset) ?? 0
            highest = Swift.max(highest, begin, end)
        }
        return highest
    }

    private static func readSlot(_ slot: Int, handle: FileHandle, slotCapacity: Int) -> MirrorFrame? {
        let base = MirrorFrameLayout.slotOffset(slot, capacity: slotCapacity)
        guard (try? handle.seek(toOffset: base)) != nil,
              let header = try? handle.read(upToCount: MirrorFrameLayout.headerSize),
              header.count == MirrorFrameLayout.headerSize,
              header.mirrorReadLE(UInt32.self, at: MirrorFrameLayout.magicOffset) == MirrorFrameLayout.magic,
              let seqBegin = header.mirrorReadLE(UInt64.self, at: MirrorFrameLayout.seqBeginOffset),
              let seqEnd = header.mirrorReadLE(UInt64.self, at: MirrorFrameLayout.seqEndOffset),
              seqEnd > 0, seqBegin == seqEnd,
              let bits = header.mirrorReadLE(UInt64.self, at: MirrorFrameLayout.timestampOffset),
              let width = header.mirrorReadLE(UInt32.self, at: MirrorFrameLayout.widthOffset),
              let height = header.mirrorReadLE(UInt32.self, at: MirrorFrameLayout.heightOffset),
              let length = header.mirrorReadLE(UInt32.self, at: MirrorFrameLayout.lengthOffset),
              length > 0, Int(length) <= slotCapacity,
              let payload = try? handle.read(upToCount: Int(length)),
              payload.count == Int(length) else { return nil }

        // Sequence lock: the writer bumps seqBegin before touching the payload.
        guard (try? handle.seek(toOffset: base + UInt64(MirrorFrameLayout.seqBeginOffset))) != nil,
              let recheck = try? handle.read(upToCount: 8),
              recheck.mirrorReadLE(UInt64.self, at: 0) == seqEnd else { return nil }

        return MirrorFrame(
            sequence: seqEnd,
            timestamp: Double(bitPattern: bits),
            width: width,
            height: height,
            jpeg: payload
        )
    }
}
