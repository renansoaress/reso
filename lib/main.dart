import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
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
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
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
  bool _obscureText = true;
  String _version = '0.0.0';

  bool _modalObscureText = true; // Controla o estado do campo no modal
  final TextEditingController _modalController = TextEditingController();

  final symbols = const ["!", "@", "#", "\$", "%", "&", "*", "+", "-"];
  final alphabet = "abcdefghijklmnopqrstuvwxyz";

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateHash);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.android) {
        FocusScope.of(context).requestFocus(_focusNode);
      }

      // Carregar a versão do app
      await _loadAppVersion();

      // Carregar o estado do botão de visualizar
      await _loadPreferences();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_updateHash);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _obscureText = prefs.getBool('obscureText') ?? true;
      _modalObscureText = prefs.getBool('modalObscureText') ?? true;
      _modalController.text = prefs.getString('modalText') ?? '';
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('obscureText', _obscureText);
    prefs.setBool('modalObscureText', _modalObscureText);
    prefs.setString('modalText', _modalController.text);
  }

  void _updateHash() {
    final input = _controller.text;
    final inputModal = _modalController.text;
    if (input.isEmpty) {
      setState(() {
        _hash = '';
      });
    } else {
      String hashStr = "";
      if(inputModal.isNotEmpty)
      {
        final bytesModal = utf8.encode(inputModal);
        final digestModal = md5.convert(bytesModal);

        final bytes = utf8.encode(input);
        final digest = md5.convert(bytes);

        final digestAll = md5.convert(digestModal.bytes + digest.bytes);
        hashStr = digestAll.toString();
      } else {
        final bytes = utf8.encode(input);
        final digest = md5.convert(bytes);
        hashStr = digest.toString();
      }

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
      _obscureText = !_obscureText;
      _savePreferences();
    });
  }

  void _toggleModalObscureText() {
    setState(() {
      _modalObscureText = !_modalObscureText;
    });
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _hash));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('ReSo copiado para a área de transferência!')),
    );
  }

  void _openSettingsModal(BuildContext context) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Configurações'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _modalController,
                    obscureText: _modalObscureText,
                    decoration: InputDecoration(
                      labelText: 'Digite a chave :X',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _modalObscureText
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _modalObscureText = !_modalObscureText;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                _controller.clear();
                _savePreferences(); // Salva as preferências ao fechar o modal
                Navigator.of(context).pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
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
                width: MediaQuery.of(context).size.width * 0.7,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RichText(
                              text: const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'R',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 60,
                                      fontFamily: 'Arial',
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'e',
                                    style: TextStyle(
                                      fontSize: 60,
                                      fontFamily: 'Courier New',
                                      color: Colors.green,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'S',
                                    style: TextStyle(
                                      fontSize: 60,
                                      fontFamily: 'Times New Roman',
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'o',
                                    style: TextStyle(
                                      fontSize: 60,
                                      fontFamily: 'Helvetica',
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
                      obscureText: _obscureText,
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
                      SizedBox(
                        child: Card(
                          elevation: 4,
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
                                        fontWeight: FontWeight.normal),
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
                      )
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 16.0,
            right: 16.0,
            child: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _openSettingsModal(context),
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
