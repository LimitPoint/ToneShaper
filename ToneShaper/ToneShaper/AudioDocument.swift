//
//  AudioDocument.swift
//  TonePlayer
//
//  Created by Joseph Pagliaro on 2/22/23.
//

import SwiftUI
import AVFoundation

/*
 AudioDocument is used by fileExporter to save audio to a location user can choose.
 */
class AudioDocument : FileDocument {
    
    var filename:String?
    var url:URL?
    
    static var readableContentTypes: [UTType] { [UTType.audio, UTType.mpeg4Audio, UTType.wav] }
    
    init(url:URL, preferredFilename: String?) {
        
        self.url = url
        
        /*
         
         WORKAROUND
         
         For issue: Feedback Assistent report FB13431681. defaultFilename of fileExporter is not working in iOS, works in Mac
         
         .fileExporter(isPresented: $viewModel.showAudioExporter, document: viewModel.audioDocument, contentType: UTType.wav, defaultFilename: “X”) { result in …
         
         Then export and in iOS the file dialog does NOT have “X” in the filename text field, but rather the filename of the url of the viewModel.audioDocument. 
         
         On iOS the defaultFilename (ie the name that appears in the save dialog) is taken from the URL used in the FileWrapper of AudioDocument rather than the deafultFilename argument to fileExporter. This copies the audio file to export to a URL with the desired filename.
         */
        if let preferredFilename = preferredFilename, let newURL = FileManager.copyAndRenameFile(at: url, toFilename: preferredFilename) {
            self.url = newURL
        }
        
        filename = self.url?.deletingPathExtension().lastPathComponent
    }
    
    required init(configuration: ReadConfiguration) throws {
        
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url = self.url
        else {
            throw CocoaError(.fileWriteUnknown)
        }
        let fileWrapper = try FileWrapper(url: url)
        return fileWrapper
    }
}
