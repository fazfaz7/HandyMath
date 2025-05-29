import SwiftUI
import AVFoundation
import Vision


// Game view where users solve math problems with their fingers.
struct GameView: View {
    
    // Current math problem shown to the user.
    @State private var currentProblem: String = ""
    
    // Correct answer to the current problem.
    @State private var correctAnswer: Int = 0
    
    // Player's current score
    @State private var score: Int = 0
    
    // Questions answered so far
    @State private var questionCount: Int = 0
    
    // Bool to show the game over screen.
    @State private var gameCompleted: Bool = false
    
    // Bool that states if the answer has already been submitted.
    @State private var answerSubmitted: Bool = false
    
    // Bool that controls the feedback (correct or wrong)
    @State private var showFeedback: Bool = false
    
    // Bool to save if last answer was correct.
    @State private var isAnswerCorrect: Bool = false

    // Tracks the last "stable" number of fingers detected.
    @State private var lastDetectedFingers: Int = 0
    
    // Tracks at that time did the last stable detection start.
    @State private var stableStartDate: Date? = nil
    
    // Value between 0.0 and 1.0 that represents the progress of stability.
    @State private var progress: CGFloat = 0.0

    // All the detected joint points in the hand
    @State private var handPoints: [CGPoint] = []
    
    // Number of fingers that are currently detected as "up"
    @State private var fingersUp: Int = 0

    // Timer that checks every 0.1s if the hand is stable enough
    private let stabilityTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {

            // Live camera preview and hand tracking.
            ScannerView(
                handPoints: $handPoints,
                fingersUp: $fingersUp
            )
            .edgesIgnoringSafeArea(.all)
            
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Main game interface
            VStack {
                // If the game is completed, show the result of the user.
                if gameCompleted {
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

                        // Circle that fills up when the finger count is stable
                        LockingCircleView(
                            number: answerSubmitted ? lastDetectedFingers : fingersUp,
                            isLocking: !answerSubmitted,
                            progress: progress
                        )
                        .padding(.bottom, 40)
                    }
                }

                // Feedback when the user submits an answer.
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

    // Function called every 0.1s to check if the user is holding a number steadily
    private func handleStabilityTick() {
        let detected = fingersUp
        if detected != lastDetectedFingers {
            // If the user changed the number we reset the timer
            lastDetectedFingers = detected
            stableStartDate = Date()
            progress = 0
        } else if detected > 0, let start = stableStartDate {
            // Keep updating progress
            let elapsed = Date().timeIntervalSince(start)
            progress = min(1.0, CGFloat(elapsed / 2.0))
            // After 2 seconds of having the same answer → we submit it.
            if elapsed >= 2.0 {
                submitAnswer()
            }
        } else {
            // If there are no hands detected, reset.
            progress = 0
            stableStartDate = nil
        }
    }

    // Submits the current answer and shows feedback
    private func submitAnswer() {
        answerSubmitted = true
        showFeedback = true
        isAnswerCorrect = (lastDetectedFingers == correctAnswer)
        
        // If the answer is correct, we play the corresponding sound.
        if isAnswerCorrect {
            SoundManager.shared.playSound(named: "correct")
            score += 1
        } else {
            SoundManager.shared.playSound(named: "incorrect")
        }
        // After 2 seconds, we go to the next question.
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

    // Resets the game to the initial state
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

    // Generates a random sum or subtraction question with result constrained between 1 and 5
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

// Circular progress view that locks the answer when stable. (2 seconds)
struct LockingCircleView: View {
    let number: Int
    let isLocking: Bool
    let progress: CGFloat

    var body: some View {
        ZStack {
            // Outer ring showing progress as a circle
            Circle()
                .trim(from: 0, to: isLocking ? progress : 1)
                .stroke(.goldenyellow, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 125, height: 125)

            // Number displayed in the center
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
