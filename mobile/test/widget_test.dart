import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:padel_mobile/features/auth/login_screen.dart';

void main() {
  testWidgets('L\'écran de connexion affiche ses champs', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Email ou téléphone'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
  });
}
