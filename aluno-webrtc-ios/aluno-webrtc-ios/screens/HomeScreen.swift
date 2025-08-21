//
//  HomeScreen.swift
//  aluno-webrtc-ios
//
//  Created by Isequiel Henrique do Nascimento on 20/08/25.
//


import SwiftUI
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}
struct HomeScreen: View {
    @State private var roomCode: String = ""
    @State private var serverUrl: String = "http://10.200.201.199:3000" //endereço do server
    @State private var isLoading: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

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

                // Formulário
                VStack(spacing: 16) {
                    Text("Entrar na Aula")
                        .font(.title2).bold().foregroundColor(Color.black)

                    TextField("Código da Aula (6 dígitos)", text: $roomCode)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    TextField("URL do Servidor", text: $serverUrl)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button(action: joinClass) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Label("Entrar na Aula", systemImage: "video.fill")
                                .bold()
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

                // Instruções
                VStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.white.opacity(0.7))
                    Text("Solicite o código da aula ao seu professor")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)

                Spacer().frame(height: 20)
            }
            .padding()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Erro"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func joinClass() {
        guard roomCode.count == 6 else {
            alertMessage = "O código deve ter 6 dígitos"
            showAlert = true
            return
        }

        isLoading = true

        Task {
            let service = WebRTCService()
            do {
                let roomExists = try await WebRTCService.checkRoomExists(serverUrl: serverUrl, roomCode: roomCode)
                if roomExists {
                    isLoading = false
                    // Navega para LiveStream
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController = UIHostingController(rootView: LiveStreamScreen(roomCode: roomCode, serverUrl: serverUrl))
                        window.makeKeyAndVisible()
                    }
                } else {
                    alertMessage = "Sala não encontrada"
                    showAlert = true
                }
            } catch {
                alertMessage = "Erro de conexão com o servidor"
                showAlert = true
            }
            isLoading = false
        }
    }
}
