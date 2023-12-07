//
//  GraphicalArray.swift
//  GraphicalArrayEditor
//
//  Created by Joseph Pagliaro on 8/26/23.
//

import SwiftUI

struct CustomButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(BorderlessButtonStyle())
            .font(.system(size: 32, weight: .light))
            .frame(width: 44, height: 44)
    }
}

extension View {
    func customButtonStyle() -> some View {
        self.modifier(CustomButtonModifier())
    }
}

struct CustomBorderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .border(Color.gray, width: 1)
    }
}

extension View {
    func customBorderStyle() -> some View {
        self.modifier(CustomBorderModifier())
    }
}


struct GraphicalArrayView: View {
    @ObservedObject var viewModel:GraphicalArrayModel
    @State private var selectedTab = 0
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        VStack {
            
            TabView(selection: $selectedTab) {
                
                GraphicalArrayPlotView(viewModel: viewModel)
                    .padding(EdgeInsets(top: 35, leading: 30, bottom: 30, trailing: 30))
                    .tabItem {
                        Image(systemName: "chart.xyaxis.line")
                        Text("Plot")
                    }
                    .tag(0)
                
                GraphicalArrayDrawView(viewModel: viewModel, onApply: { points, viewSize in
                    
                    let updated = viewModel.updatePointsFromDrawPoints(drawPoints: points, drawViewSize: viewSize, undoManager: undoManager)
                    
                    DispatchQueue.main.async {
                        selectedTab = 0
                        if updated {
                            viewModel.graphicalArrayDelegate?.graphicalArrayAppliedDrawPoints()
                        }
                        else {
                            DispatchQueue.main.async {
                                viewModel.alertInfo = GAAlertInfo(id: .canNotApply, title: "Apply Draw Points", message: "The points could not be applied.", action: {
                                })
                            }
                        }
                    }
                })
                .padding(EdgeInsets(top: 35, leading: 30, bottom: 30, trailing: 30))
                .tabItem {
                    Image(systemName: "pencil.line")
                    Text("Draw")
                }
                .tag(1)
            }
            .frame(minHeight:300)
            .customBorderStyle()
            
            if viewModel.isShowingOctaveView {
                OctaveView(viewModel: viewModel)
            }
            else {
                GraphicalArrayControlView(viewModel: viewModel)
            }
             
        }
        .alert(item: $viewModel.alertInfo, content: { alertInfo in
            switch alertInfo.id {
                case .delete, .reset, .stepped, .apply, .erase, .applySample:
                    return Alert(title: Text(alertInfo.title), message: Text(alertInfo.message), primaryButton: .destructive(Text("Yes")) {
                        alertInfo.action()
                    }, secondaryButton: .cancel() {
                        
                    })
                
                case .canNotApply, .exporterSuccess, .exporterFailed, .imageSavedToPhotos, .imageNotSavedToPhotos:
                    return Alert(title:Text(alertInfo.title), message: Text(alertInfo.message), dismissButton: .default(Text("OK"))) 
            }
        })
        .overlay(Group {
            if viewModel.isExporting {          
                ProgressView("Exporting...")
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(livelyLavenderColor))
            }
        })
        .overlay(Group {
            if viewModel.isPreparingToPlay {          
                ProgressView("Preparing to play...")
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(livelyLavenderColor))
            }
        })
    }
}

struct GraphicalArray_Previews: PreviewProvider {
    static var previews: some View {
        GraphicalArrayView(viewModel: GraphicalArrayModel(data: kDefaultModelData))
            .padding(25)
    }
}

struct ProgressView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ProgressView("Exporting...")
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(livelyLavenderColor))
            
            ProgressView("Preparing to play...")
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(livelyLavenderColor))
        }
        
    }
}
