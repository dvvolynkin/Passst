import AppKit
import Foundation

@MainActor
final class CopyFeedbackPlayer {
    static let shared = CopyFeedbackPlayer()

    private lazy var sound: NSSound? = {
        let systemSoundURL = URL(
            fileURLWithPath: "/System/Library/Sounds/Pop.aiff",
            isDirectory: false
        )
        let sound = NSSound(contentsOf: systemSoundURL, byReference: true)
            ?? NSSound(named: NSSound.Name("Pop"))
        sound?.volume = 0.52
        return sound
    }()

    private init() {}

    func play() {
        guard UserDefaults.standard.object(forKey: PreferencesKey.copySoundEnabled) == nil
            || UserDefaults.standard.bool(forKey: PreferencesKey.copySoundEnabled)
        else {
            return
        }
        sound?.stop()
        sound?.play()
    }
}
