import 'package:flutter/material.dart';

import '../cast/cast_link.dart';
import '../session.dart';
import '../theme/vj_tokens.dart';

/// Sélecteur de TV (Chromecast ; AirPlay au jalon 5).
void showCastPicker(BuildContext context, Session session) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: VjColors.recessBottom,
      title: Text('Diffuser vers',
          style: VjText.sectionTitle.copyWith(fontSize: 14)),
      content: SizedBox(
        width: 320,
        child: StreamBuilder<List<CastRoute>>(
          stream: session.cast.routes,
          builder: (context, snap) {
            final routes = snap.data ?? const <CastRoute>[];
            if (routes.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Recherche de TV…', style: VjText.hint),
              );
            }
            return ListView(
              shrinkWrap: true,
              children: [
                for (final r in routes)
                  ListTile(
                    leading: const Icon(Icons.tv, color: VjColors.printDim),
                    title: Text(r.name,
                        style: const TextStyle(
                            fontFamily: 'Barlow Condensed',
                            color: VjColors.print)),
                    onTap: () {
                      session.cast.connect(r.id);
                      Navigator.pop(context);
                    },
                  ),
                if (session.cast.state == CastState.connected)
                  ListTile(
                    leading: const Icon(Icons.close, color: VjColors.printDim),
                    title: const Text('Arrêter la diffusion',
                        style: TextStyle(
                            fontFamily: 'Barlow Condensed',
                            color: VjColors.print)),
                    onTap: () {
                      session.cast.disconnect();
                      Navigator.pop(context);
                    },
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
