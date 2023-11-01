import SwiftUI
import Vision


/*
    This view is activated when the camera is requested and stores the users image
    to the class variable to be immediately processed by the vision recognition algorithm,
    returning an array of text spotted in the photo.
 */
struct img_capture: UIViewControllerRepresentable
{
    @Binding var image: UIImage?
    @Binding var label_arr: [String]
    let patterns = [
        "^\\d{9}$",
        "^\\d{2}[A-Za-z]\\d{3}[A-Za-z]\\d{2}$",
        "^(?i)SHP[A-Za-z]{2}\\d{2}$",
        "^(?i)SHP[A-Za-z]{2}$"
    ]
    let delimiters = "|:/"
    

    func makeUIViewController(context: Context) -> UIImagePickerController
    {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context)
    {
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
                self.recog_text(in: pickedImage, patterns: self.parent.patterns, delimiters: self.parent.delimiters)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController)
        {
            picker.dismiss(animated: true)
        }

        func recog_text(in image: UIImage, patterns: [String], delimiters: String)
        {
            let textRecognitionRequest = VNRecognizeTextRequest
            { [self] request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

                for index in 0..<observations.count {
                    if let topCandidate = observations[index].topCandidates(1).first {
                        let recognizedText = topCandidate.string
                        var processed_input = process_string(mStr: recognizedText)
                        if processed_input.range(of: "^\\d{2}[A-ZZa-z]$", options: .regularExpression, range: nil, locale: nil) != nil {
                            if let unwrap_input = observations[index+1].topCandidates(1).first?.string {
                                if ((index + 1) < observations.count) {
                                    processed_input += unwrap_input
                                }
                                else if ((index + 1) == observations.count) {
                                    processed_input += unwrap_input
                                    break
                                }
                            }
                        }
                        
                        let text_split_arr = processed_input.components(separatedBy: CharacterSet(charactersIn: delimiters))
                        for text_result in text_split_arr {
                            if (self.parent.label_arr.contains(text_result)) { break }
                            print(text_result)
                            for pattern in patterns {
                                if text_result.range(of: pattern, options: .regularExpression, range: nil, locale: nil) != nil {
                                    self.parent.label_arr.append(text_result)
                                    break
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
