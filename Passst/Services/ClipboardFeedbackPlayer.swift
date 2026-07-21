import AVFoundation
import Foundation

@MainActor
final class ClipboardFeedbackPlayer {
    static let shared = ClipboardFeedbackPlayer()

    private lazy var copyPlayer = makePlayer(named: "Pop", volume: 0.65)
    private lazy var pastePlayer = makePlayer(named: "Tink", volume: 0.35)

    private init() {}

    func playCopy() {
        play(copyPlayer)
    }

    func playPaste() {
        play(pastePlayer)
    }

    private func makePlayer(named name: String, volume: Float) -> AVAudioPlayer? {
        let systemSoundURL = URL(
            fileURLWithPath: "/System/Library/Sounds/\(name).aiff",
            isDirectory: false
        )
        guard let player = try? AVAudioPlayer(contentsOf: systemSoundURL) else {
            return nil
        }
        player.volume = volume
        player.prepareToPlay()
        return player
    }

    private func play(_ player: AVAudioPlayer?) {
        guard UserDefaults.standard.object(forKey: PreferencesKey.copySoundEnabled) == nil
            || UserDefaults.standard.bool(forKey: PreferencesKey.copySoundEnabled)
        else {
            return
        }
        player?.stop()
        player?.currentTime = 0
        player?.play()
    }
}
