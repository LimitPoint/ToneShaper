//
//  UnitFunctions.swift
//  ToneShaper
//
//  Created by Joseph Pagliaro on 10/25/23.
//

import Foundation
import SwiftUI
/*
 Functions defined on unit interval [0,1].
 */

    // unitmap and mapunit are inverses
    // map [x0,y0] to [0,1]
func unitmap(_ x0:Double, _ x1:Double, _ x:Double) -> Double {
    return (x - x0)/(x1 - x0)
}

func unitmap(_ r:ClosedRange<Double>, _ x:Double) -> Double {
    return unitmap(r.lowerBound, r.upperBound, x)
}

    // map [0,1] to [x0,x1] 
func mapunit(_ r:ClosedRange<Double>, _ x:Double) -> Double {
    return mapunit(r.lowerBound, r.upperBound, x)
}

func mapunit(_ x0:Double, _ x1:Double, _ x:Double) -> Double {
    return (x1 - x0) * x + x0
}

    // flips function on [0,1]
func unitflip(_ x:Double) -> Double {
    return 1 - x
}

    // MARK: Unit Functions

func constant(_ k:Double) -> Double {
    return k
}

func smoothstep(_ x:Double) -> Double {
    return -2 * pow(x, 3) + 3 * pow(x, 2)
}

func smoothstep_on(_ r:ClosedRange<Double>, _ x:Double) -> Double {
    return smoothstep(unitmap(r, x)) 
}

func smoothstep_flip_on(_ r:ClosedRange<Double>, _ x:Double) -> Double {
    return smoothstep(unitflip(unitmap(r, x)))
}

func double_smoothstep(_ t:Double, from:Double = 1, to:Double = 2, range:ClosedRange<Double> = 0.2...0.4) -> Double {
    
    guard from >= 0, to > 0, range.lowerBound >= 0, range.upperBound <= 0.5 else {
        return 0
    }
    
    var value:Double = 0
    
    let r1 = 0...range.lowerBound
    let r2 = range
    let r3 = range.upperBound...1.0-range.upperBound
    let r4 = 1.0-range.upperBound...1.0-range.lowerBound
    let r5 = 1.0-range.lowerBound...1.0
    
    if r1.contains(t) {
        value = constant(from)
    }
    else if r2.contains(t) {
        value = mapunit(from, to, smoothstep_on(r2, t))
    }
    else if r3.contains(t) {
        value = constant(to)
    }
    else if r4.contains(t) {
        value = mapunit(from, to, smoothstep_flip_on(r4, t))
    }
    else if r5.contains(t) {
        value = constant(from)
    }
    
    return value
}

func GeneratePath(a:Double, b:Double, period:Double?, phaseOffset:Double, N:Int, frameSize:CGSize, inset:Double = 10.0, graph: (_ x:Double) -> Double) -> Path {
    
    guard frameSize.width > 0, frameSize.height > 0  else {
        return Path()
    }
    
    var plot_x:[Double] = []
    var plot_y:[Double] = []
    
    var minimum_y:Double = 0
    var maximum_y:Double = 0
    
    var minimum_x:Double = 0
    var maximum_x:Double = 0
    
    for i in 0...N {
        
        let x = a + (Double(i) * ((b - a) / Double(N)))
        
        var y:Double
        if let period = period {
            y = graph((x + phaseOffset).truncatingRemainder(dividingBy: period))
        }
        else {
            y = graph(x + phaseOffset)
        }
        
        if y < minimum_y {
            minimum_y = y
        }
        if y > maximum_y {
            maximum_y = y
        }
        
        if x < minimum_x {
            minimum_x = x
        }
        if x > maximum_x {
            maximum_x = x
        }
        
        plot_x.append(x)
        plot_y.append(y)
    }
    
    let frameRect = CGRect(x: 0, y: 0, width: frameSize.width, height: frameSize.height)
    let plotRect = frameRect.insetBy(dx: inset, dy: inset)
    
    let x0 = plotRect.origin.x
    let y0 = plotRect.origin.y
    let W = plotRect.width
    let H = plotRect.height
    
    func tx(_ x:Double) -> Double {
        if maximum_x == minimum_x {
            return x0 + W
        }
        return (x0 + W * ((x - minimum_x) / (maximum_x - minimum_x)))
    }
    
    func ty(_ y:Double) -> Double {
        if maximum_y == minimum_y {
            return frameSize.height - (y0 + H)
        }
        return frameSize.height - (y0 + H * ((y - minimum_y) / (maximum_y - minimum_y)))
    }
    
    plot_x = plot_x.map( { x in
        tx(x)
    })
    
    plot_y = plot_y.map( { y in
        ty(y)
    })
    
    let path = Path { path in
        path.move(to: CGPoint(x: plot_x[0], y: plot_y[0]))
        
        for i in 1...N {
            let x = plot_x[i]
            let y = plot_y[i]
            path.addLine(to: CGPoint(x: x, y: y))
        }
    }
    
    return path
}
