//
//  GraphicalArrayModelData.swift
//  ToneShaper
//
//  Created by Joseph Pagliaro on 9/16/23.
//

import Foundation

func lowestFrequency() -> Double {
    return 20.0
}

func highestFrequency() -> Double {
    return Double(44100) / 2.0
}

struct GraphicalArrayModelData: Codable {
    var points:[CGPoint] 
    var duration:CGFloat
    var minFrequency:CGFloat
    var maxFrequency:CGFloat
    
    var echoOffsetTimeSeconds:Double?
    var echoVolume:Double?
    var scaleType:String?
    var componentType:String?
    var fidelity:Int?
}

let kDefaultModelData = GraphicalArrayModelData(points: [CGPoint(x: 0, y: lowestFrequency()), CGPoint(x: 3.0, y: highestFrequency())], duration: 3, minFrequency: lowestFrequency() , maxFrequency: highestFrequency())

func GraphicalArrayModelDataForURL(fileURL: URL) -> GraphicalArrayModelData? {
    
    var graphicalArrayModelData:GraphicalArrayModelData?
    
    do {
        let data = try Data(contentsOf: fileURL)
        graphicalArrayModelData = try JSONDecoder().decode(GraphicalArrayModelData.self, from: data)
       
    } catch {
        print("Error: \(error)")
    }
    
    return graphicalArrayModelData
}
