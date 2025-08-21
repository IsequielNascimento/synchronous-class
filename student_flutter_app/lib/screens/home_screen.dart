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
    text: 'http://xxx.xxx.xx.xxx:3000', // Alterar para o IP do servidor
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

    setState(() {
      _isLoading = true;
    });

    try {
      final roomCode = _roomCodeController.text.trim();
      final serverUrl = _serverUrlController.text.trim();

      // Verificar se a sala existe
      final webRTCService = WebRTCService();
      final roomExists = await webRTCService.checkRoomExists(serverUrl, roomCode);

      if (!roomExists) {
        if (mounted) {
          _showErrorDialog('Sala não encontrada', 
              'O código da aula "$roomCode" não foi encontrado. Verifique se o código está correto.');
        }
        return;
      }

      // Navegar para a tela de transmissão
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => LiveStreamScreen(
              roomCode: roomCode,
              serverUrl: serverUrl,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Erro de Conexão', 
            'Não foi possível conectar ao servidor. Verifique sua conexão com a internet e a URL do servidor.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        _roomCodeController.text = clipboardData!.text!;
      }
    } catch (e) {
      
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667EEA),
              Color(0xFF764BA2),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Header
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.school,
                        size: 64,
                        color: Colors.white,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Aulas ao Vivo',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Conecte-se à sua aula',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Formulário
                Container(
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Entrar na Aula',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Campo do código da sala
                        TextFormField(
                          controller: _roomCodeController,
                          decoration: InputDecoration(
                            labelText: 'Código da Aula',
                            hintText: 'Digite o código de 6 dígitos',
                            prefixIcon: const Icon(Icons.vpn_key),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.paste),
                              onPressed: _pasteFromClipboard,
                              tooltip: 'Colar da área de transferência',
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, digite o código da aula';
                            }
                            if (value.length != 6) {
                              return 'O código deve ter 6 dígitos';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Campo da URL do servidor
                        TextFormField(
                          controller: _serverUrlController,
                          decoration: const InputDecoration(
                            labelText: 'URL do Servidor',
                            hintText: 'http://192.168.1.100:3000',
                            prefixIcon: Icon(Icons.dns),
                          ),
                          keyboardType: TextInputType.url,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, digite a URL do servidor';
                            }
                            if (!value.startsWith('http://') && !value.startsWith('https://')) {
                              return 'URL deve começar com http:// ou https://';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Botão de entrar
                        ElevatedButton(
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
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.video_call),
                                    SizedBox(width: 8),
                                    Text(
                                      'Entrar na Aula',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Instruções
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.white70,
                        size: 20,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Solicite o código da aula ao seu professor',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

