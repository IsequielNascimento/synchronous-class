//
//  LiveStreamScreen.swift
//  aluno-webrtc-ios
//
//  Created by Isequiel Henrique do Nascimento on 20/08/25.
//
// LiveStreamScreen.swift
import SwiftUI
import WebRTC

struct LiveStreamScreen: View {
    let roomCode: String
    let serverUrl: String

    @StateObject private var webRTCService = WebRTCService()
    @State private var connectionStatus: String = "Conectando..."
    @State private var isConnected = false
    @State private var isStreamActive = false
    @State private var errorMessage: String = ""

    var body: some View {
        VStack {
            // Acesso ao  remoteVideoTrack
            if let videoTrack = webRTCService.remoteVideoTrack {
                // Passando o RTCVideoTrack para a VideoView
                VideoView(videoTrack: videoTrack)
                    .ignoresSafeArea()
            } else if !errorMessage.isEmpty {
                Text("Erro: \(errorMessage)")
                    .foregroundColor(.red)
            } else {
                VStack {
                    ProgressView()
                    Text("Aguardando transmissão...")
                        .foregroundColor(.white)
                }
            }

            HStack {
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text(connectionStatus)
                    .foregroundColor(.white)
                Spacer()
                if isStreamActive {
                    Text("AO VIVO") //Pendente: não está ocorrendo atualização visual do status "conectando" para "ao vivo"
                        .padding(6)
                        .background(Color.red)
                        .cornerRadius(4)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(Color.black)
        }
        .background(Color.black)
        .task {
             await webRTCService.joinRoom(serverUrl: serverUrl, roomCode: roomCode)
        }
    }
}

// VideoView precisa receber um RTCVideoTrack
struct VideoView: UIViewRepresentable {
    let videoTrack: RTCVideoTrack

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let renderer = RTCMTLVideoView() // Cria o renderer
        renderer.videoContentMode = .scaleAspectFill
        renderer.clipsToBounds = true
        videoTrack.add(renderer) // Adiciona o track ao renderer
        return renderer
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {

    }
    
    // Pendente: adicionar um método para limpar o renderer quando a view for destruída
    static func dismantleUIView(_ uiView: RTCMTLVideoView, coordinator: ()) {
      
    }
}
