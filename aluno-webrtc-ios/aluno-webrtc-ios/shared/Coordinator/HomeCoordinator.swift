//
//  aluno_webrtc_iosApp.swift
//  aluno-webrtc-ios
//
//  Created by Isequiel Henrique do Nascimento on 23/08/25.
//


import SwiftUI

class HomeCoordinator {
    private let parent: AppCoordinator
    
    init(parent: AppCoordinator) {
        self.parent = parent
    }
    
    //Mostra a homeview como a tela principal
    func start() -> some View {
        let viewModel = HomeViewModel(coordinator: self)
        return HomeView(viewModel: viewModel)
    }
    
    //navega para LiveStreamView se a sala existir
    func showLiveStream(roomCode: String, serverUrl: String) -> some View {
        let viewModel = LiveStreamViewModel(roomCode: roomCode, serverUrl: serverUrl)
        return LiveStreamView(viewModel: viewModel)
    }
}
