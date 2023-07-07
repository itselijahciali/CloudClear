import Combine
import Photos
import AVFoundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

class PhotoViewModel: ObservableObject {
    @Published var sortedAssets: [PHAsset] = []
    @Published var sortProgress: Float = 0
    @Published var sortingComplete: Bool = false
    @Published var assetsToDelete: [PHAsset] = []
    @Published var assetsToSave: [PHAsset] = []
    @Published var saveProgress: Float = 0.0
    
    var totalFileSize: Int64 {
        calculateTotalFileSize()
    }
    
    private func calculateTotalFileSize() -> Int64 {
        var totalFileSize: Int64 = 0
        
        for asset in assetsToDelete {
            let resources = PHAssetResource.assetResources(for: asset)
            for resource in resources {
                if let fileSize = resource.value(forKey: "fileSize") as? Int64 {
                    totalFileSize += fileSize
                }
            }
        }
        
        return totalFileSize
    }
    
    func getAllPhotosSortedByFileSize(completion: @escaping () -> Void) {
        sortProgress = 0.0
        
        // Set fetch options to include everything
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeAllBurstAssets = true
        fetchOptions.includeHiddenAssets = true
        
        // When debugging it's helpful to uncomment this line and comment the next so you don't have to sort an entire library each time
        
        //let collections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumLivePhotos, options: nil)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        
        var assetsWithSize: [(asset: PHAsset, fileSize: Int64)] = []
        var uniqueAssets: Set<PHAsset> = [] // Weird iOS bug returns 2 of each asset, so we need to detedct duplicates
        
        var totalAssetsCount = 0
        
        // Find total assets, so we can check progress
        collections.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
            totalAssetsCount += assets.count
        }
        
        let sortingQueue = DispatchQueue(label: "sortingQueue", qos: .userInitiated)
        
        sortingQueue.async {
            
            collections.enumerateObjects { collection, _, _ in
                let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
                assets.enumerateObjects { asset, _, _ in
                    guard let resource = PHAssetResource.assetResources(for: asset).first else { return }
                    
                    if uniqueAssets.contains(asset) {
                        return // Skip if the asset is already added
                    }
                    
                    uniqueAssets.insert(asset)
                    
                    let fileSize = resource.value(forKey: "fileSize") as? Int64 ?? 0
                    assetsWithSize.append((asset: asset, fileSize: fileSize))
                    
                    DispatchQueue.main.async {
                        self.sortProgress += 1.0 / Float(totalAssetsCount)
                    }
                }
            }
            
            let sortedAssets = assetsWithSize.sorted(by: { $0.fileSize > $1.fileSize })
            let sortedAssetsOnly = sortedAssets.map { $0.asset }
            
            DispatchQueue.main.async {
                let topAssets = Array(sortedAssetsOnly.prefix(100))
                self.sortedAssets = topAssets
                self.sortingComplete = true
            }
            
            completion() // No error handling because I haven't cleaned up the code yet
            
        }
        
        
    }
    
    func saveAssets(completion: @escaping (URL?, Error?) -> Void) {
        let fileManager = FileManager.default
        let documentDirectory = try! fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        saveProgress = 0.0
        
        for asset in assetsToSave {
            if asset.mediaType == .image {
                let requestOptions = PHImageRequestOptions()
                requestOptions.isSynchronous = true
                requestOptions.isNetworkAccessAllowed = true
                requestOptions.deliveryMode = PHImageRequestOptionsDeliveryMode.highQualityFormat
                
                PHImageManager.default().requestImageDataAndOrientation(for: asset, options: requestOptions) { imageData, _, _, _ in
                    if let data = imageData {
                        let fileName = "\(asset.localIdentifier).jpg"
                        let fileURL = documentDirectory.appendingPathComponent(fileName)
                        do {
                            try data.write(to: fileURL)
                            print("Saved asset at \(fileURL)")
                        } catch {
                            print("Failed to save asset: \(error)")
                        }
                    }
                }
                
            } else if asset.mediaType == .video {
                #if os(iOS)
                completion(nil, NSError(domain: "com.example.app", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve asset resource."]))
                #elseif os(macOS)
                guard let resource = PHAssetResource.assetResources(for: asset).first else {
                    completion(nil, NSError(domain: "com.example.app", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve asset resource."]))
                    return
                }
                
                let originalVideoExtension = (PHAssetResource.assetResources(for: asset).first?.originalFilename as NSString?)?.pathExtension ?? "mp4"
                
                let savePanel = NSSavePanel()
                if let contentType = UTType(filenameExtension: originalVideoExtension) {
                    savePanel.allowedContentTypes = [contentType]
                }
                savePanel.nameFieldStringValue = "\(UUID().uuidString).\(originalVideoExtension)"
                
                savePanel.begin { response in
                    if response == .OK, let destinationURL = savePanel.url {
                        let requestOptions = PHAssetResourceRequestOptions()
                        requestOptions.isNetworkAccessAllowed = true
                        
                        //let progress = Progress(totalUnitCount: 100)
                        
                        PHAssetResourceManager.default().writeData(for: resource, toFile: destinationURL, options: requestOptions, completionHandler: { error in
                            if let error = error {
                                completion(nil, error)
                            } else {
                                completion(destinationURL, nil)
                            }
                        })
                    } else {
                        // User cancelled the save panel
                        completion(nil, nil)
                    }
                }
                #endif
                /*
                 let destinationURL = documentDirectory.appendingPathComponent("\(UUID().uuidString).\(originalVideoExtension)")
                 
                 let requestOptions = PHAssetResourceRequestOptions()
                 requestOptions.isNetworkAccessAllowed = true
                 
                 PHAssetResourceManager.default().writeData(for: resource, toFile: destinationURL, options: requestOptions, completionHandler: { error in
                 if let error = error {
                 completion(nil, error)
                 } else {
                 completion(destinationURL, nil)
                 }
                 }
                 )*/
                
                
                
                /*
                 let options = PHVideoRequestOptions()
                 options.version = .original
                 options.isNetworkAccessAllowed = true
                 
                 PHImageManager.default().requestExportSession(forVideo: asset, options: options, exportPreset: AVAssetExportPresetPassthrough) { (exportSession, info) in
                 guard let session = exportSession else {
                 completion(nil, NSError(domain: "com.example.app", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create AVAssetExportSession."]))
                 return
                 }
                 
                 let originalVideoExtension = (PHAssetResource.assetResources(for: asset).first?.originalFilename as NSString?)?.pathExtension ?? "mp4"
                 let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(originalVideoExtension)")
                 session.outputFileType = AVFileType(rawValue: originalVideoExtension)
                 session.outputURL = destinationURL
                 
                 session.exportAsynchronously {
                 switch session.status {
                 case .completed:
                 completion(destinationURL, nil)
                 case .failed, .cancelled:
                 completion(nil, session.error)
                 default:
                 break
                 }
                 }
                 }*/
            }/*
              let requestOptions = PHVideoRequestOptions()
              requestOptions.isNetworkAccessAllowed = true
              PHImageManager.default().requestAVAsset(forVideo: asset, options: requestOptions) { avAsset, avAudioMix, info in
              if let avAsset = avAsset {
              // Create export session
              guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetPassthrough) else {
              print("Failed to create export session")
              return
              }
              
              if let uniformTypeIdentifier = asset.value(forKey: "uniformTypeIdentifier") as? String {
              let outputFileType = AVFileType(uniformTypeIdentifier)
              exportSession.outputFileType = outputFileType
              } else {
              // Handle case when uniformTypeIdentifier is unavailable
              // For example, fallback to a default output file type
              exportSession.outputFileType = AVFileType.mp4
              }
              
              var fileURL: URL
              
              if let avURLAsset = asset as? AVURLAsset {
              let directoryURL = documentsDirectory.appendingPathComponent("AVAssets")
              do {
              try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
              print("Saved asset at \(directoryURL)")
              } catch {
              print("Failed to save asset: \(error)")
              }
              
              let fileExtension = avURLAsset.url.pathExtension
              let fileName = "\(asset.localIdentifier).\(fileExtension)"
              fileURL = documentsDirectory.appendingPathComponent(fileName)
              exportSession.outputURL = fileURL
              } else {
              // Handle case when asset is not an AVURLAsset
              // For example, fallback to a default file extension
              let fileName = "\(asset.localIdentifier).mp4"
              fileURL = documentsDirectory.appendingPathComponent(fileName)
              exportSession.outputURL = fileURL
              }
              
              exportSession.exportAsynchronously {
              if exportSession.status == .completed {
              print("Saved asset at \(fileURL)")
              } else if exportSession.status == .failed {
              if let error = exportSession.error {
              print("Failed to save asset: \(error)")
              }
              } else if exportSession.status == .cancelled {
              print("Export session cancelled")
              }
              }
              } else {
              if let error = info?[PHImageErrorKey] as? Error {
              print("Failed to fetch AVAsset for the asset: \(error)")
              } else {
              print("Failed to fetch AVAsset for the asset")
              }
              }
              }
              }
              */
        }
    }
    
    func deleteAssets(completion: @escaping (Error?) -> Void) {
        let deleteQueue = Array(assetsToDelete)
        
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(deleteQueue as NSFastEnumeration)
            }
            completionHandler: { success, error in
                if success {
                    // Assets deleted successfully
                    DispatchQueue.main.async {
                        self.assetsToDelete.removeAll()
                    }
                    completion(nil)
                } else if let error = error {
                    // Handle error
                    completion(error)
                }
            }
    }
    
    /*
     func getAllPhotosSortedByFileSize() {
     let fetchOptions = PHFetchOptions()
     fetchOptions.includeAllBurstAssets = true
     fetchOptions.includeHiddenAssets = true
     
     let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
     var assetsWithSize: [(asset: PHAsset, fileSize: Int64)] = []
     
     let requestOptions = PHImageRequestOptions()
     requestOptions.isSynchronous = true
     
     let group = DispatchGroup()
     
     collections.enumerateObjects { collection, _, _ in
     let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
     assets.enumerateObjects { asset, _, _ in
     group.enter()
     PHImageManager.default().requestImageDataAndOrientation(for: asset, options: requestOptions) { imageData, _, _, _ in
     if let data = imageData {
     assetsWithSize.append((asset: asset, fileSize: Int64(data.count)))
     }
     group.leave()
     }
     }
     
     }
     
     group.notify(queue: .main) {
     // Sort the photos by file size
     let sortedPhotos = assetsWithSize.sorted(by: { $0.fileSize > $1.fileSize })
     
     // Retrieve the sorted assets
     let sortedAssets = sortedPhotos.map { $0.asset }
     
     let topAssets = Array(sortedAssets.prefix(5))
     self.sortedAssets = topAssets
     }
     }*/
    /*
     func getAllPhotosSortedByFileSize() {
     let fetchOptions = PHFetchOptions()
     fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced] // Optionally include additional asset source types if needed
     fetchOptions.includeAllBurstAssets = true
     fetchOptions.includeHiddenAssets = true
     
     
     let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
     
     var assetsWithSize: [(asset: PHAsset, fileSize: Int64)] = []
     
     let requestOptions = PHImageRequestOptions()
     requestOptions.isSynchronous = true
     
     
     fetchResult.enumerateObjects { asset, _, _ in
     PHImageManager.default().requestImageDataAndOrientation(for: asset, options: requestOptions) { imageData, _, _, _ in
     if let data = imageData {
     assetsWithSize.append((asset: asset, fileSize: Int64(data.count)))
     }
     }
     }
     
     let sortedAssets = assetsWithSize.sorted(by: { $0.fileSize > $1.fileSize })
     let sortedAssetsOnly = sortedAssets.map { $0.asset }
     self.sortedAssets = sortedAssetsOnly
     }*/
    /*
     func getAllPhotosSortedByFileSize() {
     let fetchOptions = PHFetchOptions()
     fetchOptions.predicate = NSPredicate(format: "mediaType == %d || mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
     fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
     fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
     
     let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
     
     var photosArray: [PHAsset] = []
     
     fetchResult.enumerateObjects { asset, _, _ in
     photosArray.append(asset)
     }
     
     // Create an array of tuples with asset and file size
     var photosWithSize: [(asset: PHAsset, fileSize: Int)] = []
     
     let group = DispatchGroup()
     
     for asset in photosArray {
     group.enter()
     
     let requestOptions = PHImageRequestOptions()
     requestOptions.isSynchronous = true
     
     PHImageManager.default().requestImageDataAndOrientation(for: asset, options: requestOptions) { data, _, _, _ in
     if let imageData = data {
     let fileSize = imageData.count
     photosWithSize.append((asset: asset, fileSize: fileSize))
     }
     
     group.leave()
     }
     }
     
     group.notify(queue: .main) {
     // Sort the photos by file size
     let sortedPhotos = photosWithSize.sorted(by: { $0.fileSize < $1.fileSize })
     
     // Retrieve the sorted assets
     let sortedAssets = sortedPhotos.map { $0.asset }
     
     let topAssets = Array(sortedAssets.prefix(5))
     self.sortedAssets = topAssets
     }
     }*/
}
