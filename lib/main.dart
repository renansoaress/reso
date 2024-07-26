import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'themes.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReSo',
      // theme: ThemeData.light(), // Define o tema claro
      // darkTheme: ThemeData.dark(), // Define o tema escuro
      theme: lightTheme, // Use o tema claro importado
      darkTheme: darkTheme, // Use o tema escuro importado
      themeMode: ThemeMode
          .system, // Define o modo de tema com base nas preferências do sistema
      home: const HashPage(),
    );
  }
}

class HashPage extends StatefulWidget {
  const HashPage({super.key});

  @override
  _HashPageState createState() => _HashPageState();
}

class _HashPageState extends State<HashPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _hash = '';
  bool _obscureText =
      true; // Adiciona uma variável para gerenciar a visibilidade do texto

  final symbols = const ["!", "@", "#", "\$", "%", "&", "*", "+", "-"];
  final alphabet = "abcdefghijklmnopqrstuvwxyz";
  final String _version = '1.0.0'; // Defina a versão atual do software

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateHash);

    // Solicite o foco após a construção do widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });

    // Carregar o estado do botão de visualizar
    _loadPreferences();
  }

  @override
  void dispose() {
    _controller.removeListener(_updateHash);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _obscureText = prefs.getBool('obscureText') ??
          true; // Carrega o estado salvo ou usa true por padrão
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('obscureText', _obscureText); // Salva o estado atual
  }

  void _updateHash() {
    final input = _controller.text;
    if (input.isEmpty) {
      setState(() {
        _hash = '';
      });
    } else {
      final bytes = utf8.encode(input); // Converte o input em bytes
      final digest = md5.convert(bytes); // Gera o hash MD5
      String hashStr = digest.toString();
      String mySymbolInitial =
          symbols[hashStr.codeUnitAt(hashStr.length - 1) % symbols.length];
      String mySymbolFinal =
          symbols[hashStr.codeUnitAt(hashStr.length - 2) % symbols.length];
      String myUpperInitial = alphabet.toUpperCase()[
          hashStr.codeUnitAt(hashStr.length - 3) % alphabet.length];
      String myUpperFinal = alphabet.toUpperCase()[
          hashStr.codeUnitAt(hashStr.length - 4) % alphabet.length];
      String myLowerInitial =
          alphabet[hashStr.codeUnitAt(hashStr.length - 5) % alphabet.length];
      String myLowerFinal =
          alphabet[hashStr.codeUnitAt(hashStr.length - 6) % alphabet.length];
      String result = hashStr.substring(0, 12);

      int length = result.length;

      int positionSymbolInitial =
          hashStr.codeUnitAt(hashStr.length - 1) % length;
      int positionSymbolFinal = hashStr.codeUnitAt(hashStr.length - 2) % length;
      int positionMyUpperInitial =
          hashStr.codeUnitAt(hashStr.length - 3) % length;
      int positionMyUpperFinal =
          hashStr.codeUnitAt(hashStr.length - 4) % length;
      int positionMyLowerInitial =
          hashStr.codeUnitAt(hashStr.length - 5) % length;
      int positionMyLowerFinal =
          hashStr.codeUnitAt(hashStr.length - 6) % length;

      Set<int> positions = {positionSymbolInitial};
      while (positions.contains(positionSymbolFinal)) {
        positionSymbolFinal = (positionSymbolFinal + 1) % length;
      }
      positions.add(positionSymbolFinal);

      while (positions.contains(positionMyUpperInitial)) {
        positionMyUpperInitial = (positionMyUpperInitial + 1) % length;
      }
      positions.add(positionMyUpperInitial);

      while (positions.contains(positionMyUpperFinal)) {
        positionMyUpperFinal = (positionMyUpperFinal + 1) % length;
      }
      positions.add(positionMyUpperFinal);

      while (positions.contains(positionMyLowerInitial)) {
        positionMyLowerInitial = (positionMyLowerInitial + 1) % length;
      }
      positions.add(positionMyLowerInitial);

      while (positions.contains(positionMyLowerFinal)) {
        positionMyLowerFinal = (positionMyLowerFinal + 1) % length;
      }
      // positions.add(positionMyLowerFinal);

      List<String> resultList = result.split('');

      resultList[positionSymbolInitial] = mySymbolInitial;
      resultList[positionSymbolFinal] = mySymbolFinal;
      resultList[positionMyUpperInitial] = myUpperInitial;
      resultList[positionMyUpperFinal] = myUpperFinal;
      resultList[positionMyLowerInitial] = myLowerInitial;
      resultList[positionMyLowerFinal] = myLowerFinal;

      result = resultList.join('');

      setState(() {
        _hash = result;
      });
    }
  }

  void _toggleObscureText() {
    setState(() {
      _obscureText = !_obscureText; // Alterna a visibilidade do texto
      _savePreferences(); // Salva o estado ao alternar
    });
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _hash));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('ReSo copiado para a área de transferência!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Label com fontes diferentes para cada letra
                            RichText(
                              text: const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'R',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 60,
                                      fontFamily: 'Arial', // Fonte para 'R'
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'e',
                                    style: TextStyle(
                                      fontSize: 60,
                                      fontFamily:
                                          'Courier New', // Fonte para 'e'
                                      color: Colors.green,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'S',
                                    style: TextStyle(
                                      fontSize: 60,
                                      fontFamily:
                                          'Times New Roman', // Fonte para 'S'
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'o',
                                    style: TextStyle(
                                      fontSize: 60,
                                      fontFamily: 'Helvetica', // Fonte para 'o'
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      obscureText:
                          _obscureText, // Define se o texto deve ser oculto
                      decoration: InputDecoration(
                        labelText: 'Digite o texto :)',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: _toggleObscureText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_hash.isNotEmpty)
                      Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: SelectableText(
                                  _hash,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: _copyToClipboard,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Versão: $_version',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
