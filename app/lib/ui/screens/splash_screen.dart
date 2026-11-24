import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/vj_tokens.dart';
import '../materials.dart';

/// Splashscreen (2026-11-24) : le téléphone est encore tenu à la verticale à
/// l'ouverture, donc cet écran est le seul de l'app affiché en portrait.
/// Façade alu pleine page entre deux joues noyer, wordmark gravé dans la
/// matière, sous-titre discret en Michroma (typo « robotique »). À la sortie,
/// l'app bascule en paysage et ouvre l'écran suivant.
class SplashScreen extends StatefulWidget {
  /// Écran suivant, construit au moment de la sortie (après la bascule en
  /// paysage) — injecté pour garder le splash testable sans Session.
  final WidgetBuilder next;
  final Duration holdFor;
  const SplashScreen({
    super.key,
    required this.next,
    this.holdFor = const Duration(milliseconds: 2600),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _hold;

  @override
  void initState() {
    super.initState();
    _hold = Timer(widget.holdFor, _leave);
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  void _leave() {
    if (!mounted) return;
    // Toute la suite de l'app est en paysage (décision produit) : on tourne
    // ici, en quittant le seul écran portrait. Sans await : la rotation se
    // joue pendant le fondu vers l'écran suivant.
    unawaited(SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]));
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, _, _) => widget.next(context),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final cheek = VjDims.cheekWidth;
    return Scaffold(
      backgroundColor: VjColors.ground,
      // Un tap presse le passage à l'écran de démarrage.
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _leave,
        child: Row(children: [
          SizedBox(
              width: cheek < safe.left ? safe.left : cheek,
              child: const WalnutPanel(shadowSide: -1)),
          Expanded(
            child: AluPanel(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Le wordmark se cale sur la largeur disponible
                      // (l'écran portrait est étroit entre les joues).
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: EngravedWordmark(fontSize: 52),
                      ),
                      const SizedBox(height: 16),
                      // Sous-titre volontairement très discret : gravé lui
                      // aussi, à peine plus clair que la matière. Michroma
                      // est large : une seule ligne, mise à l'échelle.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'VIDEO MIX APP FOR COOL KIDS',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontFamily: 'Michroma',
                              fontSize: 8,
                              letterSpacing: 8 * .3,
                              color: VjColors.print.withValues(alpha: .3),
                              shadows: [
                                const Shadow(
                                    offset: Offset(0, -1),
                                    color: Color(0x99000000)),
                                Shadow(
                                    offset: const Offset(0, 1),
                                    color:
                                        Colors.white.withValues(alpha: .08)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
              width: cheek < safe.right ? safe.right : cheek,
              child: const WalnutPanel(shadowSide: 1)),
        ]),
      ),
    );
  }
}
