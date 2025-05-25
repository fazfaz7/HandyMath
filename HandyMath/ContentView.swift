import AVFoundation
import SwiftUI
import Vision

struct ContentView: View {
    @State private var isGameActive = false

    var body: some View {
        Group {
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

