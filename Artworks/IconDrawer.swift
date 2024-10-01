//
//  IconDrawer.swift
//  TRApp
//
//  Created by 秋星桥 on 2024/3/6.
//

// swiftc -parse-as-library IconDrawer.swift
// ./IconDrawer

import QuickLook
import SwiftUI

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

let previewSize = CGSize(width: 1024, height: 1024)
let symbolWidth: CGFloat = 600

struct ContentView: View {
    var body: some View {
        PreviewExporter()
            .scaleEffect(.init(width: 0.5, height: 0.5))
            .frame(width: previewSize.width / 2, height: previewSize.height / 2, alignment: .center)
    }
}

struct PreviewWaveformView: View {
    let waveWidth: CGFloat = 32
    let waveHeight: CGFloat = symbolWidth
    let waveSpacing: CGFloat = 32

    struct Waves: Identifiable, Equatable {
        var id: UUID = .init()
        var height: CGFloat
    }

    let waves: [Waves]

    init() {
        var builder = [Waves]()
        let targetCount = 128
        while builder.count < targetCount {
            builder.append(.init(height: .random(in: 0.2 ... 1.0)))
        }
        while builder.count > targetCount {
            builder.removeLast()
        }
        waves = builder
    }

    var body: some View {
        HStack(alignment: .center, spacing: waveSpacing) {
            ForEach(waves) { wave in
                RoundedRectangle(cornerRadius: waveWidth / 2)
                    .frame(width: waveWidth, height: waveHeight * wave.height)
                    .animation(.spring, value: wave.height)
            }
        }
        .frame(maxHeight: .infinity)
        .padding(-8)
    }
}

struct PreviewBannerView: View {
    var body: some View {
        ZStack {
            Image(systemName: "hand.raised.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: symbolWidth, height: symbolWidth)
                .font(.system(size: symbolWidth, weight: .regular, design: .rounded))
                .opacity(0.88)
                .padding(72)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(50)
        .background {
            LinearGradient( // f74c06, e62314
                gradient: Gradient(colors: [
                    Color(red: 247 / 255, green: 76 / 255, blue: 6 / 255),
                    Color(red: 230 / 255, green: 35 / 255, blue: 20 / 255)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .frame(width: previewSize.width, height: previewSize.height, alignment: .center)
        .clipped()
    }
}

struct PreviewExporter: View {
    var body: some View {
        VStack {
            PreviewBannerView()
                .onTapGesture {
                    let renderer = ImageRenderer(content: PreviewBannerView())
                    let data = renderer.nsImage!.tiffRepresentation!
                    let url = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent("AppIcon")
                        .appendingPathExtension("tiff")
                    try! data.write(to: url)
                    NSWorkspace.shared.open(url)
                }
        }
    }
}
