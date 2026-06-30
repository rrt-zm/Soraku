import Foundation
import AVFoundation

@MainActor
final class AudioService {
    private let engine = AVAudioEngine()
    private let ambientPlayer = AVAudioPlayerNode()
    private let effectPlayer = AVAudioPlayerNode()
    private let ambientMixer = AVAudioMixerNode()
    private let effectMixer = AVAudioMixerNode()
    private var started = false
    private let sampleRate: Double = 44100

    var soundEnabled = true
    var musicEnabled = true
    var ambienceEnabled = true
    var soundscape = "sound_bell"

    private var format: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }

    func configure() {
        guard !started else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch { }

        engine.attach(ambientPlayer)
        engine.attach(effectPlayer)
        engine.attach(ambientMixer)
        engine.attach(effectMixer)
        let fmt = format
        engine.connect(ambientPlayer, to: ambientMixer, format: fmt)
        engine.connect(effectPlayer, to: effectMixer, format: fmt)
        engine.connect(ambientMixer, to: engine.mainMixerNode, format: fmt)
        engine.connect(effectMixer, to: engine.mainMixerNode, format: fmt)
        ambientMixer.outputVolume = 0.0
        effectMixer.outputVolume = 0.8
        do {
            try engine.start()
            started = true
            startAmbientLoop()
        } catch { }
    }

    func updateSettings(sound: Bool, music: Bool, ambience: Bool, soundscape: String) {
        soundEnabled = sound
        musicEnabled = music
        ambienceEnabled = ambience
        self.soundscape = soundscape
        ambientMixer.outputVolume = ambience ? 0.16 : 0.0
        effectMixer.outputVolume = sound ? 0.8 : 0.0
    }

    private func startAmbientLoop() {
        guard let buffer = makeAmbientBuffer() else { return }
        ambientPlayer.scheduleBuffer(buffer, at: nil, options: [.loops])
        ambientPlayer.play()
    }

    private func makeAmbientBuffer() -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(sampleRate * 4.0)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        guard let data = buffer.floatChannelData?[0] else { return nil }
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func noise() -> Float {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            return Float(Int64(bitPattern: seed)) / Float(Int64.max)
        }
        var low: Float = 0
        let n = Int(frames)
        for i in 0..<n {
            let raw = noise()
            low += (raw - low) * 0.04
            let t = Double(i) / Double(n)
            let breath = Float(0.5 + 0.5 * sin(t * 2 * Double.pi))
            data[i] = low * 0.6 * (0.5 + 0.5 * breath)
        }
        let fade = min(2000, n / 8)
        for i in 0..<fade {
            let g = Float(i) / Float(fade)
            data[i] *= g
            data[n - 1 - i] *= g
        }
        return buffer
    }

    func playChime() {
        guard soundEnabled, started else { return }
        let partials: [(Float, Float)] = [(880, 1.0), (1320, 0.5), (1760, 0.3), (2640, 0.15)]
        schedule(makeTone(duration: 1.6, partials: partials, decay: 2.6, amplitude: 0.35))
    }

    func playBrush() {
        guard soundEnabled, started else { return }
        schedule(makeBrush(duration: 0.22, amplitude: 0.2))
    }

    func playBlot() {
        guard soundEnabled, started else { return }
        schedule(makeTone(duration: 0.5, partials: [(160, 1.0), (90, 0.6)], decay: 5.0, amplitude: 0.3))
    }

    func playSeal() {
        guard soundEnabled, started else { return }
        schedule(makeTone(duration: 0.9, partials: [(330, 1.0), (220, 0.6), (660, 0.25)], decay: 4.0, amplitude: 0.4))
    }

    func playSoft() {
        guard soundEnabled, started else { return }
        schedule(makeTone(duration: 0.4, partials: [(520, 1.0), (780, 0.4)], decay: 6.0, amplitude: 0.18))
    }

    private func schedule(_ buffer: AVAudioPCMBuffer?) {
        guard let buffer else { return }
        if !effectPlayer.isPlaying { effectPlayer.play() }
        effectPlayer.scheduleBuffer(buffer, at: nil, options: [.interrupts])
    }

    private func makeTone(duration: Double, partials: [(Float, Float)], decay: Float, amplitude: Float) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        guard let data = buffer.floatChannelData?[0] else { return nil }
        let n = Int(frames)
        for i in 0..<n {
            let t = Float(i) / Float(sampleRate)
            let env = expf(-decay * t)
            var sample: Float = 0
            for (freq, weight) in partials {
                sample += weight * sinf(2 * .pi * freq * t)
            }
            data[i] = sample * env * amplitude / Float(partials.count)
        }
        return buffer
    }

    private func makeBrush(duration: Double, amplitude: Float) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        guard let data = buffer.floatChannelData?[0] else { return nil }
        var seed: UInt64 = 0xD1B54A32D192ED03
        func noise() -> Float {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            return Float(Int64(bitPattern: seed)) / Float(Int64.max)
        }
        var low: Float = 0
        let n = Int(frames)
        for i in 0..<n {
            let t = Float(i) / Float(n)
            let env = sinf(.pi * t)
            low += (noise() - low) * 0.2
            data[i] = low * env * amplitude
        }
        return buffer
    }
}
