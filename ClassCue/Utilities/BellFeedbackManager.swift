//
//  BellFeedbackManager.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 10, 2026
//  Build: ClassCue Dev Build 23
//

import Foundation
import UIKit
import AVFoundation
import AudioToolbox

final class BellFeedbackManager {
    static let shared = BellFeedbackManager()

    private init() { }

    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private var audioPlayer: AVAudioPlayer?

    func playSelectedBellFeedback() {
        let defaults = UserDefaults.standard

        let hapticRaw = defaults.string(forKey: "pref_haptic") ?? HapticPattern.doubleThump.rawValue
        let soundRaw = defaults.string(forKey: "pref_sound") ?? SoundPattern.classicAlarm.rawValue

        let haptic = HapticPattern(rawValue: hapticRaw) ?? .doubleThump
        let bellSound = BellSound.fromStoredPreference(soundRaw)

        play(haptic: haptic, bellSound: bellSound)
    }

    func play(haptic: HapticPattern, bellSound: BellSound) {
        configureAudioSession()
        playBundledSound(bellSound)
        playHaptic(haptic)
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error.localizedDescription)")
        }
    }

    private func playBundledSound(_ bellSound: BellSound) {
        guard let fileName = bellSound.fileName else { return }

        let parts = fileName.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            print("Invalid bundled bell sound name: \(fileName)")
            return
        }

        let name = String(parts[0])
        let ext = String(parts[1])

        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("Missing bundled bell sound: \(fileName)")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            print("Playing bundled bell sound: \(fileName)")
        } catch {
            print("Unable to play bundled sound \(fileName): \(error.localizedDescription)")
        }
    }

    private func playHaptic(_ haptic: HapticPattern) {
        switch haptic {
        case .doubleThump:
            notificationGenerator.prepare()
            notificationGenerator.notificationOccurred(.success)

        case .triplePulse:
            notificationGenerator.prepare()
            notificationGenerator.notificationOccurred(.error)

        case .sharpClick:
            AudioServicesPlaySystemSound(1519)

        case .heavyImpact:
            impactGenerator.prepare()
            impactGenerator.impactOccurred()

        case .none:
            break
        }
    }
}
