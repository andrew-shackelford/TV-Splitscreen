//
//  ContentView.swift
//  TV Splitscreen iOS
//
//  Created by Andrew Shackelford on 9/6/24.
//

import SwiftUI
import WebKit

struct ContentView: View {
    @State private var isMenuOpen = true
    @State private var unmutedWebView = 1
    @State private var numWebViews = 1
    @State private var moveVideo = 0
    @State private var refreshWebView = 0
    @State private var resetWebView = 0
    
    var body: some View {
            ZStack {
                VStack(spacing: 0) {
                    ForEach(1...numWebViews, id: \.self) { index in
                        WebView(url: URL(string: "https://the.streameast.app")!, muted: unmutedWebView != index, moveVideo: moveVideo == index, onMoveVideo: {moveVideo = 0}, refresh: refreshWebView == index, onRefresh: {
                            refreshWebView = 0
                        }, reset: resetWebView == index, onReset: {
                            resetWebView = 0
                        }).frame(maxWidth: .infinity, maxHeight: .infinity).edgesIgnoringSafeArea(.all)
                    }
                }.edgesIgnoringSafeArea(.all)
                VStack {
                    HStack {
                        Spacer()
                        if isMenuOpen {
                            FloatingMenu(numWebViews: $numWebViews,
                                         unmutedWebView: $unmutedWebView, moveVideo: $moveVideo, refreshWebView: $refreshWebView, resetWebView: $resetWebView).padding()
                        }
                        Button(action: {
                            withAnimation {
                                print("toggling menu app")
                                isMenuOpen.toggle()
                            }
                        }) {
                            Image(systemName: "gear")
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                                .background(Color(red: 0, green: 0, blue: 0, opacity: 0.5))
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                    Spacer()
                }
            }.edgesIgnoringSafeArea(.all)
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
    }
}

struct FloatingMenu: View {
    @Binding var numWebViews: Int
    @Binding var unmutedWebView: Int
    @Binding var moveVideo: Int
    @Binding var refreshWebView: Int
    @Binding var resetWebView: Int
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                Text("Num streams:")
                Picker("Num streams", selection: $numWebViews) {
                    ForEach(1...4, id: \.self) { index in
                        Text(String(index)).tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .frame(maxWidth: 400)
            }
            HStack {
                Spacer()
                Text("Sound:")
                Picker("Sound", selection: $unmutedWebView) {
                    Text("None").tag(0)
                    ForEach(1...numWebViews, id: \.self) { index in
                        Text(String(index)).tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .frame(maxWidth: 400)
            }
            HStack {
                Spacer()
                Text("Move video:")
                HStack {
                    Spacer()
                    ForEach(1...numWebViews, id: \.self) { index in
                        Button(action: {
                            print("move webview \(index)")
                            moveVideo = index
                        }, label: {
                            Text(String(index))
                                .foregroundColor(.white)
                                .padding()
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .background(Color.gray.opacity(0.5))
                                .cornerRadius(10)
                        })
                        if index != numWebViews {
                            Spacer()
                        }
                    }
                    Spacer()
                }.padding().frame(maxWidth: 400)
            }
            HStack {
                Spacer()
                Text("Refresh:")
                HStack {
                    Spacer()
                    ForEach(1...numWebViews, id: \.self) { index in
                        Button(action: {
                            print("refresh webview \(index)")
                            refreshWebView = index
                        }, label: {
                            Text(String(index))
                                .foregroundColor(.white)
                                .padding()
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .background(Color.gray.opacity(0.5))
                                .cornerRadius(10)
                        })
                        if index != numWebViews {
                            Spacer()
                        }
                    }
                    Spacer()
                }.padding().frame(maxWidth: 400)
            }
            HStack {
                Spacer()
                Text("Reset:")
                HStack {
                    Spacer()
                    ForEach(1...numWebViews, id: \.self) { index in
                        Button(action: {
                            print("reset webview \(index)")
                            resetWebView = index
                        }, label: {
                            Text(String(index))
                                .foregroundColor(.white)
                                .padding()
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .background(Color.gray.opacity(0.5))
                                .cornerRadius(10)
                        })
                        if index != numWebViews {
                            Spacer()
                        }
                    }
                    Spacer()
                }.padding().frame(maxWidth: 400)
            }
            
        }
        .padding()
        .background(Color.black.opacity(0.9))
        .cornerRadius(15)
        .shadow(radius: 5)
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    let muted: Bool
    let moveVideo: Bool
    let onMoveVideo: () -> Void
    let refresh: Bool
    let onRefresh: () -> Void
    let reset: Bool
    let onReset: () -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        
        // Create a user script to mute all videos
        let muteVideoScript = WKUserScript(
            source: """
        let splitscreen_muted = \(muted)
        function muteAllVideos() {
            var videos = document.getElementsByTagName('video');
            for (var i = 0; i < videos.length; i++) {
                videos[i].muted = splitscreen_muted;
            }
        }
        function moveVideo() {
            document.body.appendChild(document.getElementsByTagName('video')[0]);
            document.getElementsByTagName('video')[0].style.backgroundColor = '#000';
        }
        document.body.getElementsByClassName('site-nav')[0].style.display = 'none';
        document.body.style.setProperty('background-color', 'black', 'important');

        setInterval(muteAllVideos, 1000);
        """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        
        // Add the user script to the content controller
        contentController.addUserScript(muteVideoScript)
        
        // Set the content controller to the configuration
        config.userContentController = contentController
        
        // Create the WKWebView with the configuration
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.contentInset = .zero
        webView.scrollView.scrollIndicatorInsets = .zero
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if url != context.coordinator.url {
            context.coordinator.url = url;
            let request = URLRequest(url: url)
            uiView.load(request)
        }
        if muted != context.coordinator.muted {
            context.coordinator.muted = muted;
            print("Muted changed to \(muted)")
            uiView.evaluateJavaScript("""
            splitscreen_muted = true;
            setTimeout(() => {splitscreen_muted = \(muted)}, 1500);
            videos = document.getElementsByTagName('video');
            setTimeout(() => {videos[videos.length - 1].play()}, 2500);
            """)
        }
        if refresh {
            uiView.reload()
            onRefresh()
        }
        if reset {
            let request = URLRequest(url: url)
            uiView.load(request)
            onReset()
        }
        if moveVideo {
            uiView.evaluateJavaScript("moveVideo();")
            onMoveVideo()
        }
        uiView.scrollView.contentInsetAdjustmentBehavior = .never
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: WebView
        var url: URL
        var muted: Bool
        
        init(_ parent: WebView) {
            self.parent = parent
            self.url = parent.url
            self.muted = parent.muted
        }
    }
}

#Preview {
    ContentView()
}
