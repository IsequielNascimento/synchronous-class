import SwiftUI
import WebRTC

struct LiveStreamView: View {
    @StateObject var viewModel: LiveStreamViewModel
    
    var body: some View {
        VStack {
            //Se tiver vídeo, renderiza
            if let videoTrack = viewModel.webRTCService.remoteVideoTrack {
                VideoView(videoTrack: videoTrack).ignoresSafeArea()
                // Se não, mostrar mensagem de erro
            } else if !viewModel.errorMessage.isEmpty {
                Text("Erro: \(viewModel.errorMessage)").foregroundColor(.red)
            } else {
                VStack {
                    //Loading
                    ProgressView()
                    Text("Aguardando transmissão...").foregroundColor(.white)
                }
            }
            
            //Barra de status da transmissão
            HStack {
                Circle()
                    .fill(viewModel.webRTCService.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(viewModel.webRTCService.isConnected ? "Conectado" : "Conectando...")
                    .foregroundColor(.white)
                
                if viewModel.webRTCService.isStreamActive {
                    Text("AO VIVO")
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
            //Conecta na sala apenas quando carregar a tela
            await viewModel.connect()
        }
    }
}
