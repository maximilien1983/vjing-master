import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'session.dart';
import 'theme/vj_tokens.dart';
import 'ui/screens/console_screen.dart';
import 'ui/screens/local_screen.dart';
import 'ui/screens/sources_screen.dart';
import 'ui/screens/start_screen.dart';

/// Préviz : ouvre directement un écran donné pour la comparaison aux
/// maquettes. flutter run --dart-define=SCREEN=console|local|sources
const _startScreen = String.fromEnvironment('SCREEN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await WakelockPlus.enable();
  runApp(VjingMasterApp(session: Session()));
}

class VjingMasterApp extends StatelessWidget {
  final Session session;
  const VjingMasterApp({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VJing Master',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: VjColors.ground,
        fontFamily: 'Barlow Condensed',
      ),
      home: switch (_startScreen) {
        'console' => ConsoleScreen(session: session),
        'local' => LocalScreen(session: session),
        'sources' => SourcesScreen(session: session),
        _ => StartScreen(session: session),
      },
    );
  }
}
