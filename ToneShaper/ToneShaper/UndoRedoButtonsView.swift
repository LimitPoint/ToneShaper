//
//  UndoRedoButtonsView.swift
//  ToneShaper
//
//  Created by Joseph Pagliaro on 10/13/23.
//

import SwiftUI

import SwiftUI

    // Using Maciek Czarnik idea at https://stackoverflow.com/questions/60647857/undomanagers-canundo-property-not-updating-in-swiftui
struct UndoRedoButtonsView: View {
    
    @ObservedObject var toneShaperDocument:ToneShaperDocument 
    @Environment(\.undoManager) var undoManager
    
    @State private var canUndo = false
    @State private var canRedo = false
    
    var body: some View {
        HStack {
            
            Button(action: {
                self.undoManager?.undo()
                
                if let undoManager = undoManager {
                    canUndo = undoManager.canUndo
                    canRedo = undoManager.canRedo
                }
            }) {
                Image(systemName: "arrow.uturn.backward.circle")
            }
            .disabled(canUndo == false)
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 10))
            
            Button(action: {
                self.undoManager?.redo()
                
                if let undoManager = undoManager {
                    canUndo = undoManager.canUndo
                    canRedo = undoManager.canRedo
                }
            }) {
                Image(systemName: "arrow.uturn.forward.circle")
            }
            .disabled(canRedo == false)
        }
        .onAppear {
            if let undoManager = undoManager {
                canUndo = undoManager.canUndo
                canRedo = undoManager.canRedo
            }
        }
        .onReceive(toneShaperDocument.objectWillChange) { _ in
            if let undoManager = undoManager {
                canUndo = undoManager.canUndo
                canRedo = undoManager.canRedo
            }
        }
    }
}

struct UndoRedoButtonsView_Previews: PreviewProvider {
    static var previews: some View {
        UndoRedoButtonsView(toneShaperDocument: ToneShaperDocument())
    }
}
