import CoreImage
import UIKit

/*
    UTILITY FUNCTIONS
 */

func get_res() -> CGSize
{
    let mainScreen = UIScreen.main
    let scale = mainScreen.scale
    let bounds = mainScreen.bounds
    let width = bounds.width * scale
    let height = bounds.height * scale
    
    return CGSize(width: width, height: height)
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


func input_alert(completion: @escaping (String?) -> Void) {
    let alert = UIAlertController(title: "Generate barcode", message: "", preferredStyle: .alert)
    
    alert.addTextField { textField in
        textField.placeholder = "Enter barcode"
    }
    
    let addAction = UIAlertAction(title: "Generate", style: .default) { _ in
        if let textField = alert.textFields?.first, let enteredText = textField.text {
            // Call the completion closure with the entered text
            completion(enteredText)
        } else {
            // Call the completion closure with nil if no text is entered
            completion(nil)
        }
    }
    
    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
        // Call the completion closure with nil if the user cancels
        completion(nil)
    }
    
    alert.addAction(addAction)
    alert.addAction(cancelAction)
    
    showAlert(alert: alert)
}


func showAlert(alert: UIAlertController) {
    if let controller = topMostViewController() {
        controller.present(alert, animated: true)
    }
}

private func keyWindow() -> UIWindow? {
    return UIApplication.shared.connectedScenes
    .filter {$0.activationState == .foregroundActive}
    .compactMap {$0 as? UIWindowScene}
    .first?.windows.filter {$0.isKeyWindow}.first
}

private func topMostViewController() -> UIViewController? {
    guard let rootController = keyWindow()?.rootViewController else {
        return nil
    }
    return topMostViewController(for: rootController)
}

private func topMostViewController(for controller: UIViewController) -> UIViewController {
    if let presentedController = controller.presentedViewController {
        return topMostViewController(for: presentedController)
    } else if let navigationController = controller as? UINavigationController {
        guard let topController = navigationController.topViewController else {
            return navigationController
        }
        return topMostViewController(for: topController)
    } else if let tabController = controller as? UITabBarController {
        guard let topController = tabController.selectedViewController else {
            return tabController
        }
        return topMostViewController(for: topController)
    }
    return controller
}
