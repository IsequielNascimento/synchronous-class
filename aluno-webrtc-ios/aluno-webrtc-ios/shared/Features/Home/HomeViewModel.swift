import SwiftUI

@MainActor
class HomeViewModel: ObservableObject {
    //Dados relacionado ao forms
    @Published var roomCode: String = ""
    @Published var serverUrl: String = "http://10.200.201.199:3000"

    // Estado da interface
    @Published var isLoading = false
    @Published var alertMessage: String?
    
    private let coordinator: HomeCoordinator
    
    init(coordinator: HomeCoordinator) {
        self.coordinator = coordinator
    }
    
    //Lógica de acesso a Sala de Aula
    func joinClass() async -> AnyView? {
        guard roomCode.count == 6 else {
            alertMessage = "O código deve ter 6 dígitos"
            return nil
        }
        
        isLoading = true
        do {
            // Verifica se existe uma sala no servidor
            let roomExists = try await WebRTCService.checkRoomExists(serverUrl: serverUrl, roomCode: roomCode)
            isLoading = false
            if roomExists {
                //chama o coordinator se a sala existir
                return AnyView(coordinator.showLiveStream(roomCode: roomCode, serverUrl: serverUrl))
            } else {
                alertMessage = "Sala não encontrada"
            }
        } catch {
            alertMessage = "Erro de conexão com o servidor"
        }
        isLoading = false
        return nil
    }
}
