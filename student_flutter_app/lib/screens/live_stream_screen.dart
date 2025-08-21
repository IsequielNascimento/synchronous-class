import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_service.dart';

class LiveStreamScreen extends StatefulWidget {
  final String roomCode;
  final String serverUrl;

  const LiveStreamScreen({
    super.key,
    required this.roomCode,
    required this.serverUrl,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  late WebRTCService _webRTCService;
  RTCVideoRenderer? _remoteRenderer;
  bool _isConnected = false;
  bool _isStreamActive = false;
  String _connectionStatus = 'Conectando...';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeWebRTC();
  }

  @override
  void dispose() {
    _webRTCService.dispose();
    _remoteRenderer?.dispose();
    super.dispose();
  }

  Future<void> _initializeWebRTC() async {
    try {
      _webRTCService = WebRTCService();
      
      // Configurar callbacks
      _webRTCService.onConnectionStateChanged = (state) {
        if (mounted) {
          setState(() {
            _connectionStatus = _getConnectionStatusText(state);
            _isConnected = state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
          });
        }
      };

      _webRTCService.onRemoteStream = (stream) async {
        if (mounted) {
          _remoteRenderer = RTCVideoRenderer();
          await _remoteRenderer!.initialize();
          _remoteRenderer!.srcObject = stream;
          setState(() {
            _isStreamActive = true;
          });
        }
      };

      _webRTCService.onStreamEnded = () {
        if (mounted) {
          setState(() {
            _isStreamActive = false;
            _connectionStatus = 'Transmissão encerrada';
          });
        }
      };

      _webRTCService.onError = (error) {
        if (mounted) {
          setState(() {
            _errorMessage = error;
            _connectionStatus = 'Erro de conexão';
          });
        }
      };

      _webRTCService.onTeacherDisconnected = () {
        if (mounted) {
          _showTeacherDisconnectedDialog();
        }
      };

      // Conectar à sala
      await _webRTCService.joinRoom(widget.serverUrl, widget.roomCode);
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao conectar: $e';
          _connectionStatus = 'Erro de conexão';
        });
      }
    }
  }

  String _getConnectionStatusText(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateNew:
        return 'Iniciando conexão...';
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        return 'Conectando...';
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        return 'Conectado';
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        return 'Desconectado';
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        return 'Falha na conexão';
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        return 'Conexão fechada';
      default:
        return 'Status desconhecido';
    }
  }

  void _showTeacherDisconnectedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Aula Encerrada'),
        content: const Text('O professor encerrou a aula ou se desconectou.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Fechar dialog
              Navigator.of(context).pop(); // Voltar para tela inicial
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _exitClass() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da Aula'),
        content: const Text('Tem certeza que deseja sair da aula?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Fechar dialog
              Navigator.of(context).pop(); // Voltar para tela inicial
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sala ${widget.roomCode}'),
            Text(
              _connectionStatus,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _exitClass,
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Sair da aula',
          ),
        ],
      ),
      body: Column(
        children: [
          // Área do vídeo
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: _buildVideoContent(),
            ),
          ),
          
          // Barra de status
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade900,
            child: Row(
              children: [
                // Indicador de conexão
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _connectionStatus,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                
                // Indicador de transmissão
                if (_isStreamActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'AO VIVO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoContent() {
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Erro de Conexão',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = '';
                });
                _initializeWebRTC();
              },
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      );
    }

    if (!_isStreamActive) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 24),
            Text(
              'Aguardando transmissão...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'O professor ainda não iniciou a transmissão',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_remoteRenderer == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return RTCVideoView(
      _remoteRenderer!,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    );
  }
}

