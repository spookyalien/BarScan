//
//  ContentView.swift
//  BarScan
//
//  Created by spooky alien on 10/13/23.
//

import SwiftUI
import AVFoundation
import Vision

struct ContentView: View 
{
    @State private var isCameraOpen = false
    @State private var image: UIImage?
    @State private var selection = "-"
    @State private var result_text = [String]()
    @State private var selected_index = 0

    var body: some View 
    {
        NavigationView 
        {
            VStack 
            {
                
                Button(action: { self.check_permission() }) {
                    Text("Scan Barcode")
                }
                .sheet(isPresented: $isCameraOpen) {
                    ImagePickerView(image: $image)
                }
                
//                if let image = image {
//                                    Image(uiImage: image)
//                                        .resizable()
//                                        .scaledToFit()
//                                        .frame(width: 200, height: 200)
//                }
                
                recog_text(image)
                Picker("Text", selection: $selected_index) {
                                ForEach(0 ..< result_text.count, id: \.self) {
                                    Text(self.result_text[$0])
                                }
                            }.pickerStyle(DefaultPickerStyle())
            }
        }
    }
    
    func recog_text(_ image: UIImage?)-> some View
    {
        var recognized_text = ""
        let textRecognitionRequest = VNRecognizeTextRequest { (request, error) in
            // Insert code to process the text recognition results here
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            for observation in observations {
                if let topCandidate = observation.topCandidates(1).first {
                    recognized_text = topCandidate.string
                    result_text.append(recognized_text)
                }
            }
        }
        
        textRecognitionRequest.recognitionLevel = .accurate
        
        if let image = image, let cgImage = image.cgImage {
            let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try imageRequestHandler.perform([textRecognitionRequest])
            } catch {
                print(error)
            }
        }
        
        return Text(recognized_text)
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
                parent.image = pickedImage
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

