//
//  ThumbnailProvider.swift
//  ThumbnailExtensionMac
//
//  Created by Joseph Pagliaro on 9/16/23.
//

import QuickLookThumbnailing
/*
 Don't forget:
 In Build Phases, add target dependencies and set the macOS and iOS filters for the thumbnail extensions for each platform 
 */

class ThumbnailProvider: QLThumbnailProvider {
    
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        
        let scale: CGFloat = request.scale
        
            // This ensures the document icon aspect ratio matches what is usual (rather than square), namely standard paper size of 8x10
            // can't use scale here
        let aspectRatio:CGFloat = 8.0 / 10.0
        let thumbnailFrame = CGRect(x: 0, y: 0, width: aspectRatio * request.maximumSize.height, height: request.maximumSize.height)
        
        handler(QLThumbnailReply(contextSize: thumbnailFrame.size, drawing: { (context) -> Bool in
            
            guard FileManager.default.isReadableFile(atPath: request.fileURL.path) else {
                return false
            }
            
            guard let data: Data = try? Data.init(contentsOf: request.fileURL, options: [.uncached]) else {
                return false
            }
            
            guard let graphicalArrayModelData = try? JSONDecoder().decode(GraphicalArrayModelData.self, from: data) else {
                return false
            }
            
            let viewSize = CGSize(width: thumbnailFrame.size.width * scale, height: thumbnailFrame.size.height * scale)
            
            
            DrawGraphicalArrayModelDataInCGContext(context: context, data: graphicalArrayModelData, size: viewSize, scale: 1, inset:10, labelType: .none)
            
            return true
        }), nil)
    }
}
