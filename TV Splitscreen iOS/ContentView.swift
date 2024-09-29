import Combine
import SwiftUI
import WebKit

let STARTING_URL = "https://www.google.com"

class WebViewController: ObservableObject {
    let webView: WKWebView
    @Published var isMuted: Bool = true
    
    init(url: URL) {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        
        let script = WKUserScript(
            source: """
            var splitscreen_muted = true;
            var was_paused = true;
            function muteAllVideos() {
                var videos = document.getElementsByTagName('video');
                for (var i = 0; i < videos.length; i++) {
                    videos[i].muted = splitscreen_muted;
                    videos[i].setAttribute('playsinline', '');
                    if (!videos[i].paused) {
                        if (was_paused) {
                            moveVideo();
                            was_paused = false;
                        }
                        window.scrollTo(0, document.body.scrollHeight + 10000);
                    }
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
        
        contentController.addUserScript(script)
        config.userContentController = contentController
        config.allowsInlineMediaPlayback = true
        
        self.webView = WKWebView(frame: .zero, configuration: config)
        self.webView.scrollView.contentInset = .zero
        self.webView.scrollView.scrollIndicatorInsets = .zero
        self.webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        let request = URLRequest(url: url)
        self.webView.load(request)
    }
    
    func mute(_ muted: Bool) {
        isMuted = muted
        webView.evaluateJavaScript("""
            splitscreen_muted = true;
            setTimeout(() => {splitscreen_muted = \(muted)}, 1500);
            videos = document.getElementsByTagName('video');
            setTimeout(() => {videos[videos.length - 1].play()}, 2500);
        """)
    }
    
    func refresh() {
        webView.reload()
    }
    
    func reset(url: URL) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

struct WebView: UIViewRepresentable {
    @ObservedObject var controller: WebViewController
    @ObservedObject var interactionTracker: InteractionTracker
    
    func makeUIView(context: Context) -> WKWebView {
        controller.webView.scrollView.delegate = context.coordinator
        let hoverGesture = UIHoverGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleHover(_:)))
        controller.webView.addGestureRecognizer(hoverGesture)
        return controller.webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.scrollView.contentInsetAdjustmentBehavior = .never
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            parent.interactionTracker.trackInteraction()
        }
        
        @objc func handleHover(_ gesture: UIHoverGestureRecognizer) {
            switch gesture.state {
            case .began, .changed:
                parent.interactionTracker.trackInteraction()
            default:
                break
            }
        }
    }
}

class WebViewControllerManager: ObservableObject {
    @Published var controllers: [WebViewController]
    
    init() {
        self.controllers = [
            WebViewController(url: URL(string: STARTING_URL)!),
            WebViewController(url: URL(string: STARTING_URL)!),
            WebViewController(url: URL(string: STARTING_URL)!),
            WebViewController(url: URL(string: STARTING_URL)!)
        ]
    }
}

struct ContentView: View {
    @State private var isMenuOpen = true
    @State private var numWebViews = 1
    @State private var unmutedWebView = 0
    @StateObject private var webControllerManager = WebViewControllerManager()
    @StateObject private var interactionTracker = InteractionTracker()
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                if geometry.size.width > geometry.size.height && numWebViews > 2  {
                    // iPad landscape > 2
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            ForEach(0..<2, id: \.self) { index in
                                WebView(controller: webControllerManager.controllers[index], interactionTracker: interactionTracker)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .edgesIgnoringSafeArea(.all)
                            }
                        }.edgesIgnoringSafeArea(.all)
                        HStack(spacing: 0) {
                            ForEach(2..<numWebViews, id: \.self) { index in
                                WebView(controller: webControllerManager.controllers[index], interactionTracker: interactionTracker)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .edgesIgnoringSafeArea(.all)
                            }
                        }.edgesIgnoringSafeArea(.all)
                    }.edgesIgnoringSafeArea(.all)
                } else {
                    // iPad landscape < 2, iPad portrait
                    VStack(spacing: 0) {
                        ForEach(0..<numWebViews, id: \.self) { index in
                            WebView(controller: webControllerManager.controllers[index], interactionTracker: interactionTracker)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .edgesIgnoringSafeArea(.all)
                        }
                    }.edgesIgnoringSafeArea(.all)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                interactionTracker.trackInteraction()
                if isMenuOpen {
                    withAnimation {
                        isMenuOpen = false
                    }
                }
            }
            
            VStack {
                HStack {
                    Spacer()
                    if isMenuOpen {
                        FloatingMenu(numWebViews: $numWebViews,
                                     unmutedWebView: $unmutedWebView,
                                     webControllers: webControllerManager.controllers).padding(.top, 20)
                    }
                    if interactionTracker.isGearIconVisible || isMenuOpen {
                        Button(action: {
                            withAnimation {
                                interactionTracker.trackInteraction()
                                isMenuOpen.toggle()
                            }
                        }) {
                            Image(systemName: "gear")
                                .foregroundColor(.white)
                                .font(.system(size: 30))
                                .frame(width: 60, height: 60)
                                .background(Color(red: 0, green: 0, blue: 0, opacity: 0.5))
                                .clipShape(Circle())
                        }
                        .padding(.top, 20)
                        .padding(.trailing, 15)
                    }
                }
                Spacer()
            }
        }.edgesIgnoringSafeArea(.all)
        .statusBarHidden()
        .onChange(of: unmutedWebView) { newValue in
            for (index, controller) in webControllerManager.controllers.enumerated() {
                controller.mute(index + 1 != newValue)
            }
        }
        .onChange(of: numWebViews) { newValue in
            for (index, controller) in webControllerManager.controllers.enumerated() {
                if index >= numWebViews {
                    controller.reset(url: URL(string: STARTING_URL)!)
                }
            }
        }
        .apply({
            if #available(iOS 17.0, *) {
                $0.persistentSystemOverlays(.hidden)
            } else {
                $0
            }
        })
    }
}

extension View {
    func apply<V: View>(@ViewBuilder _ block: (Self) -> V) -> V { block(self) }
}

struct FloatingMenu: View {
    @Binding var numWebViews: Int
    @Binding var unmutedWebView: Int
    let webControllers: [WebViewController]
    
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
                .frame(maxWidth: 300)
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
                .frame(maxWidth: 300)
            }
            HStack {
                Spacer()
                Text("Refresh:")
                HStack {
                    Spacer()
                    ForEach(0..<numWebViews, id: \.self) { index in
                        Button(action: {
                            webControllers[index].refresh()
                        }, label: {
                            Text(String(index + 1))
                                .foregroundColor(.white)
                                .padding(.top)
                                .padding(.bottom)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .background(Color.gray.opacity(0.5))
                                .cornerRadius(10)
                        })
                        if index != numWebViews - 1 {
                            Spacer()
                        }
                    }
                    Spacer()
                }.padding().frame(maxWidth: 300)
            }
            HStack {
                Spacer()
                Text("Reset:")
                HStack {
                    Spacer()
                    ForEach(0..<numWebViews, id: \.self) { index in
                        Button(action: {
                            webControllers[index].reset(url: URL(string: STARTING_URL)!)
                        }, label: {
                            Text(String(index + 1))
                                .foregroundColor(.white)
                                .padding(.top)
                                .padding(.bottom)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .background(Color.gray.opacity(0.5))
                                .cornerRadius(10)
                        })
                        if index != numWebViews - 1 {
                            Spacer()
                        }
                    }
                    Spacer()
                }.padding().frame(maxWidth: 300)
            }
        }
        .padding()
        .background(Color.black.opacity(0.9))
        .cornerRadius(15)
        .shadow(radius: 5)
        .frame(maxWidth: 450)
    }
}

class InteractionTracker: ObservableObject {
    @Published var lastInteractionTime: Date = Date()
    private var timer: AnyCancellable?
    @Published var isGearIconVisible = true

    init() {
        startTimer()
    }

    func trackInteraction() {
        lastInteractionTime = Date()
        isGearIconVisible = true
#if targetEnvironment(macCatalyst)
        NSCursor.unhide()
#endif
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if Date().timeIntervalSince(self.lastInteractionTime) > 5 {
                    self.isGearIconVisible = false
#if targetEnvironment(macCatalyst)
                    NSCursor.hide()
#endif
                }
            }
    }
}
struct PointerMoveModifier: ViewModifier {
    @ObservedObject var interactionTracker: InteractionTracker
    
    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if hovering {
                    interactionTracker.trackInteraction()
                }
            }
    }
}

extension View {
    func trackPointerMoves(using tracker: InteractionTracker) -> some View {
        self.modifier(PointerMoveModifier(interactionTracker: tracker))
    }
}

#Preview {
    ContentView()
}
