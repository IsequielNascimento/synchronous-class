import SwiftUI
import WebRTC

struct VideoView: UIViewRepresentable {
    let videoTrack: RTCVideoTrack

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let renderer = RTCMTLVideoView()
        renderer.videoContentMode = .scaleAspectFit
        renderer.clipsToBounds = true
        videoTrack.add(renderer)
        return renderer
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {}

    static func dismantleUIView(_ uiView: RTCMTLVideoView, coordinator: ()) {
       
    }
}
