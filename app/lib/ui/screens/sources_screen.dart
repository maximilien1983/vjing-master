import 'package:flutter/material.dart';

import '../../session.dart';
import '../../theme/vj_tokens.dart';
import '../materials.dart';
import '../widgets/mech_key.dart';
import '../widgets/source_widgets.dart';

/// Écran Sources (maquette 04) : l'autoplay pioche dans les sources chargées.
/// Jalon 3 : liste factice ; Fichier / Lien arrivent avec le jalon 4.
class SourcesScreen extends StatelessWidget {
  final Session session;
  const SourcesScreen({super.key, required this.session});

  void _notYet(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: VjColors.recessBottom,
      content: Text('$what : au jalon 4 (catalogue et fichiers).',
          style: const TextStyle(
              fontFamily: 'Barlow Condensed', color: VjColors.print)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return VjScaffold(
      facadePadding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      child: Column(
        children: [
          SizedBox(
            height: 50,
            child: Row(children: [
              MechKey(
                width: 132,
                onTap: () => Navigator.of(context).pop(),
                semanticsLabel: 'Retour à la console',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.chevron_left,
                        size: 18, color: VjColors.print),
                    const SizedBox(width: 6),
                    Text('CONSOLE', style: VjText.keyLabel),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SOURCES VIDÉO',
                        style: TextStyle(
                          fontFamily: 'Barlow Condensed',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 18 * .34,
                          color: VjColors.print,
                        )),
                    const SizedBox(height: 2),
                    Text("L'AUTOPLAY PIOCHE DANS LES SOURCES CHARGÉES",
                        style: VjText.hint.copyWith(letterSpacing: 11 * .16)),
                  ],
                ),
              ),
              MechKey(
                width: 132,
                onTap: () => _notYet(context, 'Ajout de fichier'),
                semanticsLabel: 'Ajouter un fichier du téléphone',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, size: 16, color: VjColors.print),
                    const SizedBox(width: 8),
                    Text('FICHIER', style: VjText.keyLabel),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              MechKey(
                width: 132,
                onTap: () => _notYet(context, 'Ajout de lien'),
                semanticsLabel: 'Ajouter un fichier distant',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, size: 16, color: VjColors.print),
                    const SizedBox(width: 8),
                    Text('LIEN', style: VjText.keyLabel),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: RecessPanel(
              padding: const EdgeInsets.all(8),
              child: ListenableBuilder(
                listenable: session.sourcesModel,
                builder: (context, _) {
                  final model = session.sourcesModel;
                  return ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(scrollbars: true),
                    child: ListView.separated(
                      itemCount: model.sources.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final s = model.sources[i];
                        return SourceRow(
                            source: s, onAction: () => model.toggle(s));
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
