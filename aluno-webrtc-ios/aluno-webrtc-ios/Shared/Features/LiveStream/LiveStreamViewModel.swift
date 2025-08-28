//
//  LiveStreamViewModel.swift
//  aluno-webrtc-ios
//
//  Created by Isequiel Henrique do Nascimento on 28/08/25.
//

import SwiftUI

@MainActor
class LiveStreamViewModel: ObservableObject {
    @Published var webRTCService = WebRTCService()
    @Published var errorMessage = ""
    
    let roomCode: String
    let serverUrl: String
    
    init(roomCode: String, serverUrl: String) {
        self.roomCode = roomCode
        self.serverUrl = serverUrl
    }
    
    //Conecta a sala chamando o WebRTC
    func connect() async {
        await webRTCService.joinRoom(serverUrl: serverUrl, roomCode: roomCode)
    }
}
