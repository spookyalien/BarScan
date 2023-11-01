import UIKit
import AVFoundation
import SwiftUI



/*
    Main life of app, contains button that opens camera when pressed, and fills up a selectable list with valid text
    taken from the photo, which each generate the respective barcode when touched.
 */
struct ContentView: View
{
    @State private var image: UIImage?
    @State private var barcode: UIImage?
    @State private var selected_index = 0
    @State private var selected_text: String = ""
    @State private var label_arr = [String]()
    @State private var cam_open = false
    @State private var img_visible = false
    @State private var scale_effect = 0.5
    @State private var resolution = get_res()
    @State private var label_size: CGFloat = 20
    @State private var button_size: CGFloat = 25
    

    var body: some View {
        NavigationView {
            VStack {
                Spacer().frame(height:20)
                HStack {
                    Image("Image") // Replace with your app logo image name
                                .resizable()
                                .frame(width: 60, height: 60) // Adjust the size as needed
                    Text("BarScan")
                                .font(.title)
                                .foregroundStyle(Color.black)

                    
                    Spacer()
                    Button(action: {
                        label_arr.removeAll()
                    }) {
                        Text("Clear")
                            .font(.headline)
                            .padding(10)
                            .background(Color.red)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                    }
                }
                .padding(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                .background(Color.gray)
                .foregroundColor(.white)
            
                List {
                    ForEach(label_arr.indices, id: \.self) { index in
                        Button(action: {
                            selected_text = label_arr[index]
                            barcode = gen_barcode(from: selected_text)
                            if selected_text.count > 10 {
                                scale_effect = 0.9
                            } else {
                                scale_effect = 0.5
                            }
                            img_visible = true
                        }) {
                            Text(label_arr[index])
                                .font(.system(size: label_size))
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.top, (resolution.height)/30)
                
                if img_visible {
                    if let barcode =  barcode{
                        Image(uiImage: barcode)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale_effect)
                    }
                
                }
                
                Button(action: { check_permission() }) {
                    Text("Scan Barcode")
                        .font(.system(size: button_size))
                        .padding(.bottom, resolution.height/120)
                        .frame(maxWidth: .infinity)
                        .frame(height: 90)
                        .background(Color.red)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
                .sheet(isPresented: $cam_open) {
                    img_capture(image: $image, label_arr: $label_arr)
                }
            }
        }
        .navigationBarTitle("")
        .navigationBarHidden(true)
    }

    func check_permission()
    {
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
