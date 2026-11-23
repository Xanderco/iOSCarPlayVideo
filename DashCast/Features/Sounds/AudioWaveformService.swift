import Foundation
import AVFoundation

public struct AudioAnalysisResult: Equatable, Sendable {
    public let durationSeconds: Double
    public let durationString: String
    public let waveformSamples: [Float]
    public let peakAmplitude: Float
    public let rmsAmplitude: Float
    public let normalizationGain: Float

    public init(
        durationSeconds: Double,
        durationString: String,
        waveformSamples: [Float],
        peakAmplitude: Float,
        rmsAmplitude: Float,
        normalizationGain: Float
    ) {
        self.durationSeconds = durationSeconds
        self.durationString = durationString
        self.waveformSamples = waveformSamples
        self.peakAmplitude = peakAmplitude
        self.rmsAmplitude = rmsAmplitude
        self.normalizationGain = normalizationGain
    }
}

public enum AudioAnalysisError: Error, LocalizedError {
    case invalidAudioFile
    case cannotCreatePCMBuffer
    case emptyAudioData

    public var errorDescription: String? {
        switch self {
        case .invalidAudioFile:
            return "The selected audio file is invalid or cannot be parsed."
        case .cannotCreatePCMBuffer:
            return "Failed to allocate audio PCM processing buffer."
        case .emptyAudioData:
            return "The audio file does not contain readable audio frames."
        }
    }
}

public final class AudioWaveformService {

    /// Reads an audio file and computes duration, a normalized waveform array, and target volume normalization gain.
    public static func analyzeAudio(url: URL, sampleCount: Int = 32) throws -> AudioAnalysisResult {
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            throw AudioAnalysisError.invalidAudioFile
        }

        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)
        guard frameCount > 0 else {
            throw AudioAnalysisError.emptyAudioData
        }

        // Limit frame capacity to maximum 10 seconds of analysis to keep memory lean
        let maxFramesToRead = min(frameCount, UInt32(format.sampleRate * 15.0))
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: maxFramesToRead) else {
            throw AudioAnalysisError.cannotCreatePCMBuffer
        }

        do {
            try audioFile.read(into: pcmBuffer, frameCount: maxFramesToRead)
        } catch {
            throw AudioAnalysisError.invalidAudioFile
        }

        guard let channelData = pcmBuffer.floatChannelData else {
            throw AudioAnalysisError.cannotCreatePCMBuffer
        }

        let channelCount = Int(format.channelCount)
        let totalFrames = Int(pcmBuffer.frameLength)
        guard totalFrames > 0 else {
            throw AudioAnalysisError.emptyAudioData
        }

        var peakAmplitude: Float = 0.0
        var sumSquares: Float = 0.0

        // Downsample into buckets
        let bucketSize = max(1, totalFrames / sampleCount)
        var rawSamples = [Float](repeating: 0.0, count: sampleCount)

        for bucket in 0..<sampleCount {
            let startFrame = bucket * bucketSize
            let endFrame = min(totalFrames, startFrame + bucketSize)
            guard startFrame < endFrame else { continue }

            var bucketPeak: Float = 0.0
            for frame in startFrame..<endFrame {
                var mixedSample: Float = 0.0
                for ch in 0..<channelCount {
                    mixedSample += channelData[ch][frame]
                }
                mixedSample /= Float(channelCount)

                let absVal = abs(mixedSample)
                if absVal > bucketPeak {
                    bucketPeak = absVal
                }
                if absVal > peakAmplitude {
                    peakAmplitude = absVal
                }
                sumSquares += mixedSample * mixedSample
            }
            rawSamples[bucket] = bucketPeak
        }

        let rmsAmplitude = sqrt(sumSquares / Float(totalFrames))

        // Normalize samples to 0.05 ... 1.0 range for clean visualization
        let maxSample = rawSamples.max() ?? 1.0
        let normalizedSamples: [Float] = rawSamples.map { sample in
            if maxSample > 0.001 {
                let ratio = sample / maxSample
                return max(0.08, min(1.0, ratio))
            } else {
                return 0.1
            }
        }

        // Target peak amplitude: 0.85 (-1.4 dBFS) to prevent clipping while ensuring adequate in-car presence
        let normalizationGain: Float
        if peakAmplitude > 0.01 {
            let desiredGain = 0.85 / peakAmplitude
            normalizationGain = min(3.0, max(0.2, desiredGain))
        } else {
            normalizationGain = 1.0
        }

        let durationSeconds = Double(frameCount) / format.sampleRate
        let durationString = formatDuration(seconds: durationSeconds)

        return AudioAnalysisResult(
            durationSeconds: durationSeconds,
            durationString: durationString,
            waveformSamples: normalizedSamples,
            peakAmplitude: peakAmplitude,
            rmsAmplitude: rmsAmplitude,
            normalizationGain: normalizationGain
        )
    }

    /// Formats time in seconds to mm:ss (e.g. 0:04)
    public static func formatDuration(seconds: Double) -> String {
        let totalSeconds = Int(round(seconds))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Generates deterministic, aesthetically distinct synthetic waveforms for preset sound effects.
    public static func syntheticWaveform(frequencyHz: Double, category: SoundCategory, sampleCount: Int = 32) -> [Float] {
        var samples = [Float](repeating: 0.1, count: sampleCount)
        let f = max(50.0, min(2000.0, frequencyHz))

        for i in 0..<sampleCount {
            let t = Double(i) / Double(sampleCount)
            let val: Double

            switch category {
            case .engine:
                // Low rumble with harmonic rev surges
                val = 0.35 + 0.35 * sin(2.0 * .pi * (f / 100.0) * t) + 0.3 * sin(4.0 * .pi * t)
            case .chimes:
                // Sharp attack and exponential decay
                val = exp(-3.2 * t) * (0.8 + 0.2 * sin(12.0 * .pi * t))
            case .voices:
                // Formant envelope with vocal syllabic modulation
                val = (sin(.pi * t) * 0.75) + 0.25 * sin(8.0 * .pi * t)
            case .futuristic:
                // Warp pulse with rising frequency modulation
                val = 0.4 + 0.5 * sin(2.0 * .pi * (1.0 + 3.0 * t) * t)
            case .cinematic:
                // Swell, sustain, and smooth tail
                val = pow(sin(.pi * t), 1.5) * 0.95
            case .all, .custom:
                val = 0.3 + 0.5 * sin(4.0 * .pi * t)
            }

            samples[i] = Float(max(0.08, min(1.0, abs(val))))
        }
        return samples
    }
}
