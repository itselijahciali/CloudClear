//
//  ContentView.swift
//  CloudClear
//
//  Created by Elijah Ciali on 6/23/23.
//

import SwiftUI
import Photos

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

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size:20,design:.rounded))
            .padding(20)
            .frame(width: 170)
            .foregroundColor(Color(red:0.11,green:0.08,blue:0.39))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke()
                    .shadow(color: Color("BasePurpleShad"), radius: 3, x: 0, y: configuration.isPressed ? -5 : 0)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 10)
                    )
            )
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
            .background(whitePurpleGradient)
            .clipShape(RoundedRectangle(cornerRadius: 10))
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
                        .buttonStyle(PrimaryButton())
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
                        Text(fileSizeString(for: asset))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .background(viewModel.selectedAssets.contains(asset) ? Color("WhitePurple") : nil)
                    .onTapGesture {
                        DispatchQueue.main.async {
                                toggleSelection(for: asset)
                            }
                }
            }.scrollContentBackground(.hidden)
            
            VStack{
                if !viewModel.selectedAssets.isEmpty {
                    Button("Save") {
                        viewModel.saveSelectedAssets(){ (exportedURL, error) in
                            if let url = exportedURL {
                                // Video exported successfully, do something with the URL
                                print("Exported video URL: \(url)")
                                viewModel.selectedAssets.removeAll()
                            } else if let exportError = error {
                                // Handle export error
                                print("Export error: \(exportError.localizedDescription)")
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
    
    
    
    func toggleSelection(for asset: PHAsset) {
        if viewModel.selectedAssets.contains(asset) {
            viewModel.selectedAssets.removeAll { $0 == asset }
        } else {
            viewModel.selectedAssets.append(asset)
        }
    }
    
    
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
