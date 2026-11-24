import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vjing_master/ui/screens/splash_screen.dart';

void main() {
  testWidgets('splash : wordmark gravé + sous-titre, puis écran suivant',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SplashScreen(
        holdFor: const Duration(milliseconds: 300),
        next: (_) => const Scaffold(body: Text('SUIVANT')),
      ),
    ));
    expect(find.text('VJing Master'), findsOneWidget);
    expect(find.text('VIDEO MIX APP FOR COOL KIDS'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350)); // échéance du timer
    await tester.pumpAndSettle(); // fondu vers l'écran suivant
    expect(find.text('SUIVANT'), findsOneWidget);
  });

  testWidgets('splash : un tap presse la sortie', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SplashScreen(
        holdFor: const Duration(seconds: 30), // le timer ne jouera pas
        next: (_) => const Scaffold(body: Text('SUIVANT')),
      ),
    ));
    await tester.tap(find.text('VJing Master'));
    await tester.pumpAndSettle();
    expect(find.text('SUIVANT'), findsOneWidget);
  });
}
