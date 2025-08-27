//
//  aluno_webrtc_iosApp.swift
//  aluno-webrtc-ios
//
//  Created by Isequiel Henrique do Nascimento on 20/08/25.
//

import SwiftUI

@main
struct aluno_webrtc_iosApp: App {
    @StateObject private var coordinator = AppCoordinator()
    
    var body: some Scene {
        WindowGroup {
            coordinator.start()
        }
    }
}
