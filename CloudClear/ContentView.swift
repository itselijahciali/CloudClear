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
                purpleGradient
                #if os(iOS)
                    .edgesIgnoringSafeArea(.all) // On iOS only the gradient ignores safe area
                #endif
                VStack{
                    StartView(viewModel: viewModel,sortingComplete: self.$sortingComplete)
                    #if os(macOS)
                        .background(sortingComplete ? Color.black.opacity(0.5) : nil) // Darker title bar in PhotoView
                    #endif
                        .frame(maxHeight:sortingComplete ? 50 : .infinity) // StartView remains with just the cloud animation
                        .animation(.easeOut(duration: 0.2), value: sortingComplete)
                    if sortingComplete {
                        PhotoView(viewModel: viewModel)
                    }
                }
            }
            #if os(macOS)
            .edgesIgnoringSafeArea(.all) // On macOS everything ignores the safe area since we nuked the title bar
            #endif
        }//.navigationBarHidden(true)
    }
    
}

struct NewView: View {
    var body: some View {
        Text("Hello World")
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
            if (!sortingComplete) {
                whitePurpleGradient.mask(
                    VStack{
                        Text("CloudClear").font(.system(size:60,weight:.bold,design:.rounded))
                        Text("Finally reclaim your cloud sotrage!").font(.system(size:20,weight:.bold,design:.rounded))
                    }
                ).frame(maxHeight:100)
            }
            LottieView(lottieFile: "CloudIdleAnimation")
            if (!sortingComplete) {
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
                                .font(.system(size:20,weight:.bold,design:.rounded))
                                .foregroundColor(Color("WhitePurple"))
                        }
                        .tint(.white)
                        .padding()
                        .transition(.move(edge:.trailing))
                    }
                }.frame(height:100)
            }
        }.padding([.top,.bottom],sortingComplete ? 0 : 50)
    }
}

struct PhotoView: View {
    @ObservedObject var viewModel: PhotoViewModel
    
    var body: some View {
        VStack(spacing:0) {
            /*
#if os(macOS)
            VStack{
                Spacer()
            }
            .frame(maxWidth: .infinity,maxHeight:1)
            .background(Color.white.opacity(0.5))
#endif*/
            List(Array(viewModel.sortedAssets.enumerated()), id: \.offset) { index, asset in
                VStack {
                    HStack {
                        if let thumbnail = fetchThumbnail(for: asset) {
#if os(macOS)
                            Image(nsImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
#else
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
#endif
                        } else {
                            Color.gray
                                .frame(width: 120, height: 120)
                        }
                        if let fileName = fetchFileName(for: asset) {
                            Text(fileName)
                        }
                    }
                    HStack{
                        Text(fileSizeString(for: asset))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        #if os(macOS)
                        Button("Save") {toggleSave(for: asset)}
                            .buttonStyle(SecondaryButton(backgroundGradient: blueGradient,textColor: Color("BaseBlueLight")))
                            .opacity(viewModel.assetsToSave.contains(asset) ? 1.0 : 0.5)
                        #elseif os(iOS)
                        Button("Share") {toggleShare(for: asset)}
                            .buttonStyle(SecondaryButton(backgroundGradient: blueGradient,textColor: Color("BaseBlueLight")))
                            .opacity(viewModel.assetsToSave.contains(asset) ? 1.0 : 0.5)
                        #endif
                        Button("Delete") {toggleDelete(for: asset)}
                            .buttonStyle(SecondaryButton(backgroundGradient: redGradient,textColor: Color("BaseRedLight")))
                            .opacity(viewModel.assetsToDelete.contains(asset) ? 1.0 : 0.5)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(5)
                .background(
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    ).fill(Color(.white))
                )
                .padding(2)
            }
            .colorScheme(.light)
            .scrollContentBackground(.hidden)
            
            VStack{
                if !viewModel.assetsToDelete.isEmpty || !viewModel.assetsToSave.isEmpty {
                    Button("Continue") {
                        viewModel.saveAssets(){ (exportedURL, error) in
                            if let url = exportedURL {
                                print("Exported video URL: \(url)")
                                DispatchQueue.main.async {
                                    viewModel.assetsToSave.removeAll()
                                }
                                
                                viewModel.deleteAssets(){ (error) in
                                    if let error = error {
                                        print("Delete error: \(error.localizedDescription)")
                                    } else {
                                        print("Deleted asset successfully")
                                        DispatchQueue.main.async {
                                            viewModel.sortedAssets.removeAll{ asset in
                                                viewModel.assetsToDelete.contains(asset)
                                            }
                                        }
                                        viewModel.assetsToDelete.removeAll()
                                        
                                    }
                                }
                                
                            } else if let exportError = error {
                                // Handle export error
                                print("Export error: \(exportError.localizedDescription)")
                            }
                        }
                        
                    }
                        .buttonStyle(PrimaryButton(backgroundGradient: whitePurpleGradient,textColor: Color("BasePurpleShad")))
                    Text("Total File Size: \(ByteCountFormatter.string(fromByteCount: viewModel.totalFileSize, countStyle: .file))")
                        .font(.system(size:10,weight:.bold,design:.rounded))
                        .foregroundColor(Color("WhitePurple"))
                } else {
                    Text("No items selected")
                        .font(.system(size:10,weight:.bold,design:.rounded))
                        .foregroundColor(Color("WhitePurple"))
                }
            }
            .frame(maxWidth: .infinity,minHeight:120)
            .background(Color.black.opacity(0.5))
        }
    }
    
    func toggleSave(for asset: PHAsset) {
        if viewModel.assetsToSave.contains(asset) {
            viewModel.assetsToSave.removeAll { $0 == asset }
        } else {
            viewModel.assetsToSave.append(asset)
        }
    }
    
    func toggleShare(for asset: PHAsset) {
        if viewModel.assetsToShare.contains(asset) {
            viewModel.assetsToShare.removeAll { $0 == asset }
        } else {
            viewModel.assetsToShare.append(asset)
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
            targetSize: CGSize(width: 120, height: 120),
            contentMode: .aspectFill,
            options: requestOptions,
            resultHandler: { image, _ in
                thumbnailImage = image
            }
        )
        
        return thumbnailImage
    }
    
    func fetchFileName(for asset: PHAsset) -> String? {
        let resource = PHAssetResource.assetResources(for: asset).first
        return resource?.originalFilename
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
