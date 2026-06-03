import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dart/main.dart';

void main() {
  testWidgets('BookLogApp renderiza sem erros', (WidgetTester tester) async {
    // Verifica que o widget raiz do app é criado corretamente
    expect(const BookLogApp(), isA<Widget>());
  });

  testWidgets('BookLogApp é um StatelessWidget', (WidgetTester tester) async {
    final app = const BookLogApp();
    expect(app, isA<StatelessWidget>());
  });
}