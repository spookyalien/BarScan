#BarScan
IOS app that takes the input of a picture retrieved by the camera and converts text to barcodes.

##Usage
Used in order to make defective label scanning easier. Use of this app is employed at Target and is intended to scan backroom locations and DPCIs

##Functionality
BarScan uses machine learning vision to recognize the text on the photo taken and uses CoreImage to generate a barcode to be displayed. Additionally, strings are processed to be best compatible for making the chosen barcode.

##TODO 
-Improve recognized text from picture 
-Improve GUI for user friendliness 
-Handle invalid barcodes
