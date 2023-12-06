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
        // DPCI
        "^\\d{9}$",
        // Backroom location
        "^\\d{2}[A-Za-z]\\d{3}[A-Za-z]\\d{2}$",
        // Fulfillment cart
        "^(?i)SHP[A-Za-z]{2}\\d{2}$",
        // UPC
        "^\\d{12}$"
    ]
    let delimiters = "|:/#"
    

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

        
        /*
        -Reads text from image and corrects it to ensure best processing of barcode
         */
        func recog_text(in image: UIImage, patterns: [String], delimiters: String)
        {
            let textRecognitionRequest = VNRecognizeTextRequest
            { [self] request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

                for index in 0..<observations.count {
                    if let topCandidate = observations[index].topCandidates(1).first {
                        let recognizedText = topCandidate.string
                        //Processed_input = delimited string UIImage
                        var processed_input = process_string(mStr: recognizedText)
                        // Remove misread latin chars
                        processed_input = convert_cyrillic(text: processed_input)
                        // Account for B mistaken as 8 but ignore for SHPBA12
                        // count == 3 for first part of backroom location (e.g. "01B", "99B), and count == 6 for last part of backroom location (e.g. "020B01", "114F01")
                        // Backroom location is split in myDay
                        if (processed_input.count == 3 || processed_input.count == 6) {
                            let loc1 = processed_input.index(processed_input.startIndex, offsetBy: 2)
                            let loc2 = processed_input.index(processed_input.startIndex, offsetBy: 3)
                                
                            if processed_input[loc1] == "8" {
                                processed_input.replaceSubrange(loc1...loc1, with: "B")
                            }
                                
                            if (processed_input.count == 6 && processed_input[loc2] == "8") {
                                processed_input.replaceSubrange(loc2...loc2, with: "B")
                            }
                         }
                     
        
                        /*
                         Image reading special cases
                         */
                        
                        // First part of backroom location, appends to text to create location
                        if processed_input.range(of: "^\\d{2}[A-Za-z]$", options: .regularExpression, range: nil, locale: nil) != nil {
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
                        // Last part of backroom location, appends text to create location
                        else if processed_input.range(of: "^\\d{3}[A-Za-z]\\d{2}$", options: .regularExpression, range: nil, locale: nil) != nil {
                            if let unwrap_input = observations[index+1].topCandidates(1).first?.string {
                                if ((index + 1) < observations.count) {
                                    processed_input = unwrap_input + processed_input
                                }
                                else if ((index + 1) == observations.count) {
                                    processed_input = unwrap_input + processed_input
                                    break
                                }
                            }

                        }
                        // Checks for blank fulfillment cart (cart with no numbers at end) and appends basic entry "01" to cart name
                        else if processed_input.range(of: "^(?i)SHP[A-Za-z]{2}$", options: .regularExpression, range: nil, locale: nil) != nil {
                            processed_input += "01"
                        }
                        // Fixes issue of clock (e.g. 00:01:46) being interpreted in image scanning of fulfillment cart and replaces end 0 with 1 for compatibiity with ePick
                        else if processed_input.range(of: "^(?i)SHP[A-Za-z]0\\d{1}$", options: .regularExpression, range: nil, locale: nil) != nil {
                            processed_input.removeLast()
                            processed_input += "1"
                        }
                        // Accounts for issue of backroom letter O being mistaken as 0
                        else if processed_input.range(of: "^\\d{2}[A-Za-z]\\d{6}$", options: .regularExpression, range: nil, locale: nil) != nil {
                            // Set to where O is in backroom location barcode == 5
                            let back_loc = processed_input.index(processed_input.startIndex, offsetBy: 5)
                            
                            if (processed_input[back_loc] == "0") {
                                processed_input.replaceSubrange(back_loc...back_loc, with: "O")
                            }
                        }
                        // Accounts for issue of Backroom letter B being an 8 (processed_input is not split)
                        else if processed_input.range(of: "^\\d{6}[A-Za-z]\\d{2}$", options: .regularExpression, range: nil, locale: nil) != nil {
                            // Set to where B is in backroom location barcode == 2
                            let back_loc = processed_input.index(processed_input.startIndex, offsetBy: 2)
                            
                            if (processed_input[back_loc] == "8") {
                                processed_input.replaceSubrange(back_loc...back_loc, with: "B")
                            }
                        }
                        // Accounts for misread Os and 0s e.g. 01B02O009
                        else if processed_input.range(of: "\\d{2}[A-Za-z]\\d{2}[A-Za-z]{1}\\d{3}", options: .regularExpression, range: nil, locale: nil) != nil {
                            let loc_o = processed_input.index(processed_input.startIndex, offsetBy: 5)
                            let loc_zero = processed_input.index(processed_input.startIndex, offsetBy: 6)
                            
                            if (processed_input[loc_o] == "O") {
                                processed_input.replaceSubrange(loc_o...loc_o, with: "0")
                            }
                            if (processed_input[loc_zero] == "0") {
                                processed_input.replaceSubrange(loc_zero...loc_zero , with: "O")
                            }
                        }
                        
                        let text_split_arr = processed_input.components(separatedBy: CharacterSet(charactersIn: delimiters))
                        for text_result in text_split_arr {
                            if (self.parent.label_arr.contains(text_result)) { break }
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
