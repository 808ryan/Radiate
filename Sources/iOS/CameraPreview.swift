import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let device: AVCaptureDevice?
    let onCaptureRotationAngleChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        view.configure(
            device: device,
            onCaptureRotationAngleChange: onCaptureRotationAngleChange
        )
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.previewLayer.session = session
        view.configure(
            device: device,
            onCaptureRotationAngleChange: onCaptureRotationAngleChange
        )
    }
}

final class PreviewView: UIView {
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private weak var configuredDevice: AVCaptureDevice?
    private var onCaptureRotationAngleChange: ((CGFloat) -> Void)?
    private var lastCaptureRotationAngle: CGFloat?

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    func configure(
        device: AVCaptureDevice?,
        onCaptureRotationAngleChange: @escaping (CGFloat) -> Void
    ) {
        self.onCaptureRotationAngleChange = onCaptureRotationAngleChange

        if let device, configuredDevice !== device {
            configuredDevice = device
            rotationCoordinator = AVCaptureDevice.RotationCoordinator(
                device: device,
                previewLayer: previewLayer
            )
            lastCaptureRotationAngle = nil
        }

        updateRotation()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateRotation()
    }

    private func updateRotation() {
        guard let rotationCoordinator else { return }

        let previewAngle = rotationCoordinator.videoRotationAngleForHorizonLevelPreview
        if let connection = previewLayer.connection,
           connection.isVideoRotationAngleSupported(previewAngle),
           connection.videoRotationAngle != previewAngle {
            connection.videoRotationAngle = previewAngle
        }

        let captureAngle = rotationCoordinator.videoRotationAngleForHorizonLevelCapture
        guard lastCaptureRotationAngle != captureAngle else { return }
        lastCaptureRotationAngle = captureAngle
        onCaptureRotationAngleChange?(captureAngle)
    }
}
