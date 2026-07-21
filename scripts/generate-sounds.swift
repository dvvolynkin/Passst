#!/usr/bin/env swift

import Foundation

let sampleRate = 48_000
let duration = 0.14
let sampleCount = Int(Double(sampleRate) * duration)
let twoPi = Double.pi * 2

var noiseState: UInt64 = 0x5041_5353_5354
func noise() -> Double {
    noiseState = noiseState &* 6_364_136_223_846_793_005 &+ 1
    let normalized = Double((noiseState >> 32) & 0xFFFF) / 65_535
    return (normalized * 2) - 1
}

func strike(
    time: Double,
    start: Double,
    noiseSample: Double,
    baseFrequency: Double,
    brightness: Double,
    gain: Double
) -> Double {
    let elapsed = time - start
    guard elapsed >= 0 else { return 0 }

    let transient = noiseSample * exp(-elapsed * 1_250) * 0.56
    let body = sin(twoPi * baseFrequency * elapsed) * exp(-elapsed * 92) * 0.34
    let upper = sin(twoPi * baseFrequency * 2.73 * elapsed + 0.42)
        * exp(-elapsed * 168)
        * brightness
    return (transient + body + upper) * gain
}

var samples = [Double]()
samples.reserveCapacity(sampleCount)

for index in 0..<sampleCount {
    let time = Double(index) / Double(sampleRate)
    let noiseSample = noise()
    let press = strike(
        time: time,
        start: 0,
        noiseSample: noiseSample,
        baseFrequency: 2_450,
        brightness: 0.22,
        gain: 0.72
    )
    let latch = strike(
        time: time,
        start: 0.031,
        noiseSample: noiseSample,
        baseFrequency: 1_120,
        brightness: 0.18,
        gain: 1
    )
    let caseResonance = time >= 0.031
        ? sin(twoPi * 520 * (time - 0.031)) * exp(-(time - 0.031) * 46) * 0.12
        : 0
    samples.append(tanh((press + latch + caseResonance) * 1.35))
}

let peak = samples.map(abs).max() ?? 1
let scale = peak > 0 ? 0.86 / peak : 1

var pcm = Data()
pcm.reserveCapacity(sampleCount * 2)
for sample in samples {
    var value = Int16((sample * scale * Double(Int16.max)).rounded()).littleEndian
    withUnsafeBytes(of: &value) { pcm.append(contentsOf: $0) }
}

func appendASCII(_ string: String, to data: inout Data) {
    data.append(contentsOf: string.utf8)
}

func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var encoded = value.littleEndian
    withUnsafeBytes(of: &encoded) { data.append(contentsOf: $0) }
}

var wav = Data()
appendASCII("RIFF", to: &wav)
appendLittleEndian(UInt32(36 + pcm.count), to: &wav)
appendASCII("WAVE", to: &wav)
appendASCII("fmt ", to: &wav)
appendLittleEndian(UInt32(16), to: &wav)
appendLittleEndian(UInt16(1), to: &wav)
appendLittleEndian(UInt16(1), to: &wav)
appendLittleEndian(UInt32(sampleRate), to: &wav)
appendLittleEndian(UInt32(sampleRate * 2), to: &wav)
appendLittleEndian(UInt16(2), to: &wav)
appendLittleEndian(UInt16(16), to: &wav)
appendASCII("data", to: &wav)
appendLittleEndian(UInt32(pcm.count), to: &wav)
wav.append(pcm)

let rootURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let outputURL = rootURL
    .appendingPathComponent("Passst/Resources/ClipboardCopy.wav")
try wav.write(to: outputURL, options: .atomic)
print(outputURL.path)
