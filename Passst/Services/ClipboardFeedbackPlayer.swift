import AVFoundation
import Foundation

@MainActor
final class ClipboardFeedbackPlayer {
    static let shared = ClipboardFeedbackPlayer()

    private lazy var copyPlayer = makePlayer(
        url: Bundle.main.url(forResource: "ClipboardCopy", withExtension: "wav")
            ?? systemSoundURL(named: "Pop"),
        volume: 0.8
    )
    private lazy var pastePlayer = makePlayer(
        url: systemSoundURL(named: "Tink"),
        volume: 0.35
    )

    private init() {}

    func playCopy() {
        play(copyPlayer)
    }

    func playPaste() {
        play(pastePlayer)
    }

    private func systemSoundURL(named name: String) -> URL {
        URL(
            fileURLWithPath: "/System/Library/Sounds/\(name).aiff",
            isDirectory: false
        )
    }

    private func makePlayer(url: URL, volume: Float) -> AVAudioPlayer? {
        guard let player = try? AVAudioPlayer(contentsOf: url) else {
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
