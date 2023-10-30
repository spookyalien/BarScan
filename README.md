
BarScan IOS app
==================================================

Usage
-----
Used in order to make defective label scanning easier. Use of this app is employed at Target and is intended to scan backroom locations and DPCIs.

Functionality
-------------
BarScan uses machine learning vision to recognize the text on the photo taken and uses CoreImage to generate a barcode to be displayed. Once strings have been found they are delimited, and then ran through regex to ensure that the results shown in the app list are valid for making a barcode. Some examples of valid barcodes are the following: 123-45-6789, 123456789, SHPab12, shpab, 01B020B23. Using this app increases workflow and prevents an external requirement to generate barcodes.

TODO
----
- Custom regex for user
- Improve GUI for user friendliness


