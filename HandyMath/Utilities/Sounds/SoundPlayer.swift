//
//  SoundPlayer.swift
//  HandPoseDetection
//
//  Created by Adrian Emmanuel Faz Mercado on 25/05/25.
//

import Foundation
import AVFoundation

// Sound Manager to play correct and incorrect sounds.
class SoundManager {
    static let shared = SoundManager()

    private var player: AVAudioPlayer?

    func playSound(named name: String, type: String = "wav") {
        guard let url = Bundle.main.url(forResource: name, withExtension: type) else {
            print("Sound file \(name).\(type) not found.")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("Failed to play sound: \(error.localizedDescription)")
        }
    }
}
