//
//  TimerEngine.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassTrax Dev Build 24
//

import SwiftUI
import Combine
import AudioToolbox
import UIKit

final class TimerEngine: ObservableObject {
    
    @Published var now = Date()
    
    private var cancellable: AnyCancellable?
    
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    init() {
        cancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.now = date
            }

#if !targetEnvironment(macCatalyst)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appReturned),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
#endif
    }

#if !targetEnvironment(macCatalyst)
    @objc private func appReturned() {
        now = Date()
    }
#endif

    func triggerAlert(haptic: HapticPattern, sound: SoundPattern) {
        if sound != .none {
            AudioServicesPlaySystemSound(sound.systemID)
        }

        switch haptic {
        case .doubleThump:
#if !targetEnvironment(macCatalyst)
            notificationGenerator.prepare()
            notificationGenerator.notificationOccurred(.success)
#endif
            
        case .triplePulse:
#if !targetEnvironment(macCatalyst)
            notificationGenerator.prepare()
            notificationGenerator.notificationOccurred(.error)
#endif
            
        case .sharpClick:
            playSystemHaptic(1519)
            
        case .heavyImpact:
#if !targetEnvironment(macCatalyst)
            impactGenerator.prepare()
            impactGenerator.impactOccurred()
#endif

        case .lightTap:
#if !targetEnvironment(macCatalyst)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif

        case .rigidTap:
#if !targetEnvironment(macCatalyst)
            if #available(iOS 13.0, *) {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            } else {
                impactGenerator.prepare()
                impactGenerator.impactOccurred()
            }
#endif
            
        case .none:
            break
        }
    }

    private func playSystemHaptic(_ id: SystemSoundID) {
#if targetEnvironment(macCatalyst)
        return
#else
        AudioServicesPlaySystemSound(id)
#endif
    }
}
