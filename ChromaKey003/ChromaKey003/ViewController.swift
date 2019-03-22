import AVFoundation
import UIKit

class ViewController: UIViewController {

    @IBOutlet private weak var imageView: UIImageView!

    private let captureSession = AVCaptureSession()
    private let videoDevice = AVCaptureDevice.default(for: AVMediaType.video)!
    private let backgroundCIImage = CIImage(image: UIImage(named: "background")!)!
    private var videoOutput = AVCaptureVideoDataOutput()

    private let chromaKeyCIFilter = ChromaKeyFilterFactory.make(fromHue: 0.3, toHue: 0.4)
    private let compositorCIFilter = CIFilter(name:"CISourceOverCompositing")
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice) as AVCaptureDeviceInput
            captureSession.addInput(videoInput)
        } catch let error as NSError {
            print(error)
        }

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String : Int(kCVPixelFormatType_32BGRA)]

        let queue = DispatchQueue(label: "myqueue", attributes: .concurrent)
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.alwaysDiscardsLateVideoFrames = true

        captureSession.addOutput(videoOutput)

        for connection in videoOutput.connections {
            let conn = connection
            if conn.isVideoOrientationSupported {
                conn.videoOrientation = AVCaptureVideoOrientation.portrait
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        captureSession.startRunning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession.stopRunning()
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> CIImage {
    let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
    CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
    let baseAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
    let width = CVPixelBufferGetWidth(imageBuffer)
    let height = CVPixelBufferGetHeight(imageBuffer)

    let bitmapInfo = (CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
    let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
    let imageRef = context!.makeImage()

    CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
    return CIImage(cgImage: imageRef!)
}

private func filter(foregroundCIImage: CIImage, backgroundCIImage: CIImage) -> CIImage? {
    guard let chromaKeyCIFilter = chromaKeyCIFilter,
        let compositorCIFilter = compositorCIFilter else { return nil }

    chromaKeyCIFilter.setValue(foregroundCIImage, forKey: kCIInputImageKey)
    let sourceCIImageWithoutBackground = chromaKeyCIFilter.outputImage

    compositorCIFilter.setValue(sourceCIImageWithoutBackground, forKey: kCIInputImageKey)
    compositorCIFilter.setValue(backgroundCIImage, forKey: kCIInputBackgroundImageKey)
    return compositorCIFilter.outputImage
}

func captureOutput(_ output: AVCaptureOutput,
                   didOutput sampleBuffer: CMSampleBuffer,
                   from connection: AVCaptureConnection) {
    let ciImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer)
    let filteredCIImage = filter(foregroundCIImage: ciImage,
                                 backgroundCIImage: backgroundCIImage)!
    let uiImage = UIImage(ciImage: filteredCIImage)
    DispatchQueue.main.sync(execute: {
        imageView.image = uiImage
    })
}
}
