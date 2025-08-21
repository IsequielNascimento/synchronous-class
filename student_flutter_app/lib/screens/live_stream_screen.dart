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
  late final WebRTCService _webRTCService;
  RTCVideoRenderer? _remoteRenderer;

  bool _isConnected = false;
  bool _isStreamActive = false;
  String _status = 'Conectando...';
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupWebRTC();
  }

  @override
  void dispose() {
    _webRTCService.dispose();
    _remoteRenderer?.dispose();
    super.dispose();
  }

  Future<void> _setupWebRTC() async {
    _webRTCService = WebRTCService();

    _webRTCService
      ..onConnectionStateChanged = (s) {
        _updateState(
          status: _statusText(s),
          connected: s ==
              RTCPeerConnectionState.RTCPeerConnectionStateConnected,
        );
      }
      ..onRemoteStream = (stream) async {
        _remoteRenderer = RTCVideoRenderer();
        await _remoteRenderer!.initialize();
        _remoteRenderer!.srcObject = stream;
        _updateState(streamActive: true);
      }
      ..onStreamEnded = () {
        _updateState(
          streamActive: false,
          status: 'Transmissão encerrada',
        );
      }
      ..onError = (err) {
        _updateState(
          error: err,
          status: 'Erro de conexão',
        );
      }
      ..onTeacherDisconnected = _showTeacherDisconnectedDialog;

    try {
      await _webRTCService.joinRoom(widget.serverUrl, widget.roomCode);
    } catch (e) {
      _updateState(error: 'Erro ao conectar: $e', status: 'Erro de conexão');
    }
  }

  void _updateState({
    String? status,
    bool? connected,
    bool? streamActive,
    String? error,
  }) {
    if (!mounted) return;
    setState(() {
      _status = status ?? _status;
      _isConnected = connected ?? _isConnected;
      _isStreamActive = streamActive ?? _isStreamActive;
      _error = error;
    });
  }

  String _statusText(RTCPeerConnectionState s) => switch (s) {
        RTCPeerConnectionState.RTCPeerConnectionStateNew =>
          'Iniciando conexão...',
        RTCPeerConnectionState.RTCPeerConnectionStateConnecting =>
          'Conectando...',
        RTCPeerConnectionState.RTCPeerConnectionStateConnected => 'Conectado',
        RTCPeerConnectionState.RTCPeerConnectionStateDisconnected =>
          'Desconectado',
        RTCPeerConnectionState.RTCPeerConnectionStateFailed =>
          'Falha na conexão',
        RTCPeerConnectionState.RTCPeerConnectionStateClosed =>
          'Conexão fechada',
        _ => 'Status desconhecido',
      };

  void _showTeacherDisconnectedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Aula Encerrada'),
        content:
            const Text('O professor encerrou a aula ou se desconectou.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair da Aula'),
        content: const Text('Tem certeza que deseja sair da aula?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
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
            Text(_status, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _confirmExit,
            icon: const Icon(Icons.exit_to_app),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildVideo()),
          _buildStatusBar(),
        ],
      ),
    );
  }

  Widget _buildVideo() {
    if (_error != null) {
      return _errorView();
    }
    if (!_isStreamActive) {
      return _waitingView();
    }
    if (_remoteRenderer == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return RTCVideoView(
      _remoteRenderer!,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    );
  }

  Widget _errorView() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Erro de Conexão',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _setupWebRTC(),
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      );

  Widget _waitingView() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 24),
            Text(
              'Aguardando transmissão...',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'O professor ainda não iniciou a transmissão',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );

  Widget _buildStatusBar() => Container(
        padding: const EdgeInsets.all(16),
        color: Colors.grey.shade900,
        child: Row(
          children: [
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
                _status,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (_isStreamActive)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'AO VIVO',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      );
}
