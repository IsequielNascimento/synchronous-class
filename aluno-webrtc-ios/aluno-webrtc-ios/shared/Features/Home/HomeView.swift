//
//  HomeScreen.swift
//  aluno-webrtc-ios
//
//  Created by Isequiel Henrique do Nascimento on 20/08/25.
//

import SwiftUI

struct HomeView: View {
    @StateObject var viewModel: HomeViewModel
    @State private var navigateTo: AnyView?
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: 0x667EEA), Color(hex: 0x764BA2)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "graduationcap.fill")
                        .resizable()
                        .frame(width: 64, height: 64)
                        .foregroundColor(.white)
                    Text("Aulas ao Vivo")
                        .font(.largeTitle).bold().foregroundColor(.white)
                    Text("Conecte-se à sua aula")
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
                
                Spacer()
                
                // Form
                VStack(spacing: 16) {
                    Text("Entrar na Aula")
                        .font(.title2).bold().foregroundColor(Color.black)
                    
                    TextField("Código da Aula (6 dígitos)", text: $viewModel.roomCode)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("URL do Servidor", text: $viewModel.serverUrl)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        Task {
                            navigateTo = await viewModel.joinClass()
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Label("Entrar na Aula", systemImage: "video.fill").bold()
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: 0x667EEA))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(20)
                .shadow(radius: 10)
                
                Spacer()
            }
            .padding()
            
            if let alertMessage = viewModel.alertMessage {
                Text(alertMessage)
                    .foregroundColor(.red)
            }
            
            if let destination = navigateTo {
                destination
            }
        }
    }
}
