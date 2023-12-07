//
//  DrawGraphicalArrayPlot.swift
//  TonePlayer
//
//  Created by Joseph Pagliaro on 9/16/23.
//

import Foundation
import SwiftUI
import CoreServices
import UniformTypeIdentifiers
import Photos

enum GAELabelType: String, CaseIterable, Identifiable {
    case none = "None", frequency = "Frequency", frequencyAndNote = "Frequency and Note"
    var id: Self { self }
}

func TestDrawGraphicalArrayModelData(size: CGSize, scale: CGFloat) {
    let duration = 3.5
    let data = MakeGraphicalArrayModelData(points: [(0,200.0), (0.25 * duration, 15000.0), (0.35 * duration, 750.0), (0.5 * duration, 2768.0), (0.75 * duration, 8000.0), (0.85 * duration, 1156.0), (duration, 1678.2)], duration: duration, minFrequency: kDefaultModelData.minFrequency, maxFrequency: kDefaultModelData.maxFrequency)
    
    SaveGraphicalArrayModelDataToPhotos(size: size, scale: scale, data: data, inset: 10, labelType: .frequencyAndNote) { success in
        if success {

            print("Saved!")
        }
        else {
            print("Not Saved!")
        }
    }
}

func TuplesToCGPoint(_ tuples: [(Double, Double)]) -> [CGPoint] {
    var points: [CGPoint] = []
    
    for tuple in tuples {
        let x = CGFloat(tuple.0)
        let y = CGFloat(tuple.1)
        let point = CGPoint(x: x, y: y)
        points.append(point)
    }
    
    return points
}

func MakeGraphicalArrayModelData(points: [(Double, Double)], duration: CGFloat, minFrequency: CGFloat, maxFrequency: CGFloat) -> GraphicalArrayModelData {
    
    let cgPoints = TuplesToCGPoint(points)
    
    return GraphicalArrayModelData(points: cgPoints, duration: duration, minFrequency: minFrequency, maxFrequency: maxFrequency)
}

func SaveGraphicalArrayModelDataToPhotos(size: CGSize, scale: CGFloat, data: GraphicalArrayModelData, inset: CGFloat, labelType: GAELabelType, completion: @escaping (Bool) -> ()) {
    
    let width = Int(size.width * scale) 
    let height = Int(size.height * scale) 
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    
    if let context = CGContext(data: nil,
                               width: width,
                               height: height,
                               bitsPerComponent: 8,
                               bytesPerRow: 0,
                               space: colorSpace,
                               bitmapInfo: bitmapInfo.rawValue) {
        
        DrawGraphicalArrayModelDataInCGContext(context: context, data: data, size: CGSize(width: width, height: height), scale: scale, inset: inset, labelType: labelType)
        
        if let imageURL = SaveCGContextToDocuments(context: context, filename: "ImageGraphicalArrayModelData") {
            SaveImageURLToPhotos(url: imageURL, completion: completion)
        }
    }
}

#if os(macOS)
func drawText(_ context: CGContext, myString: String, position: CGPoint, fontSize: CGFloat, color: NSColor = NSColor.black) {
    
    let savedContext = NSGraphicsContext.current
    
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    
    context.setAllowsAntialiasing(true)
    context.setShouldSmoothFonts(true)
    
    let font = NSFont.systemFont(ofSize: fontSize)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraphStyle
    ]
    
    let myAttrString = NSAttributedString(string: myString, attributes: attributes)
    
    let boundingBox = myAttrString.boundingRect(with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil)
    
        // Calculate the vertical position to center the text
    let yOffset = position.y - boundingBox.height / 2
        // Calculate the horizontal position to center the text
    let xOffset = position.x - boundingBox.width / 2
    
    let textRect = CGRect(x: xOffset, y: yOffset, width: boundingBox.width, height: boundingBox.height)
    
    myAttrString.draw(in: textRect)
    
    NSGraphicsContext.current = savedContext
}
#else
func drawText(_ context: CGContext, myString: String, position: CGPoint, fontSize: CGFloat, color: UIColor = UIColor.black) {
    UIGraphicsPushContext(context)
    
    context.setAllowsAntialiasing(true)
    context.setShouldSmoothFonts(true)
    
    let font = UIFont.systemFont(ofSize: fontSize)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraphStyle
    ]
    
    let myAttrString = NSAttributedString(string: myString, attributes: attributes)
    
    let boundingBox = myAttrString.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil)
    
        // Calculate the vertical position to center the text
    let yOffset = position.y - boundingBox.height / 2
        // Calculate the horizontal position to center the text
    let xOffset = position.x - boundingBox.width / 2
    
    let textRect = CGRect(x: xOffset, y: yOffset, width: boundingBox.width, height: boundingBox.height)
    
    myAttrString.draw(in: textRect)
    
    UIGraphicsPopContext()
}

#endif

func DrawGraphicalArrayModelDataInCGContext(context: CGContext, data: GraphicalArrayModelData, size: CGSize, scale: CGFloat, inset: CGFloat, labelType: GAELabelType) {
    let points: [CGPoint] = data.points
    let minFrequency: CGFloat = data.minFrequency
    let maxFrequency: CGFloat = data.maxFrequency
    let duration: CGFloat = data.duration
    
    let scaledInset = scale * inset
    
        // Calculate the inset size
    let insetSize = CGSize(width: size.width - 2 * scaledInset, height: size.height - 2 * scaledInset)
    
    func LAV(_ pointInA: CGPoint, A: [CGPoint], V: [CGPoint]) -> CGPoint {
        let xFraction = (pointInA.x - A[0].x) / (A[1].x - A[0].x)
        let yFraction = (pointInA.y - A[0].y) / (A[1].y - A[0].y)
        
        let pointInV_X = xFraction * (V[1].x - V[0].x) + V[0].x
        let pointInV_Y = yFraction * (V[1].y - V[0].y) + V[0].y
        
        let pointInV = CGPoint(x: pointInV_X, y: pointInV_Y)
        
        return pointInV
    }
    
    func LAV(_ pointInA: CGPoint) -> CGPoint {
        return LAV(pointInA, A: [CGPoint(x: 0, y: minFrequency), CGPoint(x: duration, y: maxFrequency)], V: [CGPoint(x: 0, y: 0), CGPoint(x: insetSize.width, y: insetSize.height)])
    }
    
    context.setAllowsAntialiasing(true)
    
        // Start drawing
#if os(macOS)
    context.setStrokeColor(NSColor.blue.cgColor)
#else
    context.setStrokeColor(UIColor.blue.cgColor)
#endif
    context.setLineWidth(2 * scale)
    
        // Draw the border around the inset area
    let borderRect = CGRect(x: scaledInset, y: scaledInset, width: insetSize.width, height: insetSize.height)
    context.stroke(borderRect)
    
#if os(macOS)
    context.setStrokeColor(NSColor.black.cgColor)
#else
    context.setStrokeColor(UIColor.black.cgColor)
#endif
    
        // Draw lines connecting the points
    if !points.isEmpty {
        var startPoint = LAV(points[0])
        startPoint = CGPoint(x: startPoint.x + scaledInset, y: startPoint.y + scaledInset)
        context.move(to: startPoint)
        
        for index in 1..<points.count {
            var point = LAV(points[index])
            point = CGPoint(x: point.x + scaledInset, y: point.y + scaledInset)
            context.addLine(to: point)
        }
    }
    context.strokePath()
    
        // Draw circles for the points
    for index in points.indices {
        let point = LAV(points[index])
        let pointDiameter: CGFloat = 10.0 * scale
        
        
        if frequencyIsNote(frequency: points[index].y) {
#if os(macOS)
            context.setFillColor(NSColor.green.cgColor)
#else
            context.setFillColor(UIColor.green.cgColor)
#endif
            let outerPointDiameter = pointDiameter + pointDiameter/8
            
            context.fillEllipse(in: CGRect(x: point.x + scaledInset - outerPointDiameter/2, y: point.y + scaledInset - outerPointDiameter/2, width: outerPointDiameter, height: outerPointDiameter))
        }
        
        
#if os(macOS)
        context.setFillColor(NSColor.black.cgColor)
#else
        context.setFillColor(UIColor.black.cgColor)
#endif
        
        var innerPointDiameter = pointDiameter
        if frequencyIsNote(frequency: points[index].y) {
            innerPointDiameter = innerPointDiameter - innerPointDiameter/8
        }
        
        context.fillEllipse(in: CGRect(x: point.x + scaledInset - innerPointDiameter/2, y: point.y + scaledInset - innerPointDiameter/2, width: innerPointDiameter, height: innerPointDiameter))
        
    }
    
    // draw text labels, drawText is implemented different for iOs and macOS
    if labelType != .none {
#if os(iOS) 
            // flip context 
        context.translateBy(x: 0, y: Double(size.height));
        context.scaleBy(x: 1, y: -1)
#endif
        
        for index in points.indices {
            var point = LAV(points[index])
            
#if os(iOS) 
            point = CGPoint(x: point.x + scaledInset, y: insetSize.height - point.y + scaledInset)
#else
            point = CGPoint(x: point.x + scaledInset, y: point.y + scaledInset)
#endif
            let noteString = pianoNoteForFrequency(Double(points[index].y))
            let frequencyString = String(format: "%.2f", points[index].y)
            let timeString = String(format: "%.2f", points[index].x)
 
#if os(iOS)
            if labelType == .frequencyAndNote {
                if frequencyIsNote(frequency: points[index].y) {
                    drawText(context, myString: noteString, position: CGPoint(x: point.x, y: point.y - 2 * 12 * scale), fontSize: 12 * scale)
                } 
            }
            
            drawText(context, myString: frequencyString, position: CGPoint(x: point.x, y: point.y - 12 * scale), fontSize: 12 * scale)
            drawText(context, myString: timeString, position: CGPoint(x: point.x, y: point.y + 12 * scale), fontSize: 12 * scale)
#else
            if labelType == .frequencyAndNote {
                if frequencyIsNote(frequency: points[index].y) {
                    drawText(context, myString: noteString, position: CGPoint(x: point.x, y: point.y + 2 * 12 * scale), fontSize: 12 * scale) 
                }
            }
            
            drawText(context, myString: frequencyString, position: CGPoint(x: point.x, y: point.y + 12 * scale), fontSize: 12 * scale)
            drawText(context, myString: timeString, position: CGPoint(x: point.x, y: point.y - 12 * scale), fontSize: 12 * scale)           
#endif
        }
    }

}

func SaveCGContextToDocuments(context:CGContext, filename:String) -> URL? {
    
    var imageURL:URL?
    
    if let cgImage = context.makeImage() {
        let mutableData = NSMutableData()
        if let imageDestination = CGImageDestinationCreateWithData(mutableData , "public.jpeg" as CFString, 1, nil) {
            CGImageDestinationAddImage(imageDestination, cgImage, nil)
            if CGImageDestinationFinalize(imageDestination) {
                let data = mutableData as Data
                do {
                    
                    let fm = FileManager.default
                    let documentsURL = try! fm.url(for:.documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                    let destinationURL = documentsURL.appendingPathComponent("\(filename).jpg")
                    
                    try data.write(to: destinationURL)
                    
                    imageURL = destinationURL
                }
                catch {
                    print("\(error)")
                }
            } else {
            }
        }
    }
    
    return imageURL
}

func SaveImageURLToPhotos(url: URL, completion: @escaping (Bool) -> ()) {
    
    PHPhotoLibrary.requestAuthorization { status in
        if status == .authorized {
            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                creationRequest?.creationDate = Date()
            } completionHandler: { success, error in
                if success {
                    print("Image saved to Photos app successfully.")
                } else {
                    if let error = error {
                        print("Error saving image to Photos app: \(error.localizedDescription)")
                    } else {
                        print("Unknown error occurred while saving image to Photos app.")
                    }
                }
                
                completion(success)
            }
        }
        else {
            completion(false)
        }
    }
}

func GraphicalArrayModelDataCGImageForURL(fileURL: URL, size: CGSize, scale: CGFloat, inset: CGFloat, labelType: GAELabelType) -> CGImage? {
    
    var cgImage:CGImage?
    
    if let graphicalArrayModelData = GraphicalArrayModelDataForURL(fileURL: fileURL) {
        
        let width = Int(size.width * scale)
        let height = Int(size.height * scale)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        if let context = CGContext(data: nil,
                                   width: width,
                                   height: height,
                                   bitsPerComponent: 8,
                                   bytesPerRow: 0,
                                   space: colorSpace,
                                   bitmapInfo: bitmapInfo.rawValue) {
            
            DrawGraphicalArrayModelDataInCGContext(context: context, data: graphicalArrayModelData, size: size, scale: scale, inset: inset, labelType: labelType)
            
            cgImage = context.makeImage()
            
        }
    }
    
    return cgImage
}
