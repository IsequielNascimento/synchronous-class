import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;

class WebRTCService {
  IO.Socket? _socket;
  RTCPeerConnection? _peerConnection;
  
  // Callbacks
  Function(RTCPeerConnectionState)? onConnectionStateChanged;
  Function(MediaStream)? onRemoteStream;
  Function()? onStreamEnded;
  Function()? onTeacherDisconnected;
  Function(String)? onError;

  // Configuração ICE servers
final Map<String, dynamic> _iceServers = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {
      'urls': 'turn:meu-turn-server.com:3478',
      'username': 'usuario',
      'credential': 'senha'
    }
  ]
};


  Future<bool> checkRoomExists(String serverUrl, String roomCode) async {
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/room/$roomCode'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['exists'] == true;
      }
      return false;
    } catch (e) {
      throw Exception('Erro ao verificar sala: $e');
    }
  }

  Future<void> joinRoom(String serverUrl, String roomCode) async {
    try {
      // Conectar ao servidor WebSocket
      _socket = IO.io(serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });

      _setupSocketListeners(roomCode);
      _socket!.connect();

      // Aguardar conexão
      await Future.delayed(const Duration(seconds: 2));
      
      if (!_socket!.connected) {
        throw Exception('Não foi possível conectar ao servidor');
      }

      // Entrar na sala 
      _socket!.emit('student-join', {'roomCode': roomCode});

    } catch (e) {
      onError?.call('Erro ao entrar na sala: $e');
    }
  }

  void _setupSocketListeners(String roomCode) {
    _socket!.on('connect', (_) {
      print('Conectado ao servidor WebSocket');
    });

    _socket!.on('disconnect', (_) {
      print('Desconectado do servidor WebSocket');
      onError?.call('Conexão perdida com o servidor');
    });

    _socket!.on('joined-room', (data) {
      print('Entrou na sala: ${data['roomCode']}');
    });

    _socket!.on('stream-started', (_) {
      print('Transmissão iniciada pelo professor');
      // A oferta será recebida em seguida
    });

    _socket!.on('stream-stopped', (_) {
      print('Transmissão encerrada pelo professor');
      onStreamEnded?.call();
      _closePeerConnection();
    });

    _socket!.on('teacher-disconnected', (_) {
      print('Professor desconectado');
      onTeacherDisconnected?.call();
      _closePeerConnection();
    });

    _socket!.on('offer', (data) async {
      print('Oferta recebida do professor');
      await _handleOffer(data['offer'], data['senderId']);
    });

    _socket!.on('ice-candidate', (data) async {
      print('Candidato ICE recebido');
      await _handleIceCandidate(data['candidate']);
    });

    _socket!.on('error', (data) {
      print('Erro do servidor: ${data['message']}');
      onError?.call(data['message']);
    });
  }

  Future<void> _handleOffer(Map<String, dynamic> offer, String senderId) async {
    try {
      // Criar peer connection se não existir
      if (_peerConnection == null) {
        await _createPeerConnection();
      }

      // Definir descrição remota
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );

      // Criar resposta
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Enviar resposta
      _socket!.emit('answer', {
        'answer': answer.toMap(),
        'targetId': senderId,
      });

      print('Resposta enviada para o professor');

    } catch (e) {
      print('Erro ao processar oferta: $e');
      onError?.call('Erro ao processar oferta do professor');
    }
  }

  Future<void> _handleIceCandidate(Map<String, dynamic>? candidate) async {
    if (_peerConnection != null && candidate != null) {
      try {
        await _peerConnection!.addCandidate(
          RTCIceCandidate(
            candidate['candidate'],
            candidate['sdpMid'],
            candidate['sdpMLineIndex'],
          ),
        );
      } catch (e) {
        print('Erro ao adicionar candidato ICE: $e');
      }
    }
  }

  Future<void> _createPeerConnection() async {
    try {
      _peerConnection = await createPeerConnection(_iceServers);

      // Configurar eventos
      _peerConnection!.onConnectionState = (state) {
        print('Estado da conexão: $state');
        onConnectionStateChanged?.call(state);
      };

      _peerConnection!.onAddStream = (stream) {
        print('Stream remoto recebido');
        onRemoteStream?.call(stream);
      };

      _peerConnection!.onIceCandidate = (candidate) {
        print('Candidato ICE local gerado');
        _socket!.emit('ice-candidate', {
          'candidate': candidate.toMap(),
          'targetId': null, // Enviar para o professor
        });
      };

      _peerConnection!.onIceConnectionState = (state) {
        print('Estado da conexão ICE: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
            state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
          onError?.call('Conexão perdida com o professor');
        }
      };

    } catch (e) {
      print('Erro ao criar peer connection: $e');
      onError?.call('Erro ao estabelecer conexão WebRTC');
    }
  }

  void _closePeerConnection() {
    _peerConnection?.close();
    _peerConnection = null;
  }

  void dispose() {
    _closePeerConnection();
    _socket?.disconnect();
    _socket?.dispose();
  }
}

