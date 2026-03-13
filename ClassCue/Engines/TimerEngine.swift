//
//  TimerEngine.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassCue Dev Build 24
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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appReturned),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appReturned() {
        now = Date()
    }
    
    func triggerAlert(haptic: HapticPattern, sound: SoundPattern) {
        
        if sound != .none {
            AudioServicesPlaySystemSound(sound.systemID)
        }
        
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

        case .lightTap:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

        case .rigidTap:
            if #available(iOS 13.0, *) {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            } else {
                impactGenerator.prepare()
                impactGenerator.impactOccurred()
            }
            
        case .none:
            break
        }
    }
}
