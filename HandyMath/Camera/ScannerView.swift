import SwiftUI
import AVFoundation
import Vision

struct ScannerView: UIViewControllerRepresentable {
    
    // All the detected joint points in the hand
    @Binding var handPoints: [CGPoint]
    
    // How many fingers are detected as up.
    @Binding var fingersUp: Int
    
    // Management of the camera for live detection.
    let captureSession = AVCaptureSession()
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              captureSession.canAddInput(videoInput) else {
            return viewController
        }
        
        captureSession.addInput(videoInput)
        
        let videoOutput = AVCaptureVideoDataOutput()
        
        if captureSession.canAddOutput(videoOutput) {
            videoOutput.setSampleBufferDelegate(context.coordinator, queue: DispatchQueue(label: "videoQueue"))
            captureSession.addOutput(videoOutput)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = viewController.view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        viewController.view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }

        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var parent: ScannerView

        init(_ parent: ScannerView) {
            self.parent = parent
        }

        // It is called every time that a new camera frame is available
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }
            self.detectHandPose(in: pixelBuffer)
        }

        // Function that uses Vision Framework to detect hand joints
        func detectHandPose(in pixelBuffer: CVPixelBuffer) {
            let request = VNDetectHumanHandPoseRequest { (request, error) in
                guard let observations = request.results as? [VNHumanHandPoseObservation], !observations.isEmpty else {
                    DispatchQueue.main.async {
                        self.parent.handPoints = []
                        self.parent.fingersUp = 0
                    }
                    return
                }
                
                if let observation = observations.first {
                    var points: [CGPoint] = []
                    var fingerTips: [CGPoint] = []
                    var mcpPoints: [CGPoint] = []
                    
                    // The joints that are tracked (but I am only using the tips and the mcps.R
                    let allJoints: [VNHumanHandPoseObservation.JointName] = [
                        .wrist,
                        .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
                        .indexMCP, .indexPIP, .indexDIP, .indexTip,
                        .middleMCP, .middlePIP, .middleDIP, .middleTip,
                        .ringMCP, .ringPIP, .ringDIP, .ringTip,
                        .littleMCP, .littlePIP, .littleDIP, .littleTip
                    ]
                    
                    // Convert Vision points to screen coordinates and collect them
                    for joint in allJoints {
                        if let recognizedPoint = try? observation.recognizedPoint(joint), recognizedPoint.confidence > 0.65 {
                            let convertedPoint = self.convertVisionPoint(recognizedPoint.location)
                            points.append(convertedPoint)
                            
                            // Store finger tips and MCP joints for finger counting
                            if joint == .thumbTip || joint == .indexTip || joint == .middleTip ||
                               joint == .ringTip || joint == .littleTip {
                                fingerTips.append(convertedPoint)
                            }
                            
                            if joint == .thumbMP || joint == .indexMCP || joint == .middleMCP ||
                               joint == .ringMCP || joint == .littleMCP {
                                mcpPoints.append(convertedPoint)
                            }
                        }
                    }
                    
                    // Count fingers up
                    let fingersCount = self.countFingersUp(fingerTips: fingerTips, mcpPoints: mcpPoints)
                    
                    DispatchQueue.main.async {
                        self.parent.handPoints = points
                        self.parent.fingersUp = fingersCount
                    }
                }
            }

            request.maximumHandCount = 1 // We only detect on hand at a time.

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("Hand pose detection failed: \(error)")
            }
        }
        
        // Count how many fingers are up
        func countFingersUp(fingerTips: [CGPoint], mcpPoints: [CGPoint]) -> Int {
            guard fingerTips.count == 5 && mcpPoints.count == 5 else {
                return 0
            }
            
            var count = 0
            
            // For fingers 1 to 4 (index to little), a finger is up if the tip is higher (y is smaller) than its MCP
            for i in 1..<5 {
                // A finger is considered "up" if its tip is above its MCP joint
                if fingerTips[i].y < mcpPoints[i].y {
                    count += 1
                }
            }
            
            // Special handling for thumb - check if it's extended to the side
            if fingerTips[0].x > fingerTips[4].x {
                let thumbExtended = fingerTips[0].x > mcpPoints[0].x
                if thumbExtended {
                    count += 1
                }
            } else {
                // if the hand is left
                let thumbExtended = fingerTips[0].x < mcpPoints[0].x
                if thumbExtended {
                    count += 1
                }
            }
            
           
            return count
        }

        // Converts a Vision point (normalized 0-1) to screen coordinates
        func convertVisionPoint(_ point: CGPoint) -> CGPoint {
            let screenSize = UIScreen.main.bounds.size
            let y = point.x * screenSize.height
            let x = screenSize.width - (point.y * screenSize.width)
            return CGPoint(x: x, y: y)
        }
    }
}
