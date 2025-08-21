import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/webrtc_service.dart';
import 'live_stream_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomCodeController = TextEditingController();
  final _serverUrlController = TextEditingController(
    text: 'http://xxx.xxx.xx.xxx:3000',
  );
  bool _isLoading = false;

  @override
  void dispose() {
    _roomCodeController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _joinClass() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final roomCode = _roomCodeController.text.trim();
      final serverUrl = _serverUrlController.text.trim();
      final webRTCService = WebRTCService();

      if (!await webRTCService.checkRoomExists(serverUrl, roomCode)) {
        _showDialog('Sala não encontrada',
            'O código "$roomCode" não foi encontrado. Verifique e tente novamente.');
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveStreamScreen(
              roomCode: roomCode,
              serverUrl: serverUrl,
            ),
          ),
        );
      }
    } catch (_) {
      _showDialog('Erro de Conexão',
          'Não foi possível conectar. Verifique sua internet e a URL do servidor.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDialog(String title, String message) => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) _roomCodeController.text = data!.text!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                _header(),
                const Spacer(),
                _form(),
                const Spacer(),
                _instructions(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          children: [
            Icon(Icons.school, size: 64, color: Colors.white),
            SizedBox(height: 16),
            Text('Aulas ao Vivo',
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            SizedBox(height: 8),
            Text('Conecte-se à sua aula',
                style: TextStyle(fontSize: 16, color: Colors.white70)),
          ],
        ),
      );

  Widget _form() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text('Entrar na Aula',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50))),
              const SizedBox(height: 24),
              _roomCodeField(),
              const SizedBox(height: 16),
              _serverUrlField(),
              const SizedBox(height: 24),
              _joinButton(),
            ],
          ),
        ),
      );

  Widget _roomCodeField() => TextFormField(
        controller: _roomCodeController,
        decoration: InputDecoration(
          labelText: 'Código da Aula',
          hintText: 'Digite o código de 6 dígitos',
          prefixIcon: const Icon(Icons.vpn_key),
          suffixIcon: IconButton(
            icon: const Icon(Icons.paste),
            onPressed: _pasteFromClipboard,
          ),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        validator: (v) {
          if (v == null || v.isEmpty) return 'Digite o código da aula';
          if (v.length != 6) return 'O código deve ter 6 dígitos';
          return null;
        },
      );

  Widget _serverUrlField() => TextFormField(
        controller: _serverUrlController,
        decoration: const InputDecoration(
          labelText: 'URL do Servidor',
          hintText: 'http://192.168.1.100:3000',
          prefixIcon: Icon(Icons.dns),
        ),
        keyboardType: TextInputType.url,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Digite a URL do servidor';
          if (!v.startsWith('http://') && !v.startsWith('https://')) {
            return 'URL deve começar com http:// ou https://';
          }
          return null;
        },
      );

  Widget _joinButton() => ElevatedButton(
        onPressed: _isLoading ? null : _joinClass,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF667EEA),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_call),
                  SizedBox(width: 8),
                  Text('Entrar na Aula',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
      );

  Widget _instructions() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          children: [
            Icon(Icons.info_outline, color: Colors.white70, size: 20),
            SizedBox(height: 8),
            Text(
              'Solicite o código da aula ao seu professor',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
