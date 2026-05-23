import AudioToolbox
import AVFoundation
import Foundation
import UIKit

final class ToastedReactor {
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var didAnnounceThisSession = false

    func reset() {
        didAnnounceThisSession = false
    }

    func announceToasted() {
        guard !didAnnounceThisSession else { return }
        didAnnounceThisSession = true

        playBell()
        speakItIsToasted()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func playBell() {
        let soundId: SystemSoundID = 1104
        AudioServicesPlaySystemSound(soundId)
    }

    private func speakItIsToasted() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: "It is toasted!")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speechSynthesizer.speak(utterance)
    }
}

