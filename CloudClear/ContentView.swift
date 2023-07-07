//
//  ContentView.swift
//  CloudClear
//
//  Created by Elijah Ciali on 6/23/23.
//

import SwiftUI
import Photos
import QuickLook

#if os(iOS)
typealias PlatformImage = UIImage
#elseif os(macOS)
typealias PlatformImage = NSImage
#endif

let purpleGradient = LinearGradient(
    colors: [Color("BasePurple"),
             Color("BasePurpleShad")],
    startPoint: .top, endPoint: .bottom)

let whitePurpleGradient = LinearGradient(
    colors: [Color("WhitePurple"),
             Color("WhitePurpleShad")],
    startPoint: .top, endPoint: .bottom)

let redGradient = LinearGradient(
    colors: [Color("BaseRed"),
             Color("BaseRedShad")],
    startPoint: .top, endPoint: .bottom)

let blueGradient = LinearGradient(
    colors: [Color("BaseBlue"),
             Color("BaseBlueShad")],
    startPoint: .top, endPoint: .bottom)

struct PrimaryButton: ButtonStyle {
    var backgroundGradient: LinearGradient
    var textColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size:20,weight:.bold,design:.rounded))
            .padding(20)
            .frame(width: 170)
            .foregroundColor(textColor)
        
        .background(backgroundGradient)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.1))
                    .shadow(color: Color.black, radius: 3, x: 0, y: configuration.isPressed ? 0 : -2)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 10)
                    )
            )
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct SecondaryButton: ButtonStyle {
    var backgroundGradient: LinearGradient
    var textColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size:10,weight:.bold,design:.rounded))
            .padding(5)
            .foregroundColor(textColor)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.black.opacity(0.1))
                    .shadow(color: Color.black, radius: 3, x: 0, y: configuration.isPressed ? 0 : -2)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 5)
                    )
            )
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
            .background(backgroundGradient)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

struct ContentView: View {
    @StateObject var viewModel = PhotoViewModel()
    @State var sortingComplete: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                purpleGradient.edgesIgnoringSafeArea(.all)
                if sortingComplete {
                    PhotoView(viewModel: viewModel)
                } else {
                    StartView(viewModel: viewModel,sortingComplete: self.$sortingComplete)
                }
                
            }
        }//.navigationBarHidden(true)
    }
    
}

struct StartView: View {
    @ObservedObject var viewModel: PhotoViewModel
    @Binding var sortingComplete: Bool
    
    var body: some View {
        
        /*NavigationLink(destination: PhotoView(viewModel: viewModel).transition(.slide), isActive: $sortingComplete)
         {
         EmptyView()
         }*/
        
        VStack {
            Spacer()
            whitePurpleGradient.mask(
                VStack{
                    Text("CloudClear").font(.system(size:60,weight:.bold,design:.rounded))
                    Text("Finally reclaim your cloud sotrage!").font(.system(size:20,weight:.bold,design:.rounded))
                }
            ).frame(maxHeight:100)
            LottieView(lottieFile: "CloudIdleAnimation")
            HStack{
                if(viewModel.sortProgress == 0.0) {
                    VStack{
                        Button("Sort Photos"){
                            viewModel.getAllPhotosSortedByFileSize {
                                self.sortingComplete.toggle()
                            }
                        }
                        .buttonStyle(PrimaryButton(backgroundGradient: whitePurpleGradient,textColor: Color("BasePurpleShad")))
                    }.padding()
                } else {
                    
                    ProgressView(value: viewModel.sortProgress, total: 1.0){
                        Text(String(format: "%.0f",round(100*viewModel.sortProgress))+"%")
                    }
                    .tint(.white)
                    .padding()
                    .transition(.move(edge:.trailing))
                }
            }.frame(height:100)
        }.padding([.top,.bottom],50)
    }
}

struct PhotoView: View {
    @ObservedObject var viewModel: PhotoViewModel
    
    var body: some View {
        VStack {
#if os(macOS)
            VStack{
                Spacer()
            }
            .frame(maxWidth: .infinity,maxHeight:1)
            .background(Color.white.opacity(0.5))
#endif
            List(Array(viewModel.sortedAssets.enumerated()), id: \.offset) { index, asset in
                VStack {
                    HStack {
                        if let thumbnail = fetchThumbnail(for: asset) {
#if os(macOS)
                            Image(nsImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
#else
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
#endif
                        } else {
                            Color.gray
                                .frame(width: 80, height: 80)
                        }
                        Text(asset.localIdentifier)
                    }
                    HStack{
                        Text(fileSizeString(for: asset))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Save") {
                            toggleSave(for: asset)
                        }.buttonStyle(SecondaryButton(backgroundGradient: blueGradient,textColor: Color("BaseBlueLight")))
                        Button("Delete") {
                            toggleDelete(for: asset)
                        }.buttonStyle(SecondaryButton(backgroundGradient: redGradient,textColor: Color("BaseRedLight")))
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .background(viewModel.assetsToDelete.contains(asset) ? Color("WhitePurple") : nil)
                .onTapGesture {
                    DispatchQueue.main.async {
                    }
                }
            }.scrollContentBackground(.hidden)
            
            VStack{
                if !viewModel.assetsToDelete.isEmpty {
                    Button("Continue") {
                        viewModel.saveAssets(){ (exportedURL, error) in
                            if let url = exportedURL {
                                // Video exported successfully, do something with the URL
                                print("Exported video URL: \(url)")
                                viewModel.assetsToSave.removeAll()
                            } else if let exportError = error {
                                // Handle export error
                                print("Export error: \(exportError.localizedDescription)")
                            }
                        }
                        viewModel.deleteAssets(){ (error) in
                            if let error = error {
                                // Handle deletion error
                                print("Failed to delete assets: \(error)")
                            } else {
                                viewModel.assetsToDelete.removeAll()
                            }
                        }
                    }
                    Text("Total File Size: \(ByteCountFormatter.string(fromByteCount: viewModel.totalFileSize, countStyle: .file))")
                } else {
                    Text("No items selected")
                }
            }
            .frame(maxWidth: .infinity,minHeight:100)
            .background(Color.white.opacity(0.5))
        }
    }
    
    func toggleSave(for asset: PHAsset) {
        if viewModel.assetsToSave.contains(asset) {
            viewModel.assetsToSave.removeAll { $0 == asset }
        } else {
            viewModel.assetsToSave.append(asset)
        }
    }
    func toggleDelete(for asset: PHAsset) {
        if viewModel.assetsToDelete.contains(asset) {
            viewModel.assetsToDelete.removeAll { $0 == asset }
        } else {
            viewModel.assetsToDelete.append(asset)
        }
    }
    /*
    func getAssetURL(from asset: PHAsset, completion: (URL?) -> Void) {
        
        let requestOptions = PHVideoRequestOptions()
        requestOptions.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: requestOptions) { avAsset, audioMix, info in
            /*guard let avAsset = avAsset as? AVURLAsset else {
             return
             }*/
            if let urlAsset = avAsset as? AVURLAsset {
                completion(urlAsset.url)
            }
        }
    }*/
    
    func fetchThumbnail(for asset: PHAsset) -> PlatformImage? {
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        
        var thumbnailImage: PlatformImage?
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 80, height: 80),
            contentMode: .aspectFill,
            options: requestOptions,
            resultHandler: { image, _ in
                thumbnailImage = image
            }
        )
        
        return thumbnailImage
    }
    
    func fileSizeString(for asset: PHAsset) -> String {
        let resource = PHAssetResource.assetResources(for: asset).first
        let fileSize = resource?.value(forKey: "fileSize") as? Int64 ?? 0
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
}

struct LibraryViewPreview: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
