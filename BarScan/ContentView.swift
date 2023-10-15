import SwiftUI
import AVFoundation
import Vision
import CoreImage

struct ContentView: View {
    @State private var isCameraOpen = false
    @State private var image: UIImage?
    @State private var barcode: UIImage?
    @State private var selected_index = 0
    @State private var recognizedTexts = [String]()
    @State private var selectedText: String = ""
    @State private var isImageVisible = false

    var body: some View {
        NavigationView {
            VStack {
                Button(action: { check_permission() }) {
                    Text("Scan Barcode")
                }
                .sheet(isPresented: $isCameraOpen) {
                    ImagePickerView(image: $image, recognizedTexts: $recognizedTexts)
                }
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                }
                
                Picker("Text", selection: $selected_index) {
                    ForEach(0 ..< recognizedTexts.count, id: \.self) { index in
                        Text(recognizedTexts[index]).tag(index)
                    }
                }
                .pickerStyle(DefaultPickerStyle())
                .onChange(of: selected_index) {
                    selectedText = recognizedTexts[selected_index]
                    let processed_input = process_string(mStr: selectedText)
                    barcode = generateBarcode(from: processed_input)
                }
                
                Button(action: {
                    isImageVisible = true
                }) {
                    Text("Generate Barcode(s)")
                }
                
                if isImageVisible {
                    if let barcode =  barcode{
                        Image(uiImage: barcode)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 500, height: 200)
                    }
                
                }
            }
        }
    }

    func check_permission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                self.isCameraOpen.toggle()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if granted {
                        self.isCameraOpen.toggle()
                    } else {
                        exit(0)
                    }
                }
            case .denied, .restricted:
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            @unknown default:
                break
        }
    }
}

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var recognizedTexts: [String]

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Update the view controller if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let pickedImage = info[.originalImage] as? UIImage {
                self.parent.image = pickedImage
                self.recognizeText(in: pickedImage)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }

        func recognizeText(in image: UIImage) {
            let textRecognitionRequest = VNRecognizeTextRequest { [self] request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

                for observation in observations {
                    if let topCandidate = observation.topCandidates(1).first {
                        let recognizedText = topCandidate.string
                        if (recognizedText.count < 9) {
                            continue
                        }
                        if (!self.parent.recognizedTexts.contains(recognizedText)) {
                            let text_split_arr = recognizedText.components(separatedBy: "|")
                            for text_result in text_split_arr {
                                self.parent.recognizedTexts.append(text_result)                     //  002344242 | 0234322344
                            }
                        }
                    }
                }
            }

            textRecognitionRequest.recognitionLevel = .accurate

            if let cgImage = image.cgImage {
                let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

                do {
                    try imageRequestHandler.perform([textRecognitionRequest])
                } catch {
                    print(error)
                }
            }
        }
    }
}

func generateBarcode(from string: String) -> UIImage? {

    let data = string.data(using: String.Encoding.ascii)

    if let filter = CIFilter(name: "CICode128BarcodeGenerator") {
        filter.setDefaults()
        //Margin
        filter.setValue(7.00, forKey: "inputQuietSpace")
        filter.setValue(data, forKey: "inputMessage")
        //Scaling
        let transform = CGAffineTransform(scaleX: 3, y: 3)

        if let output = filter.outputImage?.transformed(by: transform) {
            let context:CIContext = CIContext.init(options: nil)
            let cgImage:CGImage = context.createCGImage(output, from: output.extent)!
            let rawImage:UIImage = UIImage.init(cgImage: cgImage)

            //Refinement code to allow conversion to NSData or share UIImage. Code here:
            //http://stackoverflow.com/questions/2240395/uiimage-created-from-cgimageref-fails-with-uiimagepngrepresentation
            let cgimage: CGImage = (rawImage.cgImage)!
            let cropZone = CGRect(x: 0, y: 0, width: Int(rawImage.size.width), height: Int(rawImage.size.height))
            let cWidth: size_t  = size_t(cropZone.size.width)
            let cHeight: size_t  = size_t(cropZone.size.height)
            let bitsPerComponent: size_t = cgimage.bitsPerComponent
            //THE OPERATIONS ORDER COULD BE FLIPPED, ALTHOUGH, IT DOESN'T AFFECT THE RESULT
            let bytesPerRow = (cgimage.bytesPerRow) / (cgimage.width  * cWidth)

            let context2: CGContext = CGContext(data: nil, width: cWidth, height: cHeight, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: cgimage.bitmapInfo.rawValue)!

            context2.draw(cgimage, in: cropZone)

            let result: CGImage  = context2.makeImage()!
            let finalImage = UIImage(cgImage: result)

            return finalImage

        }
    }
    print("error 2214")

    return nil
}

func process_string(mStr: String) -> String {
    let filteredChar = mStr.filter { !$0.isWhitespace && $0 != "-" }
    return String(filteredChar)
}
