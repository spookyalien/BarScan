import SwiftUI
import AVFoundation
import Vision
import CoreImage
import Foundation

struct ContentView: View {
    @State private var cam_open = false
    @State private var image: UIImage?
    @State private var barcode: UIImage?
    @State private var selected_index = 0
    @State private var recognizedTexts = [String]()
    @State private var selected_text: String = ""
    @State private var img_visible = false
    @State private var scale_effect = 0.5

    var body: some View {
        NavigationView {
            VStack {
                Button(action: { check_permission() }) {
                    Text("Scan Barcode")
                }
                .sheet(isPresented: $cam_open) {
                    img_capture(image: $image, recognizedTexts: $recognizedTexts)
                }
                
                
                Picker("Text", selection: $selected_index) {
                    Text("Select Option").tag(0)
                    if recognizedTexts.count > 1 {
                            ForEach(1 ..< recognizedTexts.count, id: \.self) { index in
                                Text(recognizedTexts[index]).tag(index)
                            }
                    }
                }
                .pickerStyle(DefaultPickerStyle())
                .onChange(of: selected_index) {
                    selected_text = recognizedTexts[selected_index]
                    barcode = gen_barcode(from: selected_text)
                    if (selected_text.count > 10) {
                        scale_effect = 0.8
                    }
                    else {
                        scale_effect = 0.5
                    }
                }
                
                Button(action: {
                    img_visible = true
                }) {
                    Text("Generate Barcode(s)")
                }
                
                if img_visible {
                    if let barcode =  barcode{
                        Image(uiImage: barcode)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale_effect)
                    }
                
                }
            }
        }
    }

    func check_permission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                self.cam_open.toggle()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if granted {
                        self.cam_open.toggle()
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

struct img_capture: UIViewControllerRepresentable {
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

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate 
    {
        var parent: img_capture

        init(_ parent: img_capture) 
        {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) 
        {
            if let pickedImage = info[.originalImage] as? UIImage {
                self.parent.image = pickedImage
                self.recog_text(in: pickedImage)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) 
        {
            picker.dismiss(animated: true)
        }

        func recog_text(in image: UIImage) 
        {
            let patterns = [
                "^\\d{9}$",
                "^\\d{2}[A-Za-z]\\d{3}[A-Za-z]\\d{2}$",
                "^SHP[A-Za-z]{2}\\d{2}$",
                "SHP[A-Za-z]{2}$"
            ]
            
            let textRecognitionRequest = VNRecognizeTextRequest 
            { [self] request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

                for observation in observations {
                    if let topCandidate = observation.topCandidates(1).first {
                        let recognizedText = topCandidate.string
                        let processed_input = process_string(mStr: recognizedText)
                        
                        
                        if (!self.parent.recognizedTexts.contains(processed_input)) {
                            let text_split_arr = processed_input.components(separatedBy: CharacterSet(charactersIn: "|:"))
                            for text_result in text_split_arr {
                                var match = false
                                for pattern in patterns {
                                    print(text_result)
                                    if text_result.range(of: pattern, options: .regularExpression, range: nil, locale: nil) != nil {
                                        match = true
                                        print(match)
                                        break
                                    }
                                }
                                if match {
                                    self.parent.recognizedTexts.append(text_result)
                                }
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

func gen_barcode(from string: String) -> UIImage? 
{

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
    
    return nil
}

func process_string(mStr: String) -> String 
{
    let filteredChar = mStr.filter { !$0.isWhitespace && $0 != "-" }
    return String(filteredChar)
}
