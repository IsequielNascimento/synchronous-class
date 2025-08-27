//
//  aluno_webrtc_iosApp.swift
//  aluno-webrtc-ios
//
//  Created by Isequiel Henrique do Nascimento on 23/08/25.
//

import SwiftUI

class AppCoordinator: ObservableObject {
    @Published var currentView: AnyView?
    
    init() {
        start()
    }
    
    func start() -> some View {
        let homeCoordinator = HomeCoordinator(parent: self)
        return homeCoordinator.start()
    }
}
