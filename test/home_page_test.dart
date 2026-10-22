import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reso/main.dart';
import 'package:reso/reso.dart';
import 'package:reso/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Settings> _settings([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return Settings(await SharedPreferences.getInstance());
}

EditableText _editable(WidgetTester tester, int index) =>
    tester.widget<EditableText>(find.byType(EditableText).at(index));

void main() {
  testWidgets('abre com o foco no campo principal', (tester) async {
    await tester.pumpWidget(ResoApp(settings: await _settings()));
    await tester.pumpAndSettle();
    expect(_editable(tester, 0).focusNode.hasFocus, isTrue);
  });

  testWidgets('configuracoes: foco na chave e, ao fechar, de volta ao principal', (tester) async {
    await tester.pumpWidget(ResoApp(settings: await _settings()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();
    // O campo da chave e o segundo EditableText (o do dialogo).
    expect(_editable(tester, 1).focusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Configurações'), findsNothing);
    expect(_editable(tester, 0).focusNode.hasFocus, isTrue);

    // Salvando tambem volta.
    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'chave');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(_editable(tester, 0).focusNode.hasFocus, isTrue);
    expect(find.byTooltip('Configurações · chave ativa'), findsOneWidget);
  });

  testWidgets('gera o ReSo com a chave salva e copia com Enter', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });

    await tester.pumpWidget(ResoApp(settings: await _settings({'modalText': 'chave'})));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'github');
    await tester.pumpAndSettle();

    final expected = reso('github', key: 'chave');
    expect(find.text(expected, findRichText: true), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(copied, expected);
    expect(find.text('Copiado'), findsOneWidget);
    expect(_editable(tester, 0).focusNode.hasFocus, isTrue);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });

  testWidgets('salvar a chave limpa o campo principal; cancelar nao', (tester) async {
    await tester.pumpWidget(ResoApp(settings: await _settings()));
    await tester.pumpAndSettle();
    final main = find.byType(TextField).first;

    await tester.enterText(main, 'github');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(main).controller!.text, 'github');

    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'chave');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(main).controller!.text, isEmpty);
    expect(find.text(reso('github'), findRichText: true), findsNothing);
    expect(_editable(tester, 0).focusNode.hasFocus, isTrue);
  });

  testWidgets('o tema escolhido vale na hora e fica salvo', (tester) async {
    final settings = await _settings();
    await tester.pumpWidget(ResoApp(settings: settings));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();

    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('themeMode'), 'dark');
  });
}
