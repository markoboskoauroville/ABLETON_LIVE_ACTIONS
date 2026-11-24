// RemotePeaks.swift (PHONE REMOTE module): the waveform the phone draws, computed here; the phone never gets an audio file.
// A file is decoded once (AVAudioFile) into its loudest sample per 5 ms (0…255, all channels), kept in memory and in
// ~/Library/Caches/<bundle>/peaks; then a track's picture is laid on the Arrangement timeline: 32 columns per beat,
// each the loudest of the file seconds that play under it (unwarped: the file's own speed; warped: the warp markers).
import AVFoundation
import Foundation

final class RemotePeaks {
    static let perSecond = 200.0
    private var memory: [String: [UInt8]] = [:]
    private let lock = NSLock()
    private let dir: URL = {
        let id = Bundle.main.bundleIdentifier ?? "ableton-live-remote"
        let u = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/\(id)/peaks")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }()

    /// The file's 5 ms peaks, or nil when it cannot be read.
    func fine(_ path: String) -> [UInt8]? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let mtime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        let key = "\(path)|\(Int(mtime))|\(size)"
        lock.lock()
        if let m = memory[key] { lock.unlock(); return m }
        lock.unlock()
        let file = dir.appendingPathComponent(String(format: "%016llx.peaks", RemotePeaks.hash(key)))
        if let d = try? Data(contentsOf: file), !d.isEmpty {
            let a = [UInt8](d)
            lock.lock(); memory[key] = a; lock.unlock()
            return a
        }
        guard let a = RemotePeaks.decode(path) else { return nil }
        try? Data(a).write(to: file)
        lock.lock(); memory[key] = a; lock.unlock()
        return a
    }

    static func hash(_ s: String) -> UInt64 {          // FNV-1a, a stable name for the cache file
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h ^= UInt64(b); h = h &* 0x100000001b3 }
        return h
    }

    static func decode(_ path: String) -> [UInt8]? {
        guard let f = try? AVAudioFile(forReading: URL(fileURLWithPath: path)) else { return nil }
        let fmt = f.processingFormat
        let ch = Int(fmt.channelCount)
        guard ch > 0, fmt.sampleRate > 0 else { return nil }
        let hop = max(1, Int(fmt.sampleRate / perSecond))
        let chunk = AVAudioFrameCount(hop * 2000)
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: chunk) else { return nil }
        var out: [UInt8] = []
        out.reserveCapacity(Int(f.length) / hop + 2)
        var cur: Float = 0
        var count = 0
        while f.framePosition < f.length {
            do { try f.read(into: buf, frameCount: chunk) } catch { break }
            let n = Int(buf.frameLength)
            guard n > 0, let data = buf.floatChannelData else { break }
            for i in 0..<n {
                var m: Float = 0
                for c in 0..<ch { let v = abs(data[c][i]); if v > m { m = v } }
                if m > cur { cur = m }
                count += 1
                if count == hop {
                    out.append(UInt8(min(255, Int(cur * 255))))
                    cur = 0
                    count = 0
                }
            }
        }
        if count > 0 { out.append(UInt8(min(255, Int(cur * 255)))) }
        return out
    }

    /// A track's waveform on the timeline: `perBeat` columns per beat from beat 0 to `end`.
    func wave(track: Int, clips: [RemoteClip], tempo: Double, end songEnd: Double) -> [String: Any] {
        let end = max(songEnd, clips.map { $0.end }.max() ?? 0, 1)
        var perBeat = 32
        while Double(perBeat) * end > 60000 && perBeat > 1 { perBeat /= 2 }
        let n = Int((end * Double(perBeat)).rounded(.up))
        var out = [UInt8](repeating: 0, count: n)
        var missing: [String] = []
        for c in clips {
            guard let fine = fine(c.path), !fine.isEmpty else { missing.append(c.path); continue }
            let b0 = max(0, Int((c.start * Double(perBeat)).rounded(.down)))
            let b1 = min(n, Int((c.end * Double(perBeat)).rounded(.up)))
            guard b1 > b0 else { continue }
            for b in b0..<b1 {
                let x0 = max(c.start, Double(b) / Double(perBeat))
                let x1 = min(c.end, Double(b + 1) / Double(perBeat))
                guard x1 > x0 else { continue }
                var s0 = c.sec(at: x0, tempo: tempo), s1 = c.sec(at: x1, tempo: tempo)
                if s1 < s0 { swap(&s0, &s1) }
                let i0 = max(0, Int(s0 * RemotePeaks.perSecond))
                let i1 = min(fine.count, max(i0 + 1, Int((s1 * RemotePeaks.perSecond).rounded(.up))))
                guard i0 < i1 else { continue }
                var m: UInt8 = 0
                for i in i0..<i1 where fine[i] > m { m = fine[i] }
                if m > out[b] { out[b] = m }
            }
        }
        return ["t": track, "perBeat": perBeat, "n": n, "end": end, "tempo": tempo,
                "peaks": Data(out).base64EncodedString(),
                "clips": clips.map { [$0.start, $0.end, $0.muted ? 1 : 0] },
                "missing": missing.count]
    }
}
