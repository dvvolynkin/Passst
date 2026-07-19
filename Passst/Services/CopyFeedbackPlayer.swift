import AVFoundation
import Foundation

@MainActor
final class CopyFeedbackPlayer {
    static let shared = CopyFeedbackPlayer()

    private lazy var player: AVAudioPlayer? = {
        let systemSoundURL = URL(
            fileURLWithPath: "/System/Library/Sounds/Pop.aiff",
            isDirectory: false
        )
        guard let player = try? AVAudioPlayer(contentsOf: systemSoundURL) else {
            return nil
        }
        player.volume = 0.65
        player.prepareToPlay()
        return player
    }()

    private init() {}

    func play() {
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
