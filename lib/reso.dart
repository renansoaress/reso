import 'dart:convert';

import 'package:crypto/crypto.dart';

const _symbols = ['!', '@', '#', '\$', '%', '&', '*', '+', '-'];
const _alphabet = 'abcdefghijklmnopqrstuvwxyz';
const _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// Gera o ReSo de [text], combinado com [key] quando ela nao e vazia.
///
/// Sempre o mesmo resultado para a mesma entrada: qualquer mudanca aqui troca
/// as senhas de quem ja usa o app (o test/reso_test.dart trava isso).
String reso(String text, {String key = ''}) {
  if (text.isEmpty) return '';

  final digest = md5.convert(utf8.encode(text));
  final hashStr = key.isEmpty
      ? digest.toString()
      : md5.convert(md5.convert(utf8.encode(key)).bytes + digest.bytes).toString();

  int code(int fromEnd) => hashStr.codeUnitAt(hashStr.length - fromEnd);

  final symbolInitial = _symbols[code(1) % _symbols.length];
  final symbolFinal = _symbols[code(2) % _symbols.length];
  final upperInitial = _upper[code(3) % _alphabet.length];
  final upperFinal = _upper[code(4) % _alphabet.length];
  final lowerInitial = _alphabet[code(5) % _alphabet.length];
  final lowerFinal = _alphabet[code(6) % _alphabet.length];

  final result = hashStr.substring(0, 12).split('');
  final length = result.length;

  // Cada caractere novo vai para uma posicao livre. A ultima posicao nao entra
  // no conjunto, exatamente como na primeira versao do app.
  final positions = <int>{code(1) % length};
  int free(int position) {
    while (positions.contains(position)) {
      position = (position + 1) % length;
    }
    return position;
  }

  final posSymbolInitial = code(1) % length;
  final posSymbolFinal = free(code(2) % length);
  positions.add(posSymbolFinal);
  final posUpperInitial = free(code(3) % length);
  positions.add(posUpperInitial);
  final posUpperFinal = free(code(4) % length);
  positions.add(posUpperFinal);
  final posLowerInitial = free(code(5) % length);
  positions.add(posLowerInitial);
  final posLowerFinal = free(code(6) % length);

  result[posSymbolInitial] = symbolInitial;
  result[posSymbolFinal] = symbolFinal;
  result[posUpperInitial] = upperInitial;
  result[posUpperFinal] = upperFinal;
  result[posLowerInitial] = lowerInitial;
  result[posLowerFinal] = lowerFinal;

  return result.join();
}
