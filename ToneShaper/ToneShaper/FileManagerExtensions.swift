//
//  FileManagerExtensions.swift
//  TonePlayer
//
//  Created by Joseph Pagliaro on 2/12/23.
//

import Foundation

extension FileManager {
    
    class func copyAndRenameFile(at url: URL, toFilename filename: String) -> URL? {
        let newURL = url.deletingLastPathComponent().appendingPathComponent(filename).appendingPathExtension(url.pathExtension)
        
        do {
            if FileManager.default.fileExists(atPath: newURL.path) {
                try FileManager.default.removeItem(at: newURL)
            }
            
            try FileManager.default.copyItem(at: url, to: newURL)
            
            return newURL
        } catch {
            print("Error: \(error.localizedDescription)")
            return nil
        }
    }
    
    class func pathsForFilesInResourceFolderSortedByName(resourceFolderName: String, fileExtension: String) -> [URL] {
        
        var fileURLs:[URL] = []
        
        if let folderURL = Bundle.main.url(forResource: resourceFolderName, withExtension: nil) {
            do {
                let fileManager = FileManager.default
                let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                
                    // Filter the contents to only include files with the 'toneshaper' extension.
                let folderFiles = contents.filter { $0.pathExtension == fileExtension }
                
                    // Sort the 'toneshaper' files by name with custom sorting logic.
                let sortedFolderFiles = folderFiles.sorted {
                    let name1 = $0.lastPathComponent
                    let name2 = $1.lastPathComponent
                    
                        // Use the localizedStandardCompare method to compare file names.
                    return name1.localizedStandardCompare(name2) == .orderedAscending
                }
                
                fileURLs.append(contentsOf: sortedFolderFiles)

            } catch {
                    // Handle any errors that may occur while accessing the 'Samples' folder.
                print("Error: \(error)")
            }
        }
        
        return fileURLs
    }
    
    class func urlForDocumentsOrSubdirectory(subdirectoryName:String?) -> URL? {
        var documentsURL: URL?
        
        do {
            documentsURL = try FileManager.default.url(for:.documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        }
        catch {
            print("\(error)")
            return nil
        }
        
        guard let subdirectoryName = subdirectoryName else {
            return documentsURL
        }
        
        if let directoryURL = documentsURL?.appendingPathComponent(subdirectoryName) {
            if FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: nil) == false {
                do {
                    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes:nil)
                }
                catch let error as NSError {
                    print("error = \(error.description)")
                    return nil
                }
            }
            
            return directoryURL
        }
        
        return nil
    }
    
    class func documentsURL(filename:String?, subdirectoryName:String?) -> URL? {
        
        guard let documentsDirectoryURL = FileManager.urlForDocumentsOrSubdirectory(subdirectoryName: subdirectoryName) else {
            return nil
        }
        
        var destinationURL = documentsDirectoryURL
        
        if let filename = filename {
            destinationURL = documentsDirectoryURL.appendingPathComponent(filename)
        }
        
        return destinationURL
    }
    
    class func deleteDocumentsSubdirectory(subdirectoryName:String) {
        if let subdirectoryURL  = FileManager.documentsURL(filename: nil, subdirectoryName: subdirectoryName) {
            do {
                try FileManager.default.removeItem(at: subdirectoryURL)
                print("FileManager deleted directory at \(subdirectoryURL)")
            }
            catch {
                print("FileManager had an error removing directory at \(subdirectoryURL): \(error)")
            }
        }
    }
}
