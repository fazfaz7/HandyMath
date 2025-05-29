import AVFoundation
import SwiftUI
import Vision

struct ContentView: View {
    // Variable to control the start of the game.
    @State private var isGameActive = false

    var body: some View {
        Group {
            // If the user started the game, show GameView
            if isGameActive {
                GameView()
            } else {
                MainView(startAction: {
                    isGameActive = true
                })
            }
        }
        .animation(.easeInOut, value: isGameActive)
    }
}

