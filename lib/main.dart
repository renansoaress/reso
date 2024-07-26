// lib/main.dart

// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'themes.dart'; // Importe o arquivo de temas

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
  String _hash = '';

  final symbols = const ["!", "@", "#", "\$", "%", "&", "*", "+", "-"];
  final alphabet = "abcdefghijklmnopqrstuvwxyz";

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateHash);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateHash);
    _controller.dispose();
    super.dispose();
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

      while (positions.contains(positionMyLowerInitial)) {
        positionMyLowerInitial = (positionMyLowerInitial + 1) % length;
      }

      while (positions.contains(positionMyLowerFinal)) {
        positionMyLowerFinal = (positionMyLowerFinal + 1) % length;
      }

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
      body: Center(
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
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
                                    fontFamily: 'Courier New', // Fonte para 'e'
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
                    decoration: const InputDecoration(
                      labelText: 'Digite o texto',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_hash.isNotEmpty)
                    Card(
                      elevation: 4, // Define a elevação do Card
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
                                    fontSize: 16, fontWeight: FontWeight.bold),
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
            )),
      ),
    );
  }
}
