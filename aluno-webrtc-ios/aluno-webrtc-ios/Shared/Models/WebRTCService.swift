//
//  WebRTCService.swift
//  aluno-webrtc-ios
//
//  Created by Isequiel Henrique do Nascimento on 20/08/25.
//
// WebRTCService.swift

import Foundation
import WebRTC
import SocketIO

@MainActor
class WebRTCService: NSObject, ObservableObject {
    
    private var socket: SocketIOClient?
    private var manager: SocketManager?
    private var peerConnection: RTCPeerConnection?
    private var teacherSocketId: String?
    
    // Mude de RTCMTLVideoView? para RTCVideoTrack?
    @Published var remoteVideoTrack: RTCVideoTrack?

    private let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
    }()


    static func checkRoomExists(serverUrl: String, roomCode: String) async throws -> Bool {
         guard let url = URL(string: "\(serverUrl)/room/\(roomCode)") else {
             throw URLError(.badURL)
         }
         
         let (data, response) = try await URLSession.shared.data(from: url)
         
         guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
             throw URLError(.badServerResponse )
         }
         
         guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let exists = json["exists"] as? Bool else {
             throw URLError(.cannotParseResponse)
         }
         
         return exists
     }

    func joinRoom(serverUrl: String, roomCode: String) {
        manager = SocketManager(socketURL: URL(string: serverUrl)!, config: [.log(true), .compress])
        socket = manager?.defaultSocket

        setupSocketListeners(roomCode: roomCode)
        socket?.connect()
    }
    
    private func setupSocketListeners(roomCode: String) {
        socket?.on(clientEvent: .connect) { [weak self] _, _ in
           // print("Conectado no servidor socket")
            self?.socket?.emit("student-join", ["roomCode": roomCode])
        }

        // Recebendo a offer do professor
        socket?.on("offer") { [weak self] data, _ in
            guard let self = self,
                  let dict = data.first as? [String: Any],
                  let offerDict = dict["offer"] as? [String: Any],
                  let sdp = offerDict["sdp"] as? String,
                  let senderId = dict["senderId"] as? String else { return }

            //  print("Oferta recebida do professor: \(senderId)")

            // Salva o ID do professor para enviar a resposta e os candidatos ICE de volta
            self.teacherSocketId = senderId
            
            Task {
                await self.handleOffer(sdp: sdp)
            }
        }

        // Recebendo candidatos ICE do professor
        socket?.on("ice-candidate") { [weak self] data, _ in
            guard let self = self,
                  let dict = data.first as? [String: Any],
                  let candidateDict = dict["candidate"] as? [String: Any],
                  let candidateSdp = candidateDict["candidate"] as? String,
                  let sdpMid = candidateDict["sdpMid"] as? String,
                  let sdpMLineIndex = candidateDict["sdpMLineIndex"] as? Int32 else {
               // print("Erro ao decodificar candidato ICE recebido")
                return
            }
            
            print("📬 Candidato ICE recebido")
            let iceCandidate = RTCIceCandidate(sdp: candidateSdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
            
            Task {
                do {
                    try await self.peerConnection?.add(iceCandidate)
                } catch {
                    print("❌ Erro ao adicionar candidato ICE recebido: \(error)")
                }
            }
        }
        
    }
    
    private func createPeerConnection() async throws {
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        
        guard let pc = factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
            throw NSError(domain: "WebRTCService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Falha ao criar PeerConnection"])
        }
        self.peerConnection = pc
    }

    private func handleOffer(sdp: String) async {
        do {

            // 1. Criar a PeerConnection se ainda não existir
            if peerConnection == nil {
                try await createPeerConnection()
            }
            
            // 2. Definir a oferta recebida como descrição remota
            let remoteDescription = RTCSessionDescription(type: .offer, sdp: sdp)
            try await peerConnection?.setRemoteDescription(remoteDescription)
        //    print(" Descrição remota (oferta) definida.")

            // 3. Criar uma resposta (answer)
            let constraints = RTCMediaConstraints(mandatoryConstraints: [
                "OfferToReceiveAudio": "false",
                "OfferToReceiveVideo": "true"
            ], optionalConstraints: nil)
            let answer = try await peerConnection?.answer(for: constraints)
            
            // 4. Definir a resposta como descrição local
            guard let answer = answer else { return }
            try await peerConnection?.setLocalDescription(answer)
        //    print(" Descrição local (resposta) definida.")

            // 5. Enviar a resposta de volta para o professor
            guard let teacherId = self.teacherSocketId else { return }
            let answerSdp = ["sdp": answer.sdp, "type": "answer"]
            socket?.emit("answer", ["answer": answerSdp, "targetId": teacherId])
        //   print(" Resposta enviada para o professor \(teacherId)")

        } catch {
        //    print(" Erro no processamento da offer: \(error)")
        }
    }
}

extension WebRTCService: RTCPeerConnectionDelegate {

    // cahamada quando um candidato ICE local é gerado.
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        guard let teacherId = self.teacherSocketId else {
    //        print(" Candidato ICE gerado, mas o ID do professor não está disponível.")
            return
        }
        
        let candidateData: [String: Any] = [
            "candidate": candidate.sdp,
            "sdpMid": candidate.sdpMid ?? "",
            "sdpMLineIndex": candidate.sdpMLineIndex
        ]
        
        // Envia o candidato local para o servidor, direcionado ao professor
        socket?.emit("ice-candidate", [
            "candidate": candidateData,
            "targetId": teacherId
        ])
    
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("📺 Stream remoto recebido com \(stream.videoTracks.count) vídeos e \(stream.audioTracks.count) áudios")
        if let track = stream.videoTracks.first {
            // Publica o RTCVideoTrack para a View
            DispatchQueue.main.async {
                self.remoteVideoTrack = track
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
    }

    // Funções de delegate
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
