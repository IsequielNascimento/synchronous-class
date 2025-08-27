import SwiftUI
import WebRTC

struct VideoView: UIViewRepresentable {
    let videoTrack: RTCVideoTrack

    // Encapsula o renderer de vídeo WebRTC (RTCMTLVideoView)
    func makeUIView(context: Context) -> RTCMTLVideoView {
        let renderer = RTCMTLVideoView() // cria o renderer baseado em Metal OBS: Checar mais sobre renders
        renderer.videoContentMode = .scaleAspectFit
        renderer.clipsToBounds = true 
        videoTrack.add(renderer)// conecta o vídeo ao renderer
        return renderer
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {}

    static func dismantleUIView(_ uiView: RTCMTLVideoView, coordinator: ()) {
       
    }
}
