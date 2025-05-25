import SwiftUI
import AVFoundation
import Vision

struct ScannerView: UIViewControllerRepresentable {
    
    @Binding var handPoseInfo: String
    @Binding var handPoints: [CGPoint]
    @Binding var fingersUp: Int
    
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

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }
            self.detectHandPose(in: pixelBuffer)
        }

        func detectHandPose(in pixelBuffer: CVPixelBuffer) {
            let request = VNDetectHumanHandPoseRequest { (request, error) in
                guard let observations = request.results as? [VNHumanHandPoseObservation], !observations.isEmpty else {
                    DispatchQueue.main.async {
                        self.parent.handPoseInfo = "No hand detected"
                        self.parent.handPoints = []
                        self.parent.fingersUp = 0
                    }
                    return
                }
                
                if let observation = observations.first {
                    var points: [CGPoint] = []
                    var fingerTips: [CGPoint] = []
                    var mcpPoints: [CGPoint] = []
                    
                    // Get all joints
                    let allJoints: [VNHumanHandPoseObservation.JointName] = [
                        .wrist,
                        .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
                        .indexMCP, .indexPIP, .indexDIP, .indexTip,
                        .middleMCP, .middlePIP, .middleDIP, .middleTip,
                        .ringMCP, .ringPIP, .ringDIP, .ringTip,
                        .littleMCP, .littlePIP, .littleDIP, .littleTip
                    ]
                    
                    // Store points for all joints
                    for joint in allJoints {
                        if let recognizedPoint = try? observation.recognizedPoint(joint), recognizedPoint.confidence > 0.5 {
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
                        self.parent.handPoseInfo = "\(fingersCount) finger(s) up"
                    }
                }
            }

            request.maximumHandCount = 1

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
            
            // Check each finger (skip thumb as it's handled differently)
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
                print("hola")
            } else {
                let thumbExtended = fingerTips[0].x < mcpPoints[0].x
                if thumbExtended {
                    count += 1
                }
            }
            
           
            return count
        }

        func convertVisionPoint(_ point: CGPoint) -> CGPoint {
            let screenSize = UIScreen.main.bounds.size
            let y = point.x * screenSize.height
            let x = screenSize.width - (point.y * screenSize.width)
            return CGPoint(x: x, y: y)
        }
    }
}
