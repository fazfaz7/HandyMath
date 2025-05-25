import SwiftUI
import AVFoundation
import Vision

struct GameView: View {
    
    @State private var currentProblem: String = ""
    @State private var correctAnswer: Int = 0
    @State private var score: Int = 0
    @State private var questionCount: Int = 0
    @State private var gameCompleted: Bool = false
    @State private var answerSubmitted: Bool = false
    @State private var showFeedback: Bool = false
    @State private var isAnswerCorrect: Bool = false

    // Finger stability tracking
    @State private var lastDetectedFingers: Int = 0
    @State private var stableStartDate: Date? = nil
    @State private var progress: CGFloat = 0.0

    // Hand-pose bindings
    @State private var handPoseInfo: String = "Show your answer!"
    @State private var handPoints: [CGPoint] = []
    @State private var fingersUp: Int = 0

    // Timer for polling stability
    private let stabilityTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            ScannerView(
                handPoseInfo: $handPoseInfo,
                handPoints: $handPoints,
                fingersUp: $fingersUp
            )
            .edgesIgnoringSafeArea(.all)
            
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack {
                if gameCompleted {
                    // Completion screen
                    VStack(spacing: 20) {
                        Text("Game Over!")
                            .font(.largeTitle)
                            .foregroundColor(.white)

                        Text("Final Score: \(score)/10")
                            .font(.title)
                            .foregroundColor(.white)

                        Button("Play Again") {
                            resetGame()
                        }
                        .font(.title2)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                } else {
                    // Gameplay screen
                    VStack(spacing: 10) {
                        Text("\(questionCount+1) out of 10")
                            .font(.title)
                            .fontDesign(.rounded)
                            .foregroundColor(.white)
                            .padding()

                        Text("\(currentProblem) = ?")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.white)
                            .fontDesign(.rounded)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 25).fill(.darkgreen.opacity(0.85)))
                        

                        Spacer()

                        // Locking circle showing stability progress
                        LockingCircleView(
                            number: answerSubmitted ? lastDetectedFingers : fingersUp,
                            isLocking: !answerSubmitted,
                            progress: progress
                        )
                        .padding(.bottom, 40)
                    }
                }

                // Feedback overlay
                if showFeedback {
                    VStack(spacing: 16) {
                        Image(systemName: isAnswerCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 120))
                            .foregroundColor(isAnswerCorrect ? .green : .red)

                        Text(isAnswerCorrect ? "Correct!" : "Wrong! It was \(correctAnswer)")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .transition(.opacity)
                }
            }
        }
        .onAppear(perform: resetGame)
        .onReceive(stabilityTimer) { _ in
            guard !answerSubmitted, !gameCompleted else { return }
            handleStabilityTick()
        }
    }

    private func handleStabilityTick() {
        let detected = fingersUp
        if detected != lastDetectedFingers {
            // Reset stability tracking
            lastDetectedFingers = detected
            stableStartDate = Date()
            progress = 0
        } else if detected > 0, let start = stableStartDate {
            // Update progress
            let elapsed = Date().timeIntervalSince(start)
            progress = min(1.0, CGFloat(elapsed / 2.0))
            // If stable long enough, submit
            if elapsed >= 2.0 {
                submitAnswer()
            }
        } else {
            // No finger or reset
            progress = 0
            stableStartDate = nil
        }
    }

    private func submitAnswer() {
        answerSubmitted = true
        showFeedback = true
        isAnswerCorrect = (lastDetectedFingers == correctAnswer)
        if isAnswerCorrect {
            SoundManager.shared.playSound(named: "correct")
            score += 1
        } else {
            SoundManager.shared.playSound(named: "incorrect")
        }
        // After 2 seconds, advance
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showFeedback = false
            answerSubmitted = false
            progress = 0
            stableStartDate = nil
            // Advance or finish
            if questionCount < 9 {
                questionCount += 1
                loadNextQuestion()
            } else {
                gameCompleted = true
            }
        }
    }

    private func resetGame() {
        score = 0
        questionCount = 0
        gameCompleted = false
        progress = 0
        lastDetectedFingers = 0
        stableStartDate = nil
        answerSubmitted = false
        showFeedback = false
        loadNextQuestion()
    }

    /// Generates a new + or - question with result constrained between 1 and 5
       private func loadNextQuestion() {
           var a: Int = 0, b: Int = 0, result: Int = 0, op: String = "+"
           repeat {
               let x = Int.random(in: 1...5)
               let y = Int.random(in: 1...5)
               if Bool.random() {
                   op = "+"
                   a = x
                   b = y
                   result = a + b
               } else {
                   op = "-"
                   a = max(x, y)
                   b = min(x, y)
                   result = a - b
               }
           } while !(1...5).contains(result)
           currentProblem = "\(a) \(op) \(b)"
           correctAnswer = result
       }
   
}

struct LockingCircleView: View {
    let number: Int
    let isLocking: Bool
    let progress: CGFloat

    var body: some View {
        ZStack {
            // Outer progress ring
            Circle()
                .trim(from: 0, to: isLocking ? progress : 1)
                .stroke(.goldenyellow, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 125, height: 125)

            // Inner number badge
            Text("\(number)")
                .font(.system(size: 72, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 120, height: 120) // ⬅️ Consistent size
                .background(Circle().fill(.skyblue).shadow(radius: 2))
        }
        .animation(.linear(duration: 0.1), value: progress)
    }
}


#Preview {
    GameView()
}
